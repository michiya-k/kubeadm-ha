#!/bin/bash

# kubectl Installation Script for Ubuntu

set -e  # Exit immediately if a command exits with a non-zero status

# Step 1: Update package list and install dependencies
echo "Updating package list and installing required dependencies..."
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# Step 2: Set up keyring for Kubernetes
KEYRING_DIR="/etc/apt/keyrings"
KEYRING_FILE="$KEYRING_DIR/kubernetes-apt-keyring.gpg"

echo "Setting up Kubernetes apt keyring..."
if [ ! -d "$KEYRING_DIR" ]; then
  sudo mkdir -p -m 755 "$KEYRING_DIR"
fi

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o "$KEYRING_FILE"
sudo chmod 644 "$KEYRING_FILE"

# Step 3: Add Kubernetes apt repository
echo "Adding Kubernetes apt repository..."
REPO_FILE="/etc/apt/sources.list.d/kubernetes.list"
echo "deb [signed-by=$KEYRING_FILE] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | sudo tee "$REPO_FILE"
sudo chmod 644 "$REPO_FILE"

# Step 4: Update package list and install kubectl
echo "Updating package list and installing kubectl..."
sudo apt-get update -y
sudo apt-get install -y kubectl

# Step 5: Verify installation
echo "Verifying kubectl installation..."
kubectl version --client

echo "kubectl installation completed successfully!"
