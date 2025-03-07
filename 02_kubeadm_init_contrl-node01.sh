#!/bin/bash

# Enable error handling
set -e
trap 'echo "Error occurred! Exiting."; exit 1' ERR

# Get the private IP address of the current node
PRIVATE_IP=$(hostname -I | awk '{print $1}')
echo "Private IP address detected: $PRIVATE_IP"

# Set the control plane domain name to a fixed value
CONTROL_PLANE_DNS="controlplane.k8s.internal" # Change this value based on your design.
echo "Using fixed control plane DNS name: $CONTROL_PLANE_DNS"

# File to save the output of kubeadm init
KUBEADM_OUTPUT="/tmp/kubeadm_init_output.txt"

# Initialize the Kubernetes cluster and save the output
echo "Initializing Kubernetes cluster..."
sudo kubeadm init --control-plane-endpoint=$CONTROL_PLANE_DNS --pod-network-cidr=172.0.0.0/16 --upload-certs --ignore-preflight-errors=all | tee $KUBEADM_OUTPUT
sleep 10

# Configure kubectl for the current user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Calico as the Pod network add-on
kubectl apply --server-side -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
wget https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml || { echo "Failed to download custom-resources.yaml"; exit 1; }

# Update CIDR in custom-resources.yaml
sed -i 's|192.168.0.0/16|172.0.0.0/16|g' custom-resources.yaml
echo "Updated CIDR in custom-resources.yaml to 172.0.0.0/16"

# Apply custom resources
kubectl apply -f custom-resources.yaml

# Wait for CoreDNS ConfigMap to be created before modifying it
echo "Waiting for CoreDNS ConfigMap to be created..."
until kubectl get cm coredns -n kube-system > /dev/null 2>&1; do
  echo "CoreDNS ConfigMap not found, retrying in 5s..."
  sleep 5
done

# Backup the existing CoreDNS ConfigMap
kubectl get cm coredns -n kube-system -o yaml > /tmp/coredns-backup.yaml

# CoreDNS ConfigMap を修正
echo "Patching CoreDNS ConfigMap..."
kubectl get cm coredns -n kube-system -o yaml | sed 's|forward . /etc/resolv.conf {|forward . 8.8.8.8 1.1.1.1 {|' > /tmp/coredns-patch.yaml

kubectl replace -f /tmp/coredns-patch.yaml

# CoreDNS Pod を再起動して設定を適用
kubectl delete pod -n kube-system -l k8s-app=kube-dns

# Wait for CoreDNS pods to be running
echo "Waiting for CoreDNS pods to be ready..."
kubectl wait --for=condition=Ready pod -l k8s-app=kube-dns -n kube-system --timeout=120s

# Monitor the status of pods and wait until all are in 'Running' state
echo "Waiting for all pods to reach the 'Running' state..."
while true; do
  POD_STATUSES=$(kubectl get pods -A --no-headers | awk '{print $4}' | sort | uniq)
  if [ "$POD_STATUSES" == "Running" ]; then
    echo "All pods are in 'Running' state."
    echo "Displaying current pod statuses:"
    kubectl get pod -A
    echo "Initialization successful!"
    break
  else
    echo "Current pod statuses: $POD_STATUSES"
    sleep 10
  fi
done

# Display the saved output of kubeadm init
echo "=================================================="
echo "kubeadm init output saved during initialization:"
echo "=================================================="
cat $KUBEADM_OUTPUT
