#!/bin/bash
set -e

echo "BASE Platform Local Validation Options"
echo "======================================"

print_option() {
    echo -e "\n$1"
    echo "-------------------"
    echo "$2"
    echo "Command: $3"
}

print_option "1. Docker Compose (Recommended - Fastest)" \
             "Run all platform services locally with Docker Compose\nIncludes: ArgoCD, Grafana, Kibana, Airflow, MLflow, Prometheus\nRequires: Docker & Docker Compose" \
             "docker-compose -f docker-compose.local.yml up -d"

print_option "2. Vagrant + VirtualBox (Most Complete)" \
             "Full VM environment with Kubernetes (kind)\nSimulates AWS EKS with node groups and storage classes\nRequires: Vagrant & VirtualBox (8GB RAM)" \
             "vagrant up && vagrant ssh"

print_option "3. Kind (Kubernetes in Docker)" \
             "Local Kubernetes cluster for testing manifests\nSame as Vagrant option but without VM overhead\nRequires: Docker & kind" \
             "kind create cluster --config=dev-configs/kind-cluster.yaml"

echo -e "\n======================================"
echo "Choose your validation method:"
echo "1. Quick validation with Docker Compose"
echo "2. Full platform simulation with Vagrant"  
echo "3. Kubernetes manifest testing with kind"
echo -e "======================================\n"

read -p "Enter your choice (1-3): " choice

case $choice in
    1)
        echo "Starting Docker Compose local platform..."
        if ! command -v docker-compose &> /dev/null; then
            echo "Error: Docker Compose not found. Please install Docker Desktop."
            exit 1
        fi
        
        echo "Creating local environment..."
        chmod +x dev-configs/create-multiple-databases.sh
        
        docker-compose -f docker-compose.local.yml up -d
        
        echo
        echo "✓ Platform starting up..."
        echo "✓ Services will be available at:"
        echo "  - Platform UI: http://localhost:8082"
        echo "  - ArgoCD: http://localhost:8080"
        echo "  - Grafana: http://localhost:3000 (admin/admin123)"
        echo "  - Kibana: http://localhost:5601"
        echo "  - Airflow: http://localhost:8081 (admin/admin123)"
        echo "  - MLflow: http://localhost:5000"
        echo "  - Prometheus: http://localhost:9090"
        echo
        echo "Wait 2-3 minutes for all services to start, then visit:"
        echo "http://localhost:8082"
        
        # Wait and check health
        sleep 30
        echo "Checking service health..."
        docker-compose -f docker-compose.local.yml ps
        ;;
        
    2)
        echo "Starting Vagrant environment..."
        if ! command -v vagrant &> /dev/null; then
            echo "Error: Vagrant not found. Please install Vagrant and VirtualBox."
            exit 1
        fi
        
        vagrant up
        echo
        echo "✓ VM created successfully!"
        echo "Next steps:"
        echo "1. vagrant ssh"
        echo "2. kind create cluster --config=kind-config.yaml"
        echo "3. kubectl apply -f local-storage-class.yaml"
        echo "4. ./validate-local-platform.sh"
        ;;
        
    3)
        echo "Setting up kind cluster..."
        if ! command -v kind &> /dev/null; then
            echo "Error: kind not found. Installing kind..."
            curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-$(uname)-amd64
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
        fi
        
        # Create kind config if it doesn't exist
        if [ ! -f "dev-configs/kind-cluster.yaml" ]; then
            cat > dev-configs/kind-cluster.yaml << EOF
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
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "eks.amazonaws.com/nodegroup=platform_general"
EOF
        fi
        
        kind create cluster --config=dev-configs/kind-cluster.yaml
        
        # Create storage classes
        kubectl apply -f - << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-immediate
provisioner: rancher.io/local-path
volumeBindingMode: Immediate
EOF
        
        echo
        echo "✓ kind cluster created with BASE platform node labels"
        echo "✓ Storage classes configured"
        echo "Next: Deploy platform manifests to test"
        ;;
        
    *)
        echo "Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo
echo "Local validation environment ready!"