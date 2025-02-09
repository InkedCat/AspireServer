#!/usr/bin/env bash
sudo kubeadm init --config ./kubernetes/kubeadm.yaml
echo "Kubernetes installed !"

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo "User kubectl initiated !"

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.2/manifests/tigera-operator.yaml
kubectl create -f ./kubernetes/calico/custom.yaml
echo "Calico CNI installed !"

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
echo "Metrics server installed !"