#!/usr/bin/env bash

echo_success() {
    echo
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
    echo
}

sudo kubeadm reset
sudo rm -r ~/.kube
echo_success "Kubernetes removed !"

sudo nft flush ruleset
sudo firewall-cmd --reload
echo_success "Firewall rules flushed !"

sudo rm /etc/cni/net.d/10-calico.conflist
sudo rm /etc/cni/net.d/calico-kubeconfig
echo_success "Calico CNI removed !"