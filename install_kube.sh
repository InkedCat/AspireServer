#!/usr/bin/env bash

echo_info() {
    echo
    echo -e "\033[1;34m[INFO]\033[0m $1"
    echo
}

echo_success() {
    echo
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
    echo
}

sudo kubeadm init --config ./kubernetes/kubeadm.yaml

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo_success "User kubectl initiated !"

sleep 30
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
echo_success "Kubernetes installed !"

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.2/manifests/tigera-operator.yaml

echo_info "Waiting for the operator to be ready..."
sleep 30

kubectl create -f ./kubernetes/calico/custom.yaml
echo_success "Calico CNI installed !"

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
echo_success "Metrics server installed !"