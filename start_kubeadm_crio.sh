# Step 1: Start CRI-O and kubelet services
sudo systemctl enable --now crio
sudo systemctl enable --now kubelet

# Step 2: Initialize Kubernetes with the existing configuration file
sudo kubeadm init --config=/etc/kubernetes/kubeadm-config.yaml --upload-certs | tee kubeadm-init.out

# Step 3: Configure kubectl to use the kubeadm config
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=/etc/kubernetes/admin.conf


# Step 4: Taint the control-plane node to allow scheduling of pods
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# Step 5: Run a test pod
kubectl run webserver --image=nginx -n default


# Step 6: Perform a container checkpoint via Kubelet's REST API
curl -sk -X POST "https://localhost:10250/checkpoint/default/webserver/webserver" \
    --key /etc/kubernetes/pki/apiserver-kubelet-client.key \
    --cacert /etc/kubernetes/pki/ca.crt \
    --cert /etc/kubernetes/pki/apiserver-kubelet-client.crt

echo "Kubeadm initialized, test pod running, and checkpoint created."
