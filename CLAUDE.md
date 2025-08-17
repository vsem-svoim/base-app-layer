# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the **BASE App Layer** - a comprehensive enterprise data platform with 14 specialized modules providing foundational data processing capabilities. The platform follows an agent-based, microservices architecture with AI/ML enhancements for financial data processing.

## Architecture

### Core Structure
- **14 BASE Modules**: Each implementing a specific data processing domain (ingestion, quality, security, etc.)
- **Platform Services**: GitOps infrastructure layer with Terraform, ArgoCD, and Kubernetes orchestration
- **Agent-Based Design**: Each module contains 6 specialized agents with ML models and orchestrators
- **Microservices**: 12 microservices per module (168 total across all modules)

### Module Categories
**Data Foundation:**
- `data_ingestion/` - Multi-protocol data acquisition (100GB/hour throughput)
- `data_quality/` - Validation, cleaning, and quality assurance
- `data_storage/` - Distributed storage with lifecycle management
- `data_security/` - Encryption, classification, and access control

**Processing & Analytics:**
- `feature_engineering/` - ML feature extraction and transformation
- `multimodal_processing/` - Text, image, geospatial, time-series processing
- `data_streaming/` - Real-time stream processing with Kafka
- `quality_monitoring/` - Continuous monitoring and anomaly detection

**Orchestration & Management:**
- `pipeline_management/` - Workflow orchestration and dependency management
- `event_coordination/` - Event-driven architecture and saga patterns
- `metadata_discovery/` - Data cataloging and lineage tracking
- `schema_contracts/` - Schema management and data contracts

**Distribution & Control:**
- `data_distribution/` - API management and data delivery
- `data_control/` - Governance and control plane services

## Development Commands

### Automated Platform Deployment (NEW - Recommended)
```bash
# Full automated deployment (infrastructure + platform + applications)
cd platform-services/scripts
./full-deployment.sh

# Deploy specific components only
./full-deployment.sh infrastructure  # Deploy only Terraform infrastructure
./full-deployment.sh gitops         # Deploy only ArgoCD, Workflows, Rollouts
./full-deployment.sh apps           # Deploy only orchestration applications
./full-deployment.sh base-layer     # Deploy only BASE layer modules
./full-deployment.sh crossplane     # Enable Crossplane infrastructure platform

# Monitoring and validation
./full-deployment.sh validate       # Validate deployment and show status
./full-deployment.sh status         # Show current deployment status
./full-deployment.sh destroy        # Destroy entire deployment

# Environment variables (optional)
REGION=us-west-2 ENVIRONMENT=staging ./full-deployment.sh
```

### Legacy Platform Deployment
```bash
# Deploy entire platform (AWS) - Legacy method
./stage2-aws-provider.sh --region us-east-1

# Deploy via Makefile - Legacy method
make deploy ENV=dev PROVIDER=aws REGION=us-east-1

# Deploy specific environment - Legacy method
cd platform-services
./scripts/deployment/deploy.sh dev aws us-east-1
```

### Testing
```bash
# Run platform tests
make test
cd platform-services && ./scripts/testing/run-tests.sh

# Data ingestion module testing
cd data_ingestion/testing
pip install -r requirements.txt
python scripts/capability_tester.py
```

### Infrastructure Management
```bash
# Terraform operations
cd platform-services/terraform/environments/dev
terraform init
terraform plan
terraform apply

# Kubernetes deployment via Kustomize
kubectl apply -k platform-services/kustomize/base-layer/data-ingestion/overlays/aws
```

### Monitoring and Validation
```bash
# Check deployment status
kubectl get applications -n argocd -o custom-columns=NAME,PROJECT,SYNC,HEALTH

# Monitor specific module
kubectl get pods -n base-data-ingestion
kubectl logs -f deployment/base-data-ingestion-agent-data-collector

# Access services
kubectl port-forward svc/argocd-server -n argocd 8080:443      # ArgoCD
kubectl port-forward svc/airflow-webserver -n airflow 8081:8080 # Airflow
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80 # Grafana
```

## Key Implementation Patterns

### Agent-Based Architecture
Each module follows consistent patterns:
- **Agents** (`agents/`): 6 specialized autonomous processing units
- **Models** (`models/`): 5 AI/ML models for intelligent decision-making  
- **Orchestrators** (`orchestrators/`): 5 coordination and management components
- **Workflows** (`workflows/`): 5 end-to-end process definitions
- **Configs** (`configs/`): 4 operational parameter modules
- **Prompts** (`prompts/`): 6 AI instructions for LLM processing

### Naming Convention
All components follow: `base-[module]-[type]-[descriptor].[extension]`

Examples:
- `base-data-ingestion-agent-data-collector.yaml`
- `base-data-quality-model-outlier-detection.yaml`
- `base-pipeline-management-orchestrator-master-manager.yaml`

### GitOps Integration
- **ArgoCD Applications**: Auto-sync from Git with wave deployment
- **Kustomize Overlays**: Environment-specific configurations (dev/staging/prod + cloud providers)
- **ApplicationSets**: Automated deployment of all 14 modules
- **Multi-cloud Support**: AWS/Azure/GCP overlays via Kustomize

## Technology Stack

### Core Infrastructure
- **Kubernetes**: Container orchestration platform
- **Terraform**: Multi-cloud infrastructure as code
- **ArgoCD**: GitOps continuous deployment
- **Crossplane**: Kubernetes-native infrastructure management

### Data Platform
- **Apache Airflow**: Business process orchestration
- **Kafka/Kinesis**: Stream processing and messaging
- **PostgreSQL**: Metadata and configuration storage
- **MLflow/Seldon**: ML model lifecycle and serving

### Monitoring & Observability
- **Prometheus/Grafana**: Metrics and dashboards
- **ELK Stack**: Centralized logging
- **Jaeger**: Distributed tracing
- **AlertManager**: Alert routing and notifications

## Module Status

### Currently Implemented
- ✅ **data_ingestion**: Full production implementation with 12 microservices
  - Location: `data_ingestion/`
  - Status: Production-ready with comprehensive testing
  - Features: 100GB/hour throughput, multi-protocol support, AI-enhanced processing

### Planned Modules (13 remaining)
All other modules exist as YAML specifications following the same architectural patterns but require full implementation.

## Important Notes

### Security & Compliance
- All modules implement enterprise security (SOX, GDPR, FINRA compliance)
- Multi-factor authentication and RBAC across all services
- End-to-end encryption and audit logging

### Performance Targets
- **Throughput**: 100GB/hour per data ingestion agent
- **Scalability**: Auto-scaling 2-20 replicas based on load
- **Availability**: 99.9% uptime with circuit breakers and retry logic
- **Recovery**: RTO 4 hours, RPO 15 minutes

### Financial Industry Integration
- Pre-configured for 50+ financial data sources (Bloomberg, Reuters, NYSE)
- Market hours awareness and holiday calendars
- Regulatory compliance and audit trail requirements
- Real-time risk monitoring and alerting

## Working with This Codebase

### When Adding New Features
1. Follow the agent-based patterns established in `data_ingestion/`
2. Implement all 6 component categories (agents, models, orchestrators, workflows, configs, prompts)
3. Add Kubernetes manifests with consistent naming conventions
4. Include ArgoCD application definitions
5. Add monitoring and health check endpoints

### When Debugging Issues
1. Check ArgoCD sync status: `kubectl get applications -n argocd`
2. Verify pod health: `kubectl get pods -n base-[module-name]`
3. Review logs: `kubectl logs -f deployment/[service-name]`
4. Check service discovery and networking between modules
5. Validate Kustomize overlays for environment-specific configs

### When Deploying
1. Always deploy infrastructure first (Terraform)
2. Use wave-based deployment through ArgoCD ApplicationSets
3. Monitor deployment health through Grafana dashboards
4. Validate inter-module communication and data flow
5. Run end-to-end tests before promoting to production

This platform represents a comprehensive enterprise data processing foundation with production-grade reliability, security, and scalability built for financial industry requirements.