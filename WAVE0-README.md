# Wave 0 Deployment Guide
## Platform Foundation Services

This guide covers the deployment and configuration of Wave 0 services - the foundational infrastructure for the BASE App Layer platform.

## Architecture Overview

Wave 0 establishes the core foundation services required for GitOps-based platform management:

```
Wave 0: Foundation Layer
├── ArgoCD                 - GitOps continuous deployment
├── cert-manager          - TLS certificate management  
├── AWS Load Balancer     - ALB/NLB management
├── Vault                 - Secrets management
└── Platform UI           - Unified dashboard
```

## Prerequisites

- EKS cluster running with appropriate node groups
- kubectl configured and connected to cluster
- AWS CLI configured with appropriate permissions
- Helm 3.x installed (optional, for AWS LB Controller)

## Quick Start

### 1. Deploy Wave 0 Services

```bash
# Full automated deployment
./deploy-wave0-complete.sh

# Or deploy individual components
./deploy-wave0-complete.sh argocd
./deploy-wave0-complete.sh cert-manager
./deploy-wave0-complete.sh aws-lb
./deploy-wave0-complete.sh vault
./deploy-wave0-complete.sh platform-ui
```

### 2. Configure GitOps

```bash
# Full configuration
./configure-wave0.sh

# Or configure individual aspects
./configure-wave0.sh repositories
./configure-wave0.sh projects
./configure-wave0.sh applicationsets
```

### 3. Validate Deployment

```bash
# Check deployment status
./deploy-wave0-complete.sh validate

# Troubleshoot if needed
./configure-wave0.sh troubleshoot
```

## Detailed Component Information

### ArgoCD (GitOps Core)
- **Purpose**: Continuous deployment and GitOps management
- **Namespace**: `argocd`
- **Key Features**:
  - Self-managing GitOps platform
  - Application lifecycle management
  - Multi-cluster support
  - Web UI and CLI access

**Access**:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# URL: https://localhost:8080
# Username: admin
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### cert-manager (TLS Management)
- **Purpose**: Automatic TLS certificate provisioning and management
- **Namespace**: `cert-manager`
- **Key Features**:
  - Let's Encrypt integration
  - Certificate lifecycle management
  - Kubernetes-native certificate resources

### AWS Load Balancer Controller
- **Purpose**: AWS ALB/NLB integration for Kubernetes
- **Namespace**: `kube-system`
- **Key Features**:
  - Application Load Balancer provisioning
  - Network Load Balancer support
  - Target group management
  - Integration with Kubernetes Ingress

### Vault (Secrets Management)
- **Purpose**: Centralized secrets management and encryption
- **Namespace**: `vault`
- **Configuration**: Development mode with root token
- **Key Features**:
  - Secret storage and retrieval
  - Dynamic secrets generation
  - Encryption as a service
  - Kubernetes authentication

**Access**:
```bash
kubectl port-forward svc/vault -n vault 8200:8200
# URL: http://localhost:8200
# Token: root (dev mode)
```

### Platform UI (Dashboard)
- **Purpose**: Unified platform monitoring and management interface
- **Namespace**: `platform-ui`
- **Key Features**:
  - Service status monitoring
  - Health dashboards
  - API status tracking
  - Application management

**Access**:
```bash
kubectl port-forward svc/platform-ui-proxy -n platform-ui 8081:80
# URL: http://localhost:8081
```

## GitOps Configuration

After Wave 0 deployment, the platform is configured for GitOps management:

### Repository Configuration
- Default repository: `https://github.com/vsem-svoim/base-app-layer.git`
- Branch: `main`
- Path-based application organization

### ApplicationSets Structure
```
platform-services-v2/automation/gitops/applicationsets/
├── wave0-core-services.yaml       # Foundation services
├── wave1-shared-services.yaml     # Istio, monitoring prep
├── wave2-monitoring-logging.yaml  # Observability stack
└── wave3-application-services.yaml # ML/orchestration
```

### Project Organization
- `platform-core`: Core infrastructure services
- `platform-shared`: Shared platform services
- `platform-orchestration`: ML and workflow services
- `base-layer`: Data processing modules

## Next Wave Deployment

After Wave 0 is complete and validated:

### Wave 1: Shared Services
```bash
kubectl apply -f platform-services-v2/automation/gitops/applicationsets/wave1-shared-services.yaml
```

Components:
- Istio Service Mesh
- Platform UI enhancements
- API Gateway

### Wave 2: Monitoring & Logging
```bash
kubectl apply -f platform-services-v2/automation/gitops/applicationsets/wave2-monitoring-logging.yaml
```

Components:
- Prometheus & Grafana
- ELK Stack (Elasticsearch, Logstash, Kibana)
- Jaeger tracing

### Wave 3: Application Services
```bash
kubectl apply -f platform-services-v2/automation/gitops/applicationsets/wave3-application-services.yaml
```

Components:
- Apache Airflow
- MLflow
- Kubeflow
- Argo Workflows

## Troubleshooting

### Common Issues

1. **ArgoCD Pods Not Starting**
   ```bash
   # Check node selector constraints
   kubectl describe pods -n argocd
   
   # Verify node groups
   kubectl get nodes -l eks.amazonaws.com/nodegroup=platform_system
   ```

2. **AWS Load Balancer Controller Webhook Issues**
   ```bash
   # Check webhook endpoints
   kubectl get endpoints aws-load-balancer-webhook-service -n kube-system
   
   # Restart if needed
   kubectl rollout restart deployment/aws-load-balancer-controller -n kube-system
   ```

3. **Vault Pod Image Pull Issues**
   ```bash
   # Check image availability
   kubectl describe pod -n vault
   
   # Use alternative image if needed
   # Edit deployment to use hashicorp/vault:1.17.2
   ```

4. **Certificate Manager Validation Failures**
   ```bash
   # Check webhook configuration
   kubectl get validatingwebhookconfiguration cert-manager-webhook
   
   # Verify webhook pod is running
   kubectl get pods -n cert-manager -l app=webhook
   ```

### Diagnostic Commands

```bash
# Overall cluster health
kubectl get nodes
kubectl get pods --all-namespaces | grep -v Running

# Wave 0 specific checks
kubectl get pods -n argocd
kubectl get pods -n cert-manager  
kubectl get pods -n vault
kubectl get pods -n platform-ui
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Service connectivity
kubectl get svc --all-namespaces
kubectl get ingress --all-namespaces

# GitOps status
kubectl get applications -n argocd
kubectl get applicationsets -n argocd
```

### Log Analysis

```bash
# ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# AWS LB Controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Vault logs
kubectl logs -n vault -l app=vault
```

## Security Considerations

1. **ArgoCD Access**: Change default admin password after deployment
2. **Vault**: Replace dev mode with production configuration
3. **TLS**: Configure certificate issuers for production domains
4. **RBAC**: Review and customize ArgoCD permissions
5. **Network Policies**: Implement service-to-service communication controls

## Performance Tuning

1. **Resource Limits**: Adjust based on cluster capacity
2. **Replica Counts**: Scale based on availability requirements
3. **Node Selectors**: Ensure proper node placement
4. **Health Checks**: Tune readiness/liveness probe timings

## Backup and Recovery

1. **ArgoCD**: Backup application definitions and configurations
2. **cert-manager**: Backup certificate resources and issuers
3. **Vault**: Backup vault data and unseal keys
4. **Cluster State**: Regular etcd backups

## Support and Documentation

- **ArgoCD**: https://argo-cd.readthedocs.io/
- **cert-manager**: https://cert-manager.io/docs/
- **AWS Load Balancer Controller**: https://kubernetes-sigs.github.io/aws-load-balancer-controller/
- **Vault**: https://www.vaultproject.io/docs/
- **Platform Issues**: Check troubleshooting section above

---

**Status**: ✅ Wave 0 Ready for Production
**Next Phase**: Wave 1 Shared Services Deployment