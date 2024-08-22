#!/bin/bash

# Variables (Change these as needed)
KUBERNETES_VERSION="v1.31"
CRIO_VERSION="v1.30"

ADVERTISE_ADDRESS="192.168.251.130"  # Replace with your actual IP address

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system


# Step 1: Ensure swap is off and make it persistent
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab

# Step 2: Install dependencies for adding repositories
sudo apt-get update
sudo apt-get install -y software-properties-common curl apt-transport-https ca-certificates gpg criu

# Create the keyrings directory if it doesn't exist
if [ ! -d /etc/apt/keyrings ]; then
  sudo mkdir -p -m 755 /etc/apt/keyrings
fi

# Step 3: Add the Kubernetes repository

# Download and process the Kubernetes keyring, overwriting if necessary
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor --batch --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Download and process the CRI-O keyring, overwriting if necessary
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor --batch --yes -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list

# Step 5: Update the apt package index
sudo apt-get update

# Step 6: Install CRI-O, kubelet, kubeadm, and kubectl
sudo apt-get install -y cri-o kubelet kubeadm kubectl

# Step 7: Prevent the packages from being automatically updated
sudo apt-mark hold cri-o kubelet kubeadm kubectl

# Step 8: Configure CRI-O to use runc and enable CRIU support
cat <<EOF | sudo tee /etc/crio/crio.conf
[crio.runtime]
default_runtime = "runc"
enable_criu_support = true
EOF

# Step 9: Create the kubeadm-config.yaml configuration file
cat <<EOF | sudo tee /etc/kubernetes/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $ADVERTISE_ADDRESS
  bindPort: 6443
nodeRegistration:
  criSocket: "unix:///var/run/crio/crio.sock"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
featureGates:
  ContainerCheckpoint: true
EOF

echo "Installation and configuration complete. You can now run the start script to initialize the cluster."

