# FinPortIQ AWS Multi-Cluster Configuration

This directory contains a fully parameterized Terraform configuration for deploying a multi-cluster AWS infrastructure optimized for the FinPortIQ platform.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────┐  ┌─────────────────────────────────┐
│        BASE App Layer          │  │      Platform Services         │
│     EKS Cluster (1.33)         │  │     EKS Cluster (1.33)         │
├─────────────────────────────────┤  ├─────────────────────────────────┤
│  Node Groups:                   │  │  Node Groups:                   │
│  ├── base_compute (t3.medium)   │  │  ├── platform_general (t3.large)│
│  └── base_memory (r5.large)     │  │  ├── ml_workloads (m5.large)    │
│                                 │  │  └── airflow_workers (c5.large) │
│  Fargate:                       │  │                                 │
│  └── base-* namespaces          │  │  Fargate:                       │
│                                 │  │  ├── argocd, monitoring         │
│  Components:                    │  │  └── ml-* namespaces            │
│  ├── 14 BASE layer components   │  │                                 │
│  └── Isolated with taints       │  │  Services:                      │
└─────────────────────────────────┘  │  ├── ArgoCD (GitOps)            │
                                     │  ├── Airflow (Orchestration)    │
                                     │  ├── Crossplane (IaC)           │
                                     │  ├── ML Platform                │
                                     │  └── Monitoring Stack           │
                                     └─────────────────────────────────┘
```

## 📋 Quick Configuration Guide

### 1. Basic Settings
```hcl
project_name = "platform-services"
environment  = "dev"
region      = "us-east-1"
```

### 2. VPC Configuration
```hcl
vpc_cidr                = "10.0.0.0/16"    # VPC CIDR block
availability_zones_count = 3               # Number of AZs (2-6)
private_subnets_count   = 1                # Private subnets per AZ
public_subnets_count    = 1                # Public subnets per AZ

# NAT Gateway Options:
nat_gateway_count       = 3                # Total NAT gateways
single_nat_gateway      = false            # true = single NAT for all
one_nat_gateway_per_az  = true             # true = one NAT per AZ (HA)
```

### 3. Cluster Enablement
```hcl
base_cluster_enabled     = true            # Enable BASE layer cluster
platform_cluster_enabled = true            # Enable platform services cluster
```

### 4. EKS Version
Both clusters use **EKS 1.33** by default:
```hcl
base_cluster_config = {
  version = "1.33"                         # Latest EKS version
  # ...
}
platform_cluster_config = {
  version = "1.33"                         # Latest EKS version
  # ...
}
```

## 🎛️ Advanced Configuration Options

### Instance Type Selection

**BASE Layer Cluster:**
- `base_compute`: General workloads (t3.medium, t3.large)
- `base_memory_optimized`: Data processing (r5.large, r5.xlarge)

**Platform Services Cluster:**
- `platform_general`: Platform services (t3.large, t3.xlarge)
- `ml_workloads`: ML training/inference (m5.large, m5.xlarge, m5.2xlarge)
- `airflow_workers`: Workflow orchestration (c5.large, c5.xlarge)

### Capacity Types
- **ON_DEMAND**: Reliable, always available
- **SPOT**: Cost-effective, can be interrupted

### Node Group Scaling
```hcl
min_size     = 1    # Minimum nodes
max_size     = 10   # Maximum nodes
desired_size = 3    # Starting nodes
```

### Taints and Tolerations
Workload isolation using Kubernetes taints:
- BASE layer: `base-layer=true:NoSchedule`
- ML workloads: `ml-workload=true:NoSchedule`
- Airflow: `airflow=true:NoSchedule`

## 🔧 Common Configuration Scenarios

### Scenario 1: Cost-Optimized Development
```hcl
# Reduce NAT gateways
single_nat_gateway = true
nat_gateway_count  = 1

# Use SPOT instances
managed_node_groups = {
  base_compute = {
    capacity_type = "SPOT"
    desired_size  = 1
    # ...
  }
}
```

### Scenario 2: High-Availability Production
```hcl
# Multiple NAT gateways for HA
one_nat_gateway_per_az = true
nat_gateway_count      = 3

# ON_DEMAND instances for reliability
managed_node_groups = {
  platform_general = {
    capacity_type = "ON_DEMAND"
    desired_size  = 5
    # ...
  }
}
```

### Scenario 3: ML-Heavy Workloads
```hcl
# Larger ML node group
managed_node_groups = {
  ml_workloads = {
    instance_types = ["m5.2xlarge", "m5.4xlarge"]
    max_size      = 100
    desired_size  = 10
    # ...
  }
}
```

## 🚀 Deployment Commands

### 1. Initialize Terraform
```bash
cd terraform/environments/dev
terraform init
```

### 2. Plan Infrastructure
```bash
terraform plan -var-file="terraform.tfvars"
```

### 3. Deploy Infrastructure
```bash
terraform apply -var-file="terraform.tfvars"
```

### 4. Configure kubectl Access
```bash
# BASE layer cluster
aws eks update-kubeconfig --region us-east-1 --name platform-services-base-layer-dev --alias base-layer

# Platform services cluster
aws eks update-kubeconfig --region us-east-1 --name platform-services-platform-services-dev --alias platform-services
```

## 📊 Cost Optimization Tips

1. **Use SPOT instances** for non-critical workloads
2. **Enable cluster autoscaler** to scale nodes based on demand
3. **Use single NAT gateway** for development environments
4. **Right-size instance types** based on actual usage
5. **Enable Fargate** for lightweight, event-driven workloads

## 🔒 Security Features

1. **Private subnets** for all worker nodes
2. **IAM Roles for Service Accounts (IRSA)** for secure AWS access
3. **Network isolation** using security groups
4. **Workload isolation** using taints and tolerations
5. **Separate clusters** for different security zones

## 🔍 Monitoring and Observability

The configuration includes IRSA roles for:
- **CloudWatch** monitoring integration
- **Prometheus** metrics collection
- **Grafana** dashboard access
- **AWS X-Ray** distributed tracing

## 📚 Additional Resources

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Managed Node Groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html)
- [AWS Fargate for EKS](https://docs.aws.amazon.com/eks/latest/userguide/fargate.html)

## 🆘 Troubleshooting

### Common Issues:

1. **Insufficient IAM permissions**: Ensure your AWS profile has sufficient permissions
2. **VPC CIDR conflicts**: Check for existing VPCs with overlapping CIDRs
3. **Instance type availability**: Some instance types may not be available in all regions
4. **EKS version**: Ensure EKS 1.33 is available in your selected region

### Getting Help:

1. Check Terraform output for specific error messages
2. Review AWS CloudFormation events in the console
3. Verify IAM permissions using AWS CloudTrail
4. Check AWS service limits and quotas
