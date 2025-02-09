#!/usr/bin/env bash
sudo kubeadm reset
sudo rm -r ~/.kube

sudo nft flush ruleset
sudo firewall-cmd --reload

sudo rm /etc/cni/net.d/10-calico.conflist
sudo rm /etc/cni/net.d/calico-kubeconfig