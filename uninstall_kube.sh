#!/usr/bin/env bash
sudo kubeadm reset
sudo rm -r ~/.kube
echo "Kubernetes removed !"

sudo nft flush ruleset
sudo firewall-cmd --reload
echo "Firewall rules flushed !"

sudo rm /etc/cni/net.d/10-calico.conflist
sudo rm /etc/cni/net.d/calico-kubeconfig
echo "Calico CNI removed !"