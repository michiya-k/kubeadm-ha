#!/bin/bash

# Run this script on all control nodes, Control1, Control2, Control3.

# Commands definition
COMMANDS=$(cat <<'EOF'
echo "Enabling IPv4 packet forwarding"
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# Sleep to ensure all startup services are ready
sleep 10

# Install containerd
echo "Installing containerd"
sudo sysctl --system
wget https://github.com/containerd/containerd/releases/download/v2.0.3/containerd-2.0.3-linux-amd64.tar.gz -P /tmp
cd /tmp
sudo tar Cxzvf /usr/local containerd-2.0.3-linux-amd64.tar.gz

# Install runc
echo "Installing runc"
wget https://github.com/opencontainers/runc/releases/download/v1.2.5/runc.amd64 -P /tmp
sudo install -m 755 runc.amd64 /usr/local/sbin/runc

# Install CNI plugins
echo "Installing CNI plugins"
sudo mkdir -p /opt/cni/bin
wget https://github.com/containernetworking/plugins/releases/download/v1.6.2/cni-plugins-linux-amd64-v1.6.2.tgz -P /tmp
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.6.2.tgz

# Configure containerd
echo "Configuring containerd"
sudo mkdir /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /etc/systemd/system/containerd.service

echo "Restarting containerd"
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

# Install kubeadm, kubelet, kubectl
echo "Installing kubeadm, kubelet, kubectl"
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
EOF
)

# Execute commands
echo "Running commands..."
bash -c "$COMMANDS"
if [ $? -eq 0 ]; then
  echo "Commands executed successfully."
else
  echo "Error occurred while executing commands."
fi
