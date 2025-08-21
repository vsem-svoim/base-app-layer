# GitHub Actions Workflows for BASE App Layer

This directory contains GitHub Actions workflows for automating deployment and monitoring of the BASE App Layer platform.

## Workflows

### 🚀 ArgoCD Deployment Pipeline (`argocd-deployment.yml`)

**Triggers:**
- Push to `main` branch (when platform/base services change)
- Pull requests (validation only)
- Manual workflow dispatch

**Features:**
- **Smart Path Detection**: Only deploys changed services
- **Dual-Cluster Support**: Deploys to both Platform and Base clusters
- **Validation**: Validates Kubernetes manifests and Kustomizations
- **Wave-Based Deployment**: Respects ArgoCD sync waves
- **Force Sync Option**: Manual trigger with force sync capability

**Jobs:**
1. `validate` - Validates all Kubernetes manifests and Kustomizations
2. `deploy-platform` - Deploys Platform cluster services (ArgoCD, Airflow, etc.)
3. `deploy-base` - Deploys BASE cluster services (data processing modules)
4. `notify` - Sends deployment summary

### ✅ Validate Manifests (`validate-manifests.yml`)

**Triggers:**
- Pull requests with YAML changes
- Manual workflow dispatch

**Features:**
- YAML syntax validation with yamllint
- Kubernetes manifest validation
- Kustomization build testing
- ApplicationSet syntax checking

### 🏥 Health Check (`health-check.yml`)

**Triggers:**
- Scheduled (every 6 hours)
- Manual workflow dispatch

**Features:**
- Platform cluster health monitoring
- Base cluster health monitoring  
- ArgoCD application status checks
- AI prompts ConfigMaps verification
- Failed application detection

## Required Secrets

Configure these secrets in your GitHub repository settings:

```
AWS_ACCESS_KEY_ID          # AWS access key for EKS access
AWS_SECRET_ACCESS_KEY      # AWS secret key for EKS access
GITHUB_TOKEN               # Automatically provided by GitHub
```

## Manual Triggers

### Deploy Specific Cluster
```bash
# Deploy only Platform cluster
gh workflow run argocd-deployment.yml -f cluster=platform -f force_sync=true

# Deploy only BASE cluster  
gh workflow run argocd-deployment.yml -f cluster=base -f force_sync=true

# Deploy both clusters
gh workflow run argocd-deployment.yml -f cluster=both -f force_sync=true
```

### Run Health Check
```bash
# Check both clusters
gh workflow run health-check.yml -f cluster=both

# Check specific cluster
gh workflow run health-check.yml -f cluster=platform
```

### Validate Manifests
```bash
gh workflow run validate-manifests.yml
```

## Architecture Integration

### Platform Cluster Services
- ArgoCD (GitOps controller)
- Vault (secrets management)
- Cert-Manager (TLS certificates)
- AWS Load Balancer Controller
- Istio Service Mesh
- Platform UI (dashboard)
- Monitoring & Logging
- Orchestration (Airflow, MLflow, Kubeflow, Superset, Seldon)
- **API Gateway** (external access management)

### Base Cluster Services
- **Data Services** (BASE module integration gateway)
- All 14 BASE data processing modules:
  - Wave 4: data-ingestion, data-quality, data-storage, data-security
  - Wave 5: feature-engineering, multimodal-processing, data-streaming, quality-monitoring
  - Wave 6: pipeline-management, event-coordination, metadata-discovery, schema-contracts  
  - Wave 7: data-distribution, data-control

## Monitoring & Alerts

The workflows provide comprehensive monitoring:

- ✅ **Deployment Status**: Success/failure notifications
- ✅ **Application Health**: Continuous health monitoring
- ✅ **Resource Status**: Pod and service health checks
- ✅ **AI Prompts**: Verification that prompt ConfigMaps are deployed
- ✅ **Cross-Cluster**: Both Platform and Base cluster monitoring

## Troubleshooting

### Common Issues

1. **AWS Authentication Failed**
   - Verify AWS credentials are set correctly
   - Check IAM permissions for EKS access

2. **kubectl Context Issues**
   - Workflows automatically configure contexts
   - Uses `platform-cluster` and `base-cluster` context names

3. **Application Sync Failures**
   - Check ArgoCD server connectivity
   - Verify GitHub token has repository access
   - Check ApplicationSet configurations

4. **Validation Failures**
   - Review YAML syntax with yamllint
   - Verify Kubernetes resource definitions
   - Test Kustomizations locally

### Debug Commands

```bash
# Check workflow runs
gh run list --workflow=argocd-deployment.yml

# View workflow logs
gh run view <run-id>

# Check ArgoCD applications
kubectl --context platform-cluster get applications -n argocd

# Check BASE cluster deployments
kubectl --context base-cluster get namespaces | grep base-
```

## Best Practices

1. **Pull Request Workflow**: Always validate changes via PR before merging
2. **Manual Testing**: Use workflow dispatch for testing deployments
3. **Health Monitoring**: Regular health checks via scheduled workflow
4. **Rollback Strategy**: Use ArgoCD UI for quick rollbacks if needed
5. **Secret Management**: Keep AWS credentials secure and rotate regularly

---

🤖 **Generated with [Claude Code](https://claude.ai/code)**