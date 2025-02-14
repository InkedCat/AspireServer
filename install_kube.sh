#!/usr/bin/env bash

source .env

TMP_DIR="/tmp/aspire-$(date +%Y-%m-%d-%H_%M_%S)"
readonly TMP_DIR

mkdir -p "${TMP_DIR}"

LOG_FILE="${TMP_DIR}/kubeadm.log"

YQ_VERSION="v4.45.1"
YQ_BINARY="yq_linux_amd64"

K8S_VERSION="v1.32.1"
CALICO_VERSION="v3.29.2"
METRICS_VERSION="v0.7.2"
CERT_MANAGER_VERSION="v1.16.4"
TRAEFIK_VERSION="v3.3"

blue=$(tput setaf 4)
green=$(tput setaf 2)
red=$(tput setaf 1)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

echo_info() {
  printf "%s[INFO]%s %s\n" "${blue}" "${reset}" "$1"
  printf "[INFO] %s\n" "$1" >> "${LOG_FILE}"
}

echo_error() {
  printf "%s[ERROR]%s %s\n" "${red}" "${reset}" "$1"
  printf "[ERROR] %s\n" "$1" >> "${LOG_FILE}"
}

echo_warning() {
  printf "%s[WARNING]%s %s\n" "${yellow}" "${reset}" "$1"
  printf "[WARNING] %s\n" "$1" >> "${LOG_FILE}"
}

echo_success() {
  printf "%s[SUCCESS]%s %s\n" "${green}" "${reset}" "$1"
  printf "[SUCCESS] %s\n" "$1" >> "${LOG_FILE}"
}

################################################################
# Setup prerequisites
################################################################

install_yq() {
  echo_info "Installing yq..."

  if ! wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_BINARY} -O "${TMP_DIR}/yq" &>> "${LOG_FILE}"; then
    echo_error "Failed to download yq, exiting."
    exit 1
  fi

  chmod +x "${TMP_DIR}/yq"
  
  echo_success "yq installed !"
}


################################################################
# Services installation
################################################################

install_cni() {
  echo_info "Installing Calico CNI..."
    
  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml &>> "${LOG_FILE}"

  echo_info "Waiting for Calico Tigera operator to be ready..."
  if ! kubectl wait --for=condition=available --timeout=30s deployment/tigera-operator -n tigera-operator &>> "${LOG_FILE}"; then
    echo_error "Calico Tigera operator not healthy after 30s, exiting."
    exit 1
  fi

  kubectl create -f ./kubernetes/calico/custom-ressources.yaml  &>> "${LOG_FILE}"

  echo_success "Calico CNI installed !"
}

install_metrics_server() {
  echo_info "Installing Metrics Server..."
    
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_VERSION}/components.yaml &>> "${LOG_FILE}"

  echo_info "Waiting for Metrics Server to be ready..."
  if ! kubectl wait --for=condition=available --timeout=30s deployment/metrics-server -n kube-system &>> "${LOG_FILE}"; then
    echo_warning "Metrics Server not healthy after 30s. Please check the logs to see what went wrong."
  else
    echo_success "Metrics Server installed !"
  fi
}

install_cert_manager() {
  echo_info "Installing Cert Manager..."
  
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml &>> "${LOG_FILE}"

  echo_info "Waiting for Cert Manager to be ready..."
  if ! kubectl wait --for=condition=available --timeout=30s deployment/cert-manager-webhook -n cert-manager &>> "${LOG_FILE}"; then
    echo_warning "Cert Manager not healthy after 30s. Please check the logs to see what went wrong."
  else
    echo_success "Cert Manager installed !"
  fi

  /${TMP_DIR}/yq " .stringData.api-token = \"${CLOUDFLARE_API_TOKEN}\"" < ./kubernetes/secrets/cloudflare-token.yaml > "${TMP_DIR}/cloudflare-token-secret.yaml"
  kubectl apply -f "${TMP_DIR}/cloudflare-token-secret.yaml" &>> "${LOG_FILE}"
  rm "${TMP_DIR}/cloudflare-token-secret.yaml"

  kubectl apply -f ./kubernetes/cert-manager/staging-cert-manager.yaml &>> "${LOG_FILE}"

  echo_success "Cert Manager Issuers created !"
}

install_traefik_crds() {
  echo_info "Creating Traefik CRDs..."

  kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/${TRAEFIK_VERSION}/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml &>> "${LOG_FILE}"
  kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/${TRAEFIK_VERSION}/docs/content/reference/dynamic-configuration/kubernetes-crd-rbac.yml &>> "${LOG_FILE}"

  echo_success "Traefik CRDs created !"
}

install_traefik_pre() {
  echo_info "Installing Traefik pre-requisites..."

  kubectl apply -f ./kubernetes/traefik-ingress/rbac/account.yaml &>> "${LOG_FILE}"
  kubectl apply -f ./kubernetes/traefik-ingress/rbac/cluster-role.yaml &>> "${LOG_FILE}"
  kubectl apply -f ./kubernetes/traefik-ingress/rbac/cluster-role-binding.yaml &>> "${LOG_FILE}"

  echo_success "Traefik pre-requisites installed !"
}

install_traefik_extra() {
  echo_info "Installing Traefik extra components..."

  kubectl apply -f ./kubernetes/traefik-ingress/middlewares/https-redirect.yaml &>> "${LOG_FILE}"
  kubectl apply -f ./kubernetes/traefik-ingress/routes/api.yaml &>> "${LOG_FILE}"
  kubectl apply -f ./kubernetes/traefik-ingress/service.yaml &>> "${LOG_FILE}"
  kubectl apply -f ./kubernetes/traefik-ingress/tls/staging-tls.yaml &>> "${LOG_FILE}"

  echo_success "Traefik extra components installed !"
}

install_traefik() {
  echo_info "Installing Traefik..."

  install_traefik_crds

  install_traefik_pre
 
  /${TMP_DIR}/yq ".spec.template.spec.containers[0].image = \"traefik:${TRAEFIK_VERSION}\"" < ./kubernetes/traefik-ingress/deployment.yaml > "${TMP_DIR}/traefik-deployment.yaml"

  kubectl apply -f "${TMP_DIR}/traefik-deployment.yaml" &>> "${LOG_FILE}"

  echo_info "Waiting for Traefik to be ready..."
  if ! kubectl wait --for=condition=available --timeout=30s deployment/traefik -n kube-system &>> "${LOG_FILE}"; then
    echo_warning "Traefik not healthy after 30s. Please check the logs to see what went wrong."
  else
    echo_success "Traefik installed !"
  fi

  install_traefik_extra

  echo_success "Traefik Ingress created !"
}

################################################################
# Kubernetes installation
################################################################

init_kubeadm() {
  echo_info "Initializing the Kubernetes cluster..."
  
  primary_ipv4="$(echo "${selected_interface}" | awk -F'[ /]+' '{print $1}')"

  /${TMP_DIR}/yq eval "
    select(.kind == \"InitConfiguration\").nodeRegistration.kubeletExtraArgs.[0].value = \"${primary_ipv4}\" |
    select(.kind == \"InitConfiguration\").localAPIEndpoint.advertiseAddress = \"${primary_ipv4}\" |
    select(.kind == \"ClusterConfiguration\").kubernetesVersion = \"${K8S_VERSION}\"
  " < ./kubernetes/kubeadm.yaml > "${TMP_DIR}/kubeadm.yaml"

  if [ -n "${CUSTOM_SAN}" ]; then
    /${TMP_DIR}/yq eval -i "select(.kind == \"ClusterConfiguration\").apiServer.certSANs[0] = \"${CUSTOM_SAN}\"" "${TMP_DIR}/kubeadm.yaml"
  fi

  sudo kubeadm init --config "${TMP_DIR}/kubeadm.yaml" &>> "${LOG_FILE}"

  echo_success "Kubernetes installed !"
}

wait_for_nodes() {
  echo_info "Waiting for nodes to be ready..."

  if ! kubectl wait --for=condition=Ready --all nodes --timeout=180s &>> "${LOG_FILE}" ; then
    echo_error "Nodes not ready after 180s, exiting."
    exit 1
  fi

  echo_success "Nodes ready !"
}

configure_user_kubectl() {
  echo_info "Configuring user kubectl..."
    
  mkdir -p "${HOME}/.kube"
  sudo cp -i /etc/kubernetes/admin.conf "${HOME}/.kube/config"
  sudo chown "$(id -u):$(id -g)" "${HOME}/.kube/config"

  echo_success "$(id -un) kubectl configured !"
}

configure_as_single_node() {
  echo_info "Configuring single node cluster..."

  kubectl taint nodes --all node-role.kubernetes.io/control-plane- &>> "${LOG_FILE}"

  echo_info "Waiting for single node cluster to be ready..."
  sleep 10

  echo_success "Single node cluster ready !"
}

configure_namespaces() {
  echo_info "Creating namespaces..."

  kubectl apply -f ./kubernetes/namespaces/staging.yaml &>> "${LOG_FILE}"

  echo_success "Namespaces created !"
}

################################################################
# Variables setup
################################################################

choose_interface() {
  echo_warning "Please choose the network interface to use for the cluster"
  while true; do
    echo_info "Available network interfaces:"
    interfaces="$(ip -4 addr show scope global | grep inet | awk '{print $2 " " $NF}')"

    line_number=1
    while read -r ip interface; do
      printf "%s) %s %s\n" "${line_number}" "${ip}" "${interface}"

      ((line_number++))
    done < <(echo "${interfaces}")

    read -r -p "Select the interface to use: " interface_number

    if [[ ! $interface_number =~ ^[0-9]+$ ]] || [ "${interface_number}" -ge "${line_number}" ]; then
      echo_error "Invalid interface number, please try again."
    else
      selected_interface="$(echo "${interfaces}" | sed -n "${interface_number}"p)"
      break
    fi
  done
  echo_success "Selected interface: ${selected_interface}"
}

setup_cloudflare() {
  echo_warning "Please enter your Cloudflare API token to use for the cluster issuer"

  read -r -p "CF Token: " CLOUDFLARE_API_TOKEN

  echo_success "Cloudflare API Token secret created !"
}

setup_variables() {
  setup_cloudflare

  choose_interface
}

################################################################
# Main script
################################################################

echo_info "Script prequisites setup..."

install_yq

echo_success "Script now ready !"

echo_info "Starting Aspire Kubernetes install..."

setup_variables

echo_info "Logs are available at ${LOG_FILE}"

echo_info "Configuring control-plane node..."
init_kubeadm

configure_user_kubectl

configure_as_single_node

configure_namespaces

install_cni

install_cert_manager

install_metrics_server

install_traefik

wait_for_nodes

echo_success "Aspire Kubernetes installed !"