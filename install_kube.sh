#!/usr/bin/env bash

echo_success() {
    echo
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

sudo kubeadm init --config ./kubernetes/kubeadm.yaml
echo_success "Kubernetes installed !"

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo_success "User kubectl initiated !"

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.2/manifests/tigera-operator.yaml
kubectl create -f ./kubernetes/calico/custom.yaml
echo_success "Calico CNI installed !"

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
echo_success "Metrics server installed !"