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

## ApplicationSet Management (GitOps Automated)

### Current ApplicationSets Status
```bash
# Check all ApplicationSets
kubectl get applicationsets -n argocd

# Current ApplicationSets:
# ✅ wave1-shared-services: Istio, Monitoring, Logging
# ✅ wave2-orchestration-services: Airflow, MLflow, Kubeflow, Superset, Seldon  
# ✅ wave3-application-services: API Gateway, Data Services
```

### ApplicationSet Deployment Commands
```bash
# Deploy Wave 1 ApplicationSet
kubectl apply -f platform-services-v2/automation/gitops/applicationsets/wave1-shared-services.yaml

# Deploy Wave 3 ApplicationSet  
kubectl apply -f platform-services-v2/automation/gitops/applicationsets/wave3-application-services.yaml

# Check generated applications with wave labels
kubectl get applications -n argocd -o custom-columns=NAME,SYNC,HEALTH,WAVE:.metadata.annotations.argocd\.argoproj\.io/sync-wave
```

### Manual Sync Commands
```bash
# Trigger sync for new Wave 3 applications
kubectl patch application api-gateway -n argocd --type merge -p '{"operation":{"sync":{}}}'
kubectl patch application data-services -n argocd --type merge -p '{"operation":{"sync":{}}}'
```

## Development Commands

### Platform Services v2 Architecture (CURRENT - Recommended)
```bash
# Full automated deployment with improved wave-based architecture
cd platform-services-v2/automation/scripts
./deploy-platform.sh

# Wave-based component deployment with dependency validation
./deploy-platform.sh core          # Wave 0: ArgoCD, Vault, Cert-Manager, AWS LB Controller
./deploy-platform.sh shared        # Wave 1: Monitoring, Logging, Service Mesh
./deploy-platform.sh orchestration # Wave 2: Airflow, MLflow, Kubeflow, Argo Workflows
./deploy-platform.sh apps          # Wave 3: Platform UI, API Gateway, Data Services

# Platform validation and health checks
./validate-platform.sh             # Comprehensive platform validation
./validate-platform.sh core        # Core services validation
./validate-platform.sh security    # Security and RBAC validation

# Environment-specific deployment
ENVIRONMENT=staging REGION=us-west-2 ./deploy-platform.sh
```

### Complete Platform Reset (Clean Slate)
```bash
# Destroy all applications while preserving infrastructure
./destroy-all-applications.sh full  # Complete cleanup with confirmations
./destroy-all-applications.sh quick # Fast cleanup with minimal prompts

# Selective cleanup options
./destroy-all-applications.sh applications  # Remove only ArgoCD applications
./destroy-all-applications.sh services      # Remove only platform services
```

### Legacy Platform Deployment (Archived)
```bash
# Old deployment method (moved to .platform-services)
cd .platform-services/scripts
./full-deployment.sh

# Legacy individual component deployment
./full-deployment.sh infrastructure  # Deploy only Terraform infrastructure
./full-deployment.sh gitops         # Deploy only ArgoCD, Workflows, Rollouts
./full-deployment.sh apps           # Deploy only orchestration applications
./full-deployment.sh base-layer     # Deploy only BASE layer modules
```

### Original Scripts (Historical)
```bash
# Original deployment scripts (still available but deprecated)
./stage2-aws-provider.sh --region us-east-1

# Original Makefile deployment
make deploy ENV=dev PROVIDER=aws REGION=us-east-1
```

### Testing and Validation
```bash
# Platform health validation (v2)
cd platform-services-v2/automation/scripts
./validate-platform.sh             # Full platform validation
./validate-platform.sh core        # Core services only
./validate-platform.sh security    # Security validation

# Legacy testing (archived)
cd .platform-services && ./scripts/testing/run-tests.sh

# BASE module testing
cd data_ingestion/testing
pip install -r requirements.txt
python scripts/capability_tester.py
```

### Infrastructure Management
```bash
# Terraform operations (v2 structure)
cd platform-services-v2/bootstrap/terraform/providers/aws/environments/dev
terraform init
terraform plan
terraform apply

# Legacy Terraform (archived)
cd .platform-services/terraform/environments/dev
terraform init && terraform plan && terraform apply

# Kubernetes deployment via Kustomize (updated paths)
kubectl apply -k platform-services-v2/application-services/platform-ui/overlays/dev
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

## Current Project Status & Objectives (Updated 2025-08-21 17:00 UTC)

### Recent Deployment Progress ✅
- ✅ **Wave 0 Complete**: ArgoCD, Vault, Cert-Manager, AWS LB Controller fully deployed
- ✅ **Wave 1 Complete**: Platform UI with modern dashboard, Istio service mesh operational
- ✅ **Apache Airflow Deployed**: Workflow orchestration with Platform UI integration 
- ✅ **Service Isolation Fixed**: Removed duplicate platform-ui deployment from argocd namespace
- ✅ **Fargate Compatibility**: Fixed NET_ADMIN capability issues for Istio sidecar injection
- ✅ **Health Check Endpoints**: Corrected Airflow health probes from `/login` to `/health`
- ✅ **GitOps Alignment**: ApplicationSets now accurately reflect deployed services
- ✅ **Service Configuration Fixes**: Corrected upstream service names and node selectors
- ✅ **Repository Cleanup**: Added proper .gitignore to exclude Istio binaries and temporary files

### Current Platform Status (Updated 2025-08-21)
**Live Production Environment with Professional Platform UI:**
- **Platform UI**: ✅ https://k8s-platform-platform-909bd21b57-121932925.us-east-1.elb.amazonaws.com/
  - **Applications Tab**: Professional service gallery with clean enterprise cards
  - **API Status Tab**: Real-time endpoint monitoring with response times
  - **Health Monitoring Tab**: System metrics, resource utilization dashboard
- **ArgoCD**: ✅ Accessible via /argocd/ proxy (GitOps continuous delivery)
- **Apache Airflow**: ✅ Accessible via /airflow/ proxy (workflow orchestration)
- **MLflow**: ✅ Accessible via /mlflow/ proxy (ML lifecycle management, 2Gi memory)
- **Apache Superset**: ✅ Accessible via /superset/ proxy (business intelligence)
- **Kiali**: ✅ Accessible via /kiali/ proxy (service mesh observability)
- **Vault**: ⚠️ Accessible via /vault/ proxy (requires manual unseal)
- **Kubeflow**: 🔄 Accessible via /kubeflow/ proxy (API server initializing)

### Wave-Based Deployment Status (Updated 2025-08-21)
- **Wave 0 (Core)**: ✅ 100% Complete - ArgoCD, Vault, Cert-Manager, AWS LB Controller (Manual deployment)
- **Wave 1 (Shared)**: ✅ 100% Complete - Platform UI, Istio Service Mesh (✅ **ApplicationSet Active**)
- **Wave 2 (Orchestration)**: ✅ 95% Complete - Airflow, MLflow, Kubeflow, Superset, Seldon (✅ **ApplicationSet Active**)
- **Wave 3 (Applications)**: ⏳ 0% Started - Not actually deployed (ApplicationSet removed to match reality)
- **Waves 4-7 (BASE)**: ⏳ 0% Started - 14 data processing modules ready for infrastructure

### Current Tasks in Progress (Updated 2025-08-21)
1. **Wave 2 Final Resolution** (Active):
   - Kubeflow: 🔄 API server initializing (MySQL database setup, ~5-10 minutes)
   - Vault Unseal: ⚠️ Implement automated unseal solution (API proxy configuration needed)
   - Platform Monitoring: ✅ Professional UI with real-time health tracking operational

2. **Recently Completed** (2025-08-21):
   - ✅ **Platform UI Professional Redesign**: Complete enterprise dashboard overhaul
   - ✅ **ConfigMap Size Optimization**: Split large HTML into separate ConfigMaps
   - ✅ **MLflow Resolution**: Fixed OOMKilled issues with 2Gi memory limits
   - ✅ **Apache Superset**: Deployed with proper proxy configuration
   - ✅ **Service Integration**: All Wave 2 services integrated with unified NGINX proxy

3. **Next Phase Planning** (Wave 3 Preparation):
   - API Gateway deployment for external access management
   - Data Services gateway for BASE module integration
   - External ingress and load balancer configurations

4. **BASE Module Implementation** (✅ COMPLETED):
   - ✅ **65 kustomization.yaml files created** across agents/, models/, orchestrators/, workflows/, configs/
   - ✅ **14 data processing modules** ready for Wave 4-7 deployment with proper GitOps structure
   - ✅ **ApplicationSets created** for Wave 4-7 BASE modules deployment
   - ✅ **Complete infrastructure foundation** established with domain-specific naming

### Todo List (Session Completed 2025-08-21)
**Status: Wave 2 Orchestration Services Complete - GitOps Configuration Fixed**

✅ **Completed Today:**
- ✅ Professional Platform UI Redesign - Complete enterprise dashboard overhaul
- ✅ ConfigMap Size Optimization - Split large HTML content into separate ConfigMaps  
- ✅ Service Integration - All Wave 2 orchestration services integrated with NGINX proxy
- ✅ MLflow Resolution - Fixed OOMKilled issues with 2Gi memory limits
- ✅ Apache Superset - Deployed with proper proxy configuration
- ✅ API Monitoring - Real-time endpoint health tracking with response times
- ✅ Health Dashboard - System metrics and resource utilization monitoring
- ✅ Fix duplicate platform-ui in argocd namespace - FIXED
- ✅ Airflow deployment with correct health checks
- ✅ Enterprise Styling - Removed "Gen AI" branding, implemented professional design
- ✅ **ApplicationSet Alignment** - Updated Wave 1 and 2 ApplicationSets to match actual deployed services
- ✅ **GitOps Cleanup** - Removed theoretical Wave 3 ApplicationSet, aligned automation with reality
- ✅ **Service Configuration Fixes** - Fixed API Gateway upstream service names (airflow-webserver → airflow)
- ✅ **Node Selector Standardization** - Updated all services to use platform_system nodegroup
- ✅ **Repository Hygiene** - Added comprehensive .gitignore for Istio binaries and build artifacts
- ✅ **BASE Modules Implementation** - Created 65 kustomization files for all 14 data processing modules
- ✅ **Wave 4-7 ApplicationSets** - Complete GitOps deployment structure for BASE modules

🔄 **Remaining Issues:**
- Kubeflow API server initialization (MySQL setup in progress, ~5-10 minutes)
- Vault automated unseal solution (requires API proxy configuration)
- Cert-manager cainjector RBAC permissions issue

📋 **Next Phase - BASE Modules Deployment Status:**
- ✅ ApplicationSets now match actual deployed services (Wave 1: Platform UI + Istio, Wave 2: Orchestration services)
- ✅ Wave 3 ApplicationSet removed as those services were never actually deployed
- ✅ Service configurations fixed (API Gateway upstream names, node selectors) 
- ✅ Repository cleaned up with proper .gitignore
- ✅ **65 kustomization files created** for all 14 BASE modules with complete GitOps structure
- ✅ **BASE modules registered** in ArgoCD via existing ApplicationSets
- 🔄 **ArgoCD sync issues**: Temporary connectivity problems preventing full deployment
- 📋 **Next Phase**: Resolve ArgoCD sync connectivity and deploy all 14 data processing modules

### Next Steps Prioritized  
1. **ApplicationSet Deployment Status** (COMPLETED):
   - ✅ Wave 1 ApplicationSet: Platform UI + Istio Service Mesh (matches actual deployment)
   - ✅ Wave 2 ApplicationSet: Airflow, MLflow, Kubeflow, Superset, Seldon (matches actual deployment)
   - ✅ Wave 3 ApplicationSet: Removed (services were never actually deployed)
   - ✅ GitOps automation now accurately reflects platform state

2. **Platform Services Monitoring** (Current State):
   - Wave 2 orchestration services operational (95% complete)
   - Platform UI with real-time health monitoring active
   - Professional enterprise dashboard with API status tracking

3. **Stage 3 - BASE Module Implementation** (Enable Wave 4-7 deployment):
   - Create 52 missing kustomization files following data_ingestion pattern
   - Implement agent, model, orchestrator, workflow, and config subdirectories

4. **Stage 4 - Production Readiness**:
   - End-to-end deployment testing
   - Performance validation (200GB/hour throughput)
   - Security and compliance verification

### Current File Structure Status
```
✅ Fixed Structure:
├── platform-services-v2/automation/gitops/
│   ├── applicationsets/ (3 path fixes applied)
│   └── projects/ (4 missing projects created)
├── [all-14-modules]/kustomization.yaml (created)
└── platform-services-v2/application-services/platform-ui/ (consolidated)

⚠️ Needs Implementation:
├── platform-services-v2/shared-services/
│   ├── monitoring/ (manifests needed)
│   ├── logging/ (manifests needed)
│   └── istio/ (manifests needed)
├── platform-services-v2/orchestration-services/ (configs incomplete)
└── [all-14-modules]/[5-subdirs]/kustomization.yaml (52 files needed)
```

### Deployment Readiness Timeline
- **Week 1**: Shared services implementation → Wave 1 deployment ready
- **Week 2**: Orchestration completion → Wave 2 deployment ready  
- **Week 3**: BASE modules implementation → Waves 4-7 deployment ready
- **Week 4**: Production validation and performance testing