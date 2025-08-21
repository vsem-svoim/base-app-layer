# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.hostname = "base-platform-dev"

  # Network configuration
  config.vm.network "private_network", ip: "192.168.56.10"
  config.vm.network "forwarded_port", guest: 8080, host: 8080  # ArgoCD
  config.vm.network "forwarded_port", guest: 3000, host: 3000  # Grafana
  config.vm.network "forwarded_port", guest: 5601, host: 5601  # Kibana
  config.vm.network "forwarded_port", guest: 8081, host: 8081  # Airflow
  config.vm.network "forwarded_port", guest: 5000, host: 5000  # MLflow

  # VM configuration
  config.vm.provider "virtualbox" do |vb|
    vb.name = "base-platform-dev"
    vb.memory = "8192"
    vb.cpus = 4
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  end

  # Provisioning script
  config.vm.provision "shell", inline: <<-SHELL
    set -e
    
    echo "=== BASE Platform Local Development Setup ==="
    
    # Update system
    apt-get update
    apt-get upgrade -y
    
    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker vagrant
    systemctl enable docker
    systemctl start docker
    
    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Install kind (Kubernetes in Docker)
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    
    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/kubectl
    
    # Install Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    # Install ArgoCD CLI
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
    
    # Install k9s (Kubernetes CLI UI)
    curl -sS https://webinstall.dev/k9s | bash
    sudo mv ~/.local/bin/k9s /usr/local/bin/
    
    # Install yq and jq
    apt-get install -y jq
    curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/local/bin/yq
    chmod +x /usr/local/bin/yq
    
    # Create kind cluster configuration
    cat > /home/vagrant/kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: base-platform
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "eks.amazonaws.com/nodegroup=platform_system"
  extraPortMappings:
  - containerPort: 30080
    hostPort: 8080
    protocol: TCP
  - containerPort: 30000
    hostPort: 3000
    protocol: TCP
  - containerPort: 30601
    hostPort: 5601
    protocol: TCP
  - containerPort: 30081
    hostPort: 8081
    protocol: TCP
  - containerPort: 30500
    hostPort: 5000
    protocol: TCP
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "eks.amazonaws.com/nodegroup=platform_general"
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "eks.amazonaws.com/nodegroup=platform_memory"
EOF

    # Create local storage class configuration
    cat > /home/vagrant/local-storage-class.yaml << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-immediate
provisioner: rancher.io/local-path
volumeBindingMode: Immediate
reclaimPolicy: Delete
EOF

    # Create platform validation script
    cat > /home/vagrant/validate-local-platform.sh << 'EOF'
#!/bin/bash
set -e

echo "BASE Platform Local Validation"
echo "============================="

# Check if kind cluster exists
if kind get clusters | grep -q "base-platform"; then
    echo "✓ kind cluster 'base-platform' exists"
else
    echo "✗ kind cluster 'base-platform' does not exist"
    echo "  Run: kind create cluster --config=/home/vagrant/kind-config.yaml"
    exit 1
fi

# Set kubeconfig
export KUBECONFIG="$(kind get kubeconfig-path --name="base-platform")"
kubectl config use-context kind-base-platform

echo "✓ kubectl configured for local cluster"

# Check nodes with labels
echo
echo "Node Groups Validation:"
kubectl get nodes --show-labels | grep "eks.amazonaws.com/nodegroup"

# Check storage classes
echo
echo "Storage Classes:"
kubectl get storageclass

# Check if we can create a test pod
echo
echo "Testing pod creation..."
kubectl run test-pod --image=nginx:alpine --rm -it --restart=Never --command -- echo "Platform validation successful"

echo
echo "✓ Local platform validation completed successfully!"
echo
echo "Platform Access URLs (after deployment):"
echo "- ArgoCD: http://localhost:8080"
echo "- Grafana: http://localhost:3000" 
echo "- Kibana: http://localhost:5601"
echo "- Airflow: http://localhost:8081"
echo "- MLflow: http://localhost:5000"
EOF

    chmod +x /home/vagrant/validate-local-platform.sh
    
    # Set ownership
    chown -R vagrant:vagrant /home/vagrant/
    
    echo "=== Setup Complete ==="
    echo "Next steps:"
    echo "1. vagrant ssh"
    echo "2. kind create cluster --config=kind-config.yaml"
    echo "3. kubectl apply -f local-storage-class.yaml"
    echo "4. ./validate-local-platform.sh"
    echo "5. Deploy platform services using local manifests"
    
  SHELL
end