# BASE App Layer - AWS Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the complete BASE App Layer on AWS. The platform consists of:

- **Infrastructure Layer**: VPC, EKS clusters, managed node groups
- **GitOps Layer**: ArgoCD, Argo Workflows, Argo Rollouts  
- **Orchestration Layer**: Airflow, MLflow, Kubeflow, Grafana, Prometheus, Vault, Istio
- **BASE Layer**: 14 data processing modules with agent-based architecture
- **Platform UI**: Unified dashboard for all services

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Cloud                            │
│  ┌─────────────────────┐    ┌─────────────────────────────┐ │
│  │   Base Cluster      │    │    Platform Cluster        │ │
│  │ (Data Processing)   │    │   (GitOps & Services)      │ │
│  │                     │    │                             │ │
│  │ • Data Ingestion    │    │ • ArgoCD                    │ │
│  │ • Data Quality      │    │ • Airflow                   │ │
│  │ • 12 other modules  │    │ • MLflow/Kubeflow          │ │
│  │                     │    │ • Grafana/Prometheus       │ │
│  │ Fargate + Managed   │    │ • Vault/Istio              │ │
│  │ Node Groups         │    │ • Platform UI              │ │
│  │                     │    │                             │ │
│  │                     │    │ 5 Specialized Node Groups: │ │
│  │                     │    │ • System (On-Demand)       │ │
│  │                     │    │ • General (60% On-Demand)  │ │
│  │                     │    │ • Compute (30% On-Demand)  │ │
│  │                     │    │ • Memory (50% On-Demand)   │ │
│  │                     │    │ • GPU (40% On-Demand)      │ │
│  └─────────────────────┘    └─────────────────────────────┘ │
│                                                             │
│  Load Balancer Controller → ALB → Platform UI Dashboard     │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

### Required Tools
```bash
# Install required CLI tools
brew install terraform kubectl awscli helm jq

# Verify installations
terraform --version  # Should be >= 1.5.0
kubectl version      # Should be >= 1.28.0
aws --version        # Should be >= 2.0.0
helm version         # Should be >= 3.12.0
jq --version         # Should be >= 1.6
```

### AWS Configuration
```bash
# Configure AWS CLI with your credentials
aws configure --profile your-profile-name

# Set environment variable
export AWS_PROFILE=your-profile-name

# Verify access
aws sts get-caller-identity
```

### Required AWS Permissions
Your AWS account/user needs the following permissions:
- EC2 (VPC, Subnets, Security Groups, etc.)
- EKS (Clusters, Node Groups, Fargate)
- IAM (Roles, Policies, Service Accounts)
- S3 (Terraform state bucket)
- CloudWatch (Logs, Metrics)
- Route53 (DNS for ingress)
- ACM (SSL certificates)

## Quick Start (Automated)

### Option 1: Complete Automated Deployment
```bash
# Clone the repository
git clone <repository-url>
cd base-app-layer

# Set your AWS profile
export AWS_PROFILE=your-profile-name

# Run complete deployment
cd .platform-services/scripts
./full-deployment.sh

# Monitor deployment progress (30-45 minutes total)
# - Infrastructure: ~15 minutes
# - GitOps stack: ~10 minutes  
# - Applications: ~15 minutes
# - Validation: ~5 minutes
```

### Option 2: Step-by-Step Deployment
```bash
# Deploy infrastructure only
./full-deployment.sh infrastructure

# Deploy GitOps stack
./full-deployment.sh gitops

# Deploy orchestration applications
./full-deployment.sh apps

# Deploy BASE layer modules
./full-deployment.sh base-layer

# Enable Crossplane (optional)
./full-deployment.sh crossplane
```

## Manual Deployment Steps

### Step 1: Infrastructure Deployment
```bash
# Navigate to Terraform directory
cd .platform-services/terraform-new/providers/aws/environments/dev

# Initialize Terraform
terraform init

# Review and customize terraform.tfvars
# Key configurations:
# - region = "us-east-1"
# - aws_profile = "your-profile-name"  
# - node group configurations
# - enable/disable services for cost optimization

# Plan deployment
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan

# Wait for completion (~15 minutes)
```

### Step 2: Configure kubectl
```bash
# Update kubeconfig for both clusters
aws eks update-kubeconfig --region us-east-1 --name base-app-layer-dev-platform --alias platform
aws eks update-kubeconfig --region us-east-1 --name base-app-layer-dev-base --alias base

# Verify connectivity
kubectl --context=platform get nodes
kubectl --context=base get nodes
```

### Step 3: Deploy GitOps Stack
```bash
# Run ArgoCD deployment
cd .platform-services/scripts
./deploy-argo-stack.sh

# Get ArgoCD admin password
kubectl --context=platform -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access ArgoCD (in new terminal)
kubectl --context=platform port-forward svc/argocd-server -n argocd 8080:443
# Navigate to https://localhost:8080
```

### Step 4: Deploy Applications
```bash
# Apply ApplicationSets
kubectl --context=platform apply -f .platform-services/argocd/applicationsets/

# Monitor application deployment
kubectl --context=platform get applications -n argocd -w

# Check application health
kubectl --context=platform get applications -n argocd
```

### Step 5: Deploy Platform UI
```bash
# Deploy dashboard
kubectl --context=platform apply -f .platform-services/platform-ui/dashboard.yaml

# Check ingress status
kubectl --context=platform get ingress -n platform-ui

# Get ALB hostname
kubectl --context=platform get ingress platform-ui-ingress -n platform-ui -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Configuration Reference

### Terraform Variables (terraform.tfvars)
```hcl
# Basic Configuration
project_name = "base-app-layer"
environment  = "dev"
region      = "us-east-1"
aws_profile = "your-profile-name"

# Cost Optimization Flags
base_cluster_enabled     = true
platform_cluster_enabled = true
enable_monitoring        = true
enable_data_storage      = false  # Disable for cost savings
enable_databases         = false  # Disable for cost savings

# VPC Configuration
vpc_cidr                 = "10.0.0.0/16"
availability_zones_count = 2
nat_gateway_count        = 1

# Node Group Configuration
# Platform cluster has 5 specialized node groups:
# - platform_system: 100% On-Demand for ArgoCD, Load Balancers
# - platform_general: 60% On-Demand for general workloads
# - platform_compute: 30% On-Demand for ML/compute workloads  
# - platform_memory: 50% On-Demand for databases/caching
# - platform_gpu: 40% On-Demand for ML training (min 0, desired 0, max 2)

# IRSA Configuration
enable_irsa = true
# Pre-configured for ArgoCD, Airflow, Monitoring services
```

### ApplicationSet Configuration
Wave-based deployment order:
1. **Wave 1**: Istio (Service Mesh)
2. **Wave 2**: Vault, Vault Secrets Operator (Secrets Management)
3. **Wave 3**: Prometheus (Monitoring Foundation)
4. **Wave 4**: Airflow, MLflow (Orchestration)
5. **Wave 5**: Kubeflow, Grafana (Advanced Services)

## Monitoring and Troubleshooting

### Check Deployment Status
```bash
# Use built-in status checker
./full-deployment.sh status

# Manual checks
kubectl --context=platform get nodes
kubectl --context=platform get applications -n argocd
kubectl --context=platform get pods --all-namespaces
kubectl --context=base get pods --all-namespaces
```

### Common Issues and Solutions

#### 1. Node Group Creation Stuck
```bash
# Check AWS EKS console for detailed error messages
aws eks describe-nodegroup --cluster-name base-app-layer-dev-platform --nodegroup-name platform_system --region us-east-1

# Common causes:
# - Insufficient EC2 capacity in AZ
# - IAM permissions issues
# - Subnet configuration problems
```

#### 2. ArgoCD Applications OutOfSync
```bash
# Refresh applications
kubectl --context=platform patch application <app-name> -n argocd --type='merge' -p='{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Manual sync
kubectl --context=platform patch application <app-name> -n argocd --type='merge' -p='{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
```

#### 3. Load Balancer Controller Issues
```bash
# Check ALB controller pods
kubectl --context=platform get pods -n kube-system | grep aws-load-balancer

# Check logs
kubectl --context=platform logs -f deployment/aws-load-balancer-controller -n kube-system

# Common cause: Managed nodes not ready yet
```

#### 4. Platform UI Dashboard Not Accessible
```bash
# Check ingress status
kubectl --context=platform get ingress -n platform-ui

# Check ALB creation
aws elbv2 describe-load-balancers --region us-east-1 | grep base-platform-dashboard

# Verify DNS (if using custom domain)
nslookup platform.base-app-layer.dev
```

### Log Collection
```bash
# ArgoCD logs
kubectl --context=platform logs -f deployment/argocd-server -n argocd

# Application logs
kubectl --context=platform logs -f deployment/<service-name> -n <namespace>

# AWS Load Balancer Controller logs
kubectl --context=platform logs -f deployment/aws-load-balancer-controller -n kube-system

# Terraform logs
export TF_LOG=INFO
terraform apply
```

## Access Information

### Service Endpoints

Once deployed, you can access services via:

#### ArgoCD (GitOps Management)
```bash
# Port forward to local machine
kubectl --context=platform port-forward svc/argocd-server -n argocd 8080:443

# Access: https://localhost:8080
# Username: admin
# Password: Get with command below
kubectl --context=platform -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

#### Platform UI Dashboard
```bash
# Get ALB hostname
kubectl --context=platform get ingress platform-ui-ingress -n platform-ui -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Access via ALB hostname or configure DNS to point to ALB
# URL: http://<alb-hostname> or https://platform.base-app-layer.dev
```

#### Individual Services (via Platform Dashboard)
- **Airflow**: `/airflow` - Workflow orchestration
- **MLflow**: `/mlflow` - ML lifecycle management  
- **Kubeflow**: `/kubeflow` - ML workflows
- **Grafana**: `/grafana` - Monitoring dashboards
- **Prometheus**: `/prometheus` - Metrics collection
- **Vault**: `/vault` - Secrets management

### Direct Service Access (Alternative)
```bash
# Airflow
kubectl --context=platform port-forward svc/airflow-webserver -n airflow 8081:8080

# Grafana
kubectl --context=platform port-forward svc/prometheus-grafana -n monitoring 3000:80

# MLflow
kubectl --context=platform port-forward svc/mlflow-server -n mlflow 5000:5000

# Vault
kubectl --context=platform port-forward svc/vault -n vault 8200:8200
```

## Cost Optimization

### Default Configuration (Cost-Optimized)
- Single NAT gateway instead of one per AZ
- Spot instances with mixed instance policy
- Disabled non-essential services (databases, storage)
- GPU nodes with min=0, desired=0
- Smaller instance types (xlarge minimum)

### Further Cost Savings
```bash
# Destroy when not in use
./full-deployment.sh destroy

# Scale down node groups
aws eks update-nodegroup-config --cluster-name base-app-layer-dev-platform --nodegroup-name platform_general --scaling-config minSize=0,maxSize=3,desiredSize=0

# Use more Spot instances
# Edit terraform.tfvars to increase spot percentage in mixed_instances_policy
```

### Estimated Monthly Costs (us-east-1)
- **Minimal setup**: ~$200-300/month
- **Development setup**: ~$500-800/month  
- **Production setup**: ~$1500-3000/month

## Security Considerations

### IAM and RBAC
- All services use IRSA (IAM Roles for Service Accounts)
- ArgoCD projects with proper RBAC
- Separate clusters for data processing vs orchestration
- Least privilege access patterns

### Network Security
- Private subnets for all worker nodes
- Security groups with minimal required access
- VPC CNI for pod-level networking
- Istio service mesh for inter-service communication

### Secrets Management
- HashiCorp Vault for secrets storage
- Vault Secrets Operator for Kubernetes integration
- ArgoCD credentials stored securely
- No secrets in Git repositories

## Troubleshooting Guide

### Pre-Deployment Issues
1. **AWS credentials**: Verify with `aws sts get-caller-identity`
2. **IAM permissions**: Ensure EKS, EC2, VPC permissions
3. **Tool versions**: Check terraform, kubectl, aws-cli versions
4. **S3 bucket**: Terraform state bucket must exist

### During Deployment Issues
1. **Terraform locks**: Wait for operations to complete or use `terraform force-unlock`
2. **Resource limits**: Check AWS service quotas (EIPs, VPC endpoints)
3. **Node group failures**: Check EC2 capacity and subnet configurations
4. **Timeout issues**: Increase timeout values in scripts

### Post-Deployment Issues
1. **Applications not syncing**: Check ArgoCD project permissions
2. **Services not accessible**: Verify ingress and load balancer status
3. **Authentication failures**: Check IRSA role configurations
4. **Performance issues**: Monitor node resource utilization

## Next Steps

After successful deployment:

1. **Configure DNS**: Point `platform.base-app-layer.dev` to ALB
2. **SSL certificates**: Add ACM certificate to ingress
3. **Monitoring setup**: Configure Grafana dashboards
4. **BASE layer development**: Implement remaining 13 modules
5. **CI/CD pipelines**: Connect ArgoCD to Git repositories
6. **Backup strategy**: Configure Velero for cluster backups

## Support

For issues and questions:
1. Check this README for common solutions
2. Review ArgoCD applications status
3. Check Kubernetes events and logs
4. Verify AWS resource status in console
5. Use the validation script: `./full-deployment.sh validate`

## References

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [AWS EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)