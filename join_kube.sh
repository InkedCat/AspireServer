#!/usr/bin/env bash

source .env

TMP_DIR="/tmp/aspire-$(date +%Y-%m-%d-%H_%M_%S)"
mkdir -p "${TMP_DIR}"

# Log file
LOG_FILE="${TMP_DIR}/kubeadm.log"

# Colors for output
blue=$(tput setaf 4)
green=$(tput setaf 2)
red=$(tput setaf 1)
reset=$(tput sgr0)

echo_info() {
  printf "%s[INFO]%s %s\n" "${blue}" "${reset}" "$1"
  printf "[INFO] %s\n" "$1" >> "${LOG_FILE}"
}

echo_error() {
  printf "%s[ERROR]%s %s\n" "${red}" "${reset}" "$1"
  printf "[ERROR] %s\n" "$1" >> "${LOG_FILE}"
}

echo_success() {
  printf "%s[SUCCESS]%s %s\n" "${green}" "${reset}" "$1"
  printf "[SUCCESS] %s\n" "$1" >> "${LOG_FILE}"
}

join_kubeadm() {
  echo_info "Joining the Kubernetes cluster..."

  sudo kubeadm join $CONTROL_PLANE_IP:6443 --token $KUBEADM_TOKEN --discovery-token-ca-cert-hash sha256:$CA_CERT_HASH &>> "${LOG_FILE}"

  if [ $? -eq 0 ]; then
    echo_success "Worker node joined the cluster!"
  else
    echo_error "Failed to join the cluster. Check the log file for details."
    exit 1
  fi
}

# Main script execution
echo_info "Starting worker node setup..."
join_kubeadm
echo_success "Worker node setup complete!"