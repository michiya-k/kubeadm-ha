#!/bin/bash

# Enable error handling
set -e
trap 'echo "Error occurred! Exiting."; exit 1' ERR

# Get the private IP address of the current node
PRIVATE_IP=$(hostname -I | awk '{print $1}')
echo "Private IP address detected: $PRIVATE_IP"

# File to save the output of kubeadm init
KUBEADM_OUTPUT="/tmp/kubeadm_init_output.txt"

# Initialize the Kubernetes cluster and save the output
echo "Initializing Kubernetes cluster..."
sudo kubeadm init --control-plane-endpoint=$PRIVATE_IP --pod-network-cidr=172.0.0.0/16 --upload-certs --ignore-preflight-errors=all | tee $KUBEADM_OUTPUT
sleep 10

# Configure kubectl for the current user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Calico as the Pod network add-on
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
wget https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml || { echo "Failed to download custom-resources.yaml"; exit 1; }

# Update CIDR in custom-resources.yaml
sed -i 's|192.168.0.0/16|172.0.0.0/16|g' custom-resources.yaml
echo "Updated CIDR in custom-resources.yaml to 172.0.0.0/16"

# Apply custom resources
kubectl create -f custom-resources.yaml

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
