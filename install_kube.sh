#!/usr/bin/env bash

TMP_DIR="/tmp/aspire-$(date +%Y-%m-%d-%H_%M_%S)"
readonly TMP_DIR

mkdir -p "${TMP_DIR}"

LOG_FILE="${TMP_DIR}/kubeadm.log"

export KUBERNETES_VERSION="v1.32.1"
CALICO_VERSION="v3.29.2"
METRICS_VERSION="v0.7.2"
CERT_MANAGER_VERSION="v1.16.3"

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

  export CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN}"
  envsubst < ./kubernetes/cert-manager/cluster-issuer.yaml > "${TMP_DIR}/cluster-issuer.yaml"

  kubectl apply -f "${TMP_DIR}/cluster-issuer.yaml" &>> "${LOG_FILE}"
}

################################################################
# Kubernetes installation
################################################################

init_kubeadm() {
  echo_info "Initializing the Kubernetes cluster..."
  
  export PRIMARY_IPV4="$(echo "${selected_interface}" | awk -F'[ /]+' '{print $1}')"

  envsubst < ./kubernetes/kubeadm.yaml > "${TMP_DIR}/kubeadm.yaml"

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

################################################################
# Variables setup
################################################################

choose_interface() {
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
}

setup_variables() {
  echo_warning "Please enter your Cloudflare API token to use for the cluster"
  read -r -p "CF Token: " CLOUDFLARE_API_TOKEN
  echo_success "Cloudflare API Token secret created !"

  echo_warning "Please choose the network interface to use for the cluster"
  choose_interface
  echo_success "Selected interface: ${selected_interface}"
}

################################################################
# Main script
################################################################

echo_info "Starting Aspire Kubernetes install..."

setup_variables

echo_info "Logs are available at ${LOG_FILE}"

echo_info "Configuring control-plane node..."
init_kubeadm

configure_user_kubectl

install_cni

install_cert_manager

install_metrics_server

wait_for_nodes

configure_as_single_node

echo_success "Aspire Kubernetes installed !"