# FinPortIQ Platform Services

Enterprise-grade financial data platform with BASE layer integration.

## Architecture

- **BASE Layer**: 14 foundational components with complete Kubernetes manifests
- **Platform Services**: Airflow, PostgreSQL, Kafka, Monitoring
- **ML Platform**: MLflow, Kubeflow, Seldon Core
- **Deployment**: Kustomize overlays + ArgoCD GitOps
- **Infrastructure**: Terraform + Crossplane multi-cloud

## Configuration

- **Cluster**: platform-services-dev
- **Environment**: dev
- **BASE Layer**: https://github.com/vsem-svoim/base-app-layer.git

## Quick Start

1. **Deploy Infrastructure**
   ```bash
   ./scripts/deployment/deploy.sh dev aws us-east-1
   ```

2. **Deploy Platform**
   ```bash
   kubectl apply -f argocd/bootstrap/root-app.yaml
   ```

## Directory Structure

```
platform-services/
├── argocd/                 # GitOps applications
├── kustomize/              # BASE layer overlays
├── terraform/              # Infrastructure as code
├── crossplane/             # Cloud-native infrastructure
├── helm-charts/            # Platform services
├── airflow/                # Data pipelines
├── ml-platform/            # ML services
├── monitoring/             # Observability
├── scripts/                # Deployment utilities
├── tests/                  # Testing suites
├── docs/                   # Documentation
├── policies/               # Security policies
└── config/                 # Environment configs
```

## BASE Layer Components

All 14 components deployed via Kustomize overlays:
- data-ingestion, data-control, data-distribution
- data-quality, data-security, data-storage
- data-streaming, event-coordination
- feature-engineering, metadata-discovery
- multimodal-processing, pipeline-management
- quality-monitoring, schema-contracts

## Next Steps

1. Configure your cloud provider
2. Deploy infrastructure with Terraform
3. Deploy BASE layer with ArgoCD
4. Configure monitoring and observability

Ready for provider-specific configuration and deployment!
