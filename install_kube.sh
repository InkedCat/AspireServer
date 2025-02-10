#!/usr/bin/env bash

TMP_DIR="/tmp/aspire-$(date +%Y-%m-%d-%H_%M_%S)"
readonly TMP_DIR

mkdir -p $TMP_DIR

LOG_FILE="${TMP_DIR}/kubeadm.log"

KUBERNETES_VERSION="v1.32.1"
CALICO_VERSION="v3.29.2"
METRICS_VERSION="v0.7.2"

echo_info() {
  echo -e "\033[1;34m[INFO]\033[0m $1"
}

echo_error() {
  echo -e "\033[1;31m[ERROR]\033[0m $1"
}

echo_warning() {
  echo -e "\033[1;33m[WARNING]\033[0m $1"
}

echo_success() {
  echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

install_cni() {
  echo_info "Installing Calico CNI..."
    
  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml &>> $LOG_FILE

  echo_info "Waiting for Calico Tigera operator to be ready..."
  if ! kubectl wait --for=condition=available --timeout=30s deployment/tigera-operator -n tigera-operator &>> $LOG_FILE; then
    echo_error "Calico Tigera operator not healthy after 30s, exiting."
    exit 1
  fi

  kubectl create -f ./kubernetes/calico/custom-ressources.yaml  &>> $LOG_FILE

  echo_success "Calico CNI installed !"
}

install_metrics_server() {
  echo_info "Installing Metrics Server..."
    
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_VERSION}/components.yaml &>> $LOG_FILE

  echo_info "Waiting for Metrics Server to be ready..."
  if ! kubectl wait --for=condition=available --timeout=30s deployment/metrics-server -n kube-system &>> $LOG_FILE; then
    echo_warning "Metrics Server not healthy after 30s. Please check the logs to see what went wrong."
  else
    echo_success "Metrics Server installed !"
  fi
}

is_valid_IPV4() {
  return $(ip -4 route get $1 &> /dev/null)
}

is_valid_IPV6() {
  return $(ip -6 route get $1 &> /dev/null)
}

init_kubeadm() {
  echo_info "Initializing the Kubernetes cluster..."

  PRIMARY_IPV4="$(ip -4 addr show scope global | grep -m1 inet | awk '{print $2}' | cut -d/ -f1)"
  if ! is_valid_IPV4 $PRIMARY_IPV4; then
    echo_error "Invalid IPv4 address: $PRIMARY_IPV4"
    exit 1
  fi
  
  PRIMARY_IPV6="$(ip -6 addr show scope global | grep -m1 inet6 | awk '{print $2}' | cut -d/ -f1)"
  if ! is_valid_IPV6 $PRIMARY_IPV6; then
    echo_error "Invalid IPv6 address: $PRIMARY_IPV6"
    exit 1
  fi

  envsubst < ./kubernetes/kubeadm.yaml > ${TMP_DIR}/kubeadm.yaml

  sudo kubeadm init --config ${TMP_DIR}/kubeadm.yaml &>> $LOG_FILE

  echo_success "Kubernetes installed !"
}

wait_for_nodes() {
  echo_info "Waiting for nodes to be ready..."

  if ! kubectl wait --for=condition=Ready --all nodes --timeout=180s &>> $LOG_FILE ; then
    echo_error "Nodes not ready after 180s, exiting."
    exit 1
  fi

  echo_success "Nodes ready !"
}


configure_user_kubectl() {
  echo_info "Configuring user kubectl..."
    
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  echo_success "$(id -un) kubectl configured !"
}

configure_as_single_node() {
  echo_info "Configuring single node cluster..."

  kubectl taint nodes --all node-role.kubernetes.io/control-plane- &>> $LOG_FILE

  echo_info "Waiting for single node cluster to be ready..."
  sleep 10

  echo_success "Single node cluster ready !"
}

echo_info "Starting Aspire Kubernetes install..."
echo_info "Logs are available at $LOG_FILE"

echo_info "Configuring control-plane node..."
init_kubeadm

configure_user_kubectl

install_cni

install_metrics_server

wait_for_nodes

configure_as_single_node

echo_success "Aspire Kubernetes installed !"