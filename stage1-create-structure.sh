#!/bin/bash

# FinPortIQ Platform - Stage 1: Create Universal Infrastructure Structure
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INITIAL_DIR="$(pwd)"

# Default Configuration
PROJECT_ROOT="platform-services"
GITHUB_ORG="vsem-svoim"
CLUSTER_NAME="base-finportiq"
ENVIRONMENT="dev"
BASE_LAYER_REPO_URL=""
BASE_LAYER_COMPONENTS=""
LOCAL_PATH="./base-layer"
BRANCH="main"
CREATED_AT=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

show_help() {
    cat << EOF
FinPortIQ Platform - Stage 1: Create Universal Infrastructure Structure

Usage: $0 [OPTIONS]

Options:
  -n, --name NAME           Project name [default: platform-services]
  -o, --org ORG            GitHub organization [default: vsem-svoim]
  -c, --cluster CLUSTER    Cluster name [default: base-finportiq]
  -e, --env ENVIRONMENT    Environment [default: dev]
  -r, --repo URL           BASE layer repository URL
  -h, --help              Show this help

Examples:
  $0 --name myproject --org myorg --repo https://github.com/org/base-layer.git
  $0 -n platform-services -o vsem-svoim -r https://github.com/vsem-svoim/base-layer.git
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name) PROJECT_ROOT="$2"; shift 2 ;;
            -o|--org) GITHUB_ORG="$2"; shift 2 ;;
            -c|--cluster) CLUSTER_NAME="$2"; shift 2 ;;
            -e|--env) ENVIRONMENT="$2"; shift 2 ;;
            -r|--repo) BASE_LAYER_REPO_URL="$2"; shift 2 ;;
            -h|--help) show_help; exit 0 ;;
            *) log_error "Unknown parameter: $1"; show_help; exit 1 ;;
        esac
    done
}

collect_user_input() {
    log "Collecting BASE layer information..."

    if [[ -z "$BASE_LAYER_REPO_URL" ]]; then
        echo -n "Enter BASE layer repository URL (e.g., https://github.com/org/base-layer.git): "
        read -r BASE_LAYER_REPO_URL

        if [[ -z "$BASE_LAYER_REPO_URL" ]]; then
            log_error "BASE layer repository URL is required"
            exit 1
        fi
    fi

    # Standard BASE layer components
    BASE_LAYER_COMPONENTS="data_ingestion,data_control,data_distribution,data_quality,data_security,data_storage,data_streaming,event_coordination,feature_engineering,metadata_discovery,multimodal_processing,pipeline_management,quality_monitoring,schema_contracts"
    LOCAL_PATH="./base-layer"
    BRANCH="main"
    CREATED_AT="$(date '+%Y-%m-%d %H:%M:%S')"

    log_info "BASE layer: $BASE_LAYER_REPO_URL"
    log_info "GitHub organization: $GITHUB_ORG"
    log_info "Components: 14 BASE layer components"
}

check_dependencies() {
    log "Checking dependencies..."
    local deps=("git")

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            log_error "$dep is not installed"
            exit 1
        fi
        log "$dep found"
    done
}

create_project_structure() {
    log "Creating project structure..."

    PROJECT_ROOT_ABS="${INITIAL_DIR}/${PROJECT_ROOT}"
    mkdir -p "$PROJECT_ROOT_ABS"
    cd "$PROJECT_ROOT_ABS"

    # Core directory structure
    local directories=(
        # GitHub Actions
        ".github/workflows"

        # ArgoCD GitOps
        "argocd/bootstrap"
        "argocd/applications/base-layer"
        "argocd/applications/platform-services"
        "argocd/applications/ml-platform"
        "argocd/environments/dev"
        "argocd/environments/staging"
        "argocd/environments/prod"
        "argocd/rollouts"

        # Terraform - Provider Agnostic Modules
        "terraform/modules/kubernetes"
        "terraform/modules/database"
        "terraform/modules/messaging"
        "terraform/modules/storage"
        "terraform/modules/iam"
        "terraform/modules/network"
        "terraform/modules/loadbalancer"
        "terraform/modules/monitoring"

        # Terraform - Multi-Provider Support
        "terraform/providers/aws"
        "terraform/providers/gcp"
        "terraform/providers/azure"
        "terraform/providers/onprem"

        # Terraform - Environments
        "terraform/environments/global"
        "terraform/environments/dev"
        "terraform/environments/staging"
        "terraform/environments/prod"
        "terraform/bootstrap"

        # Crossplane - Infrastructure as Code
        "crossplane/compositions/compute"
        "crossplane/compositions/database"
        "crossplane/compositions/storage"
        "crossplane/compositions/network"
        "crossplane/claims/dev"
        "crossplane/claims/staging"
        "crossplane/claims/prod"
        "crossplane/functions"
        "crossplane/apis"

        # Airflow Data Pipelines
        "airflow/dags/deployment"
        "airflow/dags/data_pipelines/ingestion_workflows"
        "airflow/dags/data_pipelines/processing_workflows"
        "airflow/dags/ml_pipelines"
        "airflow/plugins/operators"
        "airflow/plugins/sensors"
        "airflow/plugins/hooks"
        "airflow/config"

        # Helm Charts - Platform Services
        "helm-charts/platform-services/airflow/templates"
        "helm-charts/platform-services/airflow/values"
        "helm-charts/platform-services/postgresql/templates"
        "helm-charts/platform-services/postgresql/values"
        "helm-charts/platform-services/kafka/templates"
        "helm-charts/platform-services/kafka/values"
        "helm-charts/platform-services/monitoring/templates"
        "helm-charts/platform-services/monitoring/values"
        "helm-charts/platform-services/logging/templates"
        "helm-charts/platform-services/logging/values"
        "helm-charts/platform-services/security/templates"
        "helm-charts/platform-services/security/values"

        # ML Platform
        "ml-platform/models/connection-optimization/training"
        "ml-platform/models/connection-optimization/serving"
        "ml-platform/models/connection-optimization/monitoring"
        "ml-platform/mlflow/experiments"
        "ml-platform/mlflow/registry"
        "ml-platform/mlflow/values"
        "ml-platform/kubeflow/pipelines"
        "ml-platform/kubeflow/katib"
        "ml-platform/kubeflow/values"
        "ml-platform/seldon/deployments"
        "ml-platform/seldon/experiments"
        "ml-platform/seldon/values"

        # Monitoring Stack
        "monitoring/prometheus/rules"
        "monitoring/prometheus/scrapers"
        "monitoring/grafana/dashboards"
        "monitoring/grafana/datasources"
        "monitoring/jaeger"
        "monitoring/elk/elasticsearch"
        "monitoring/elk/logstash"
        "monitoring/elk/kibana"
        "monitoring/alertmanager"

        # Scripts
        "scripts/deployment"
        "scripts/testing"
        "scripts/ml-ops"
        "scripts/utilities"
        "scripts/backup"

        # Testing
        "tests/unit/agents"
        "tests/unit/models"
        "tests/unit/orchestrators"
        "tests/integration/workflows"
        "tests/integration/end-to-end"
        "tests/performance/load-tests"
        "tests/performance/stress-tests"
        "tests/security/penetration"
        "tests/compliance/sox"
        "tests/compliance/gdpr"
        "tests/compliance/pci-dss"

        # Documentation
        "docs/architecture/decision-records"
        "docs/operations/runbooks"
        "docs/operations/sop"
        "docs/operations/troubleshooting"
        "docs/operations/disaster-recovery"
        "docs/api/openapi"
        "docs/development"
        "docs/deployment"

        # Policy as Code
        "policies/opa/admission"
        "policies/opa/authorization"
        "policies/opa/compliance"
        "policies/kyverno/security"
        "policies/kyverno/best-practices"
        "policies/sentinel/cost-control"

        # Configuration Management
        "config/environments/dev"
        "config/environments/staging"
        "config/environments/prod"
        "config/secrets"
        "config/configmaps"
    )

    # Create Kustomize directories for BASE layer components
    local base_components=("data-ingestion" "data-control" "data-distribution" "data-quality" "data-security" "data-storage" "data-streaming" "event-coordination" "feature-engineering" "metadata-discovery" "multimodal-processing" "pipeline-management" "quality-monitoring" "schema-contracts")

    for component in "${base_components[@]}"; do
        directories+=(
            "kustomize/base-layer/${component}/base"
            "kustomize/base-layer/${component}/overlays/dev"
            "kustomize/base-layer/${component}/overlays/staging"
            "kustomize/base-layer/${component}/overlays/prod"
        )
    done

    # Create all directories
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
    done

    log "Created ${#directories[@]} directories"
}

create_argocd_configs() {
    log "Creating ArgoCD configurations..."

    # Root application (App-of-Apps pattern)
    cat > argocd/bootstrap/root-app.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: finportiq-platform
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/$GITHUB_ORG/FinPortIQ.git
    targetRevision: HEAD
    path: $PROJECT_ROOT/argocd/applications
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF

    # BASE layer applications
    local base_components=("data-ingestion" "data-control" "data-distribution" "data-quality" "data-security" "data-storage" "data-streaming" "event-coordination" "feature-engineering" "metadata-discovery" "multimodal-processing" "pipeline-management" "quality-monitoring" "schema-contracts")

    for component in "${base_components[@]}"; do
        cat > "argocd/applications/base-layer/${component}-app.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${component}-\${ENVIRONMENT}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $BASE_LAYER_REPO_URL
    path: ${component//-/_}
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: base-${component}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
    done

    # Platform services applications
    cat > argocd/applications/platform-services/monitoring-stack-app.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: monitoring-stack
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://prometheus-community.github.io/helm-charts
    chart: kube-prometheus-stack
    targetRevision: 55.0.0
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

    cat > argocd/applications/platform-services/airflow-app.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: airflow
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://airflow.apache.org
    chart: airflow
    targetRevision: 1.11.0
  destination:
    server: https://kubernetes.default.svc
    namespace: airflow
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
}

create_kustomize_configs() {
    log "Creating Kustomize configurations..."

    local base_components=("data-ingestion" "data-control" "data-distribution" "data-quality" "data-security" "data-storage" "data-streaming" "event-coordination" "feature-engineering" "metadata-discovery" "multimodal-processing" "pipeline-management" "quality-monitoring" "schema-contracts")

    for component in "${base_components[@]}"; do
        # Base kustomization
        cat > "kustomize/base-layer/${component}/base/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../../../../base-layer/${component//-/_}/agents/
  - ../../../../../base-layer/${component//-/_}/configs/
  - ../../../../../base-layer/${component//-/_}/models/
  - ../../../../../base-layer/${component//-/_}/orchestrators/
  - ../../../../../base-layer/${component//-/_}/workflows/

configMapGenerator:
  - name: ${component}-prompts
    files:
      - ../../../../../base-layer/${component//-/_}/prompts/

commonLabels:
  app.kubernetes.io/part-of: base-system
  base.io/category: ${component//-/_}

namespace: base-${component}
namePrefix: base-${component}-
EOF

        # Environment overlays
        for env in dev staging prod; do
            local replicas=1
            local log_level="debug"

            case $env in
                staging) replicas=2; log_level="info" ;;
                prod) replicas=3; log_level="warn" ;;
            esac

            cat > "kustomize/base-layer/${component}/overlays/${env}/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

patches:
  - target:
      kind: Deployment
    patch: |-
      - op: replace
        path: /spec/replicas
        value: ${replicas}

commonLabels:
  base.io/environment: ${env}

configMapGenerator:
  - name: ${component}-${env}-config
    literals:
      - ENVIRONMENT=${env}
      - LOG_LEVEL=${log_level}
EOF
        done
    done
}

create_terraform_structure() {
    log "Creating Terraform structure..."

    # Main terraform configuration
    cat > terraform/main.tf << 'EOF'
terraform {
  required_version = ">= 1.5"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}
EOF

    # Provider-agnostic Kubernetes module
    cat > terraform/modules/kubernetes/main.tf << 'EOF'
# Provider-agnostic Kubernetes cluster module
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "region" {
  description = "Cloud region"
  type        = string
}

variable "node_count" {
  description = "Number of nodes"
  type        = number
  default     = 3
}

variable "node_instance_type" {
  description = "Instance type for nodes"
  type        = string
  default     = "medium"
}

variable "provider_type" {
  description = "Cloud provider type (aws, gcp, azure, onprem)"
  type        = string
}

# This will be implemented by provider-specific modules
output "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = ""
}

output "cluster_certificate" {
  description = "Kubernetes cluster certificate"
  value       = ""
}
EOF

    # Database module
    cat > terraform/modules/database/main.tf << 'EOF'
# Provider-agnostic database module
variable "database_name" {
  description = "Name of the database"
  type        = string
}

variable "instance_class" {
  description = "Database instance class"
  type        = string
  default     = "medium"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 100
}

variable "provider_type" {
  description = "Cloud provider type"
  type        = string
}
EOF
}

create_crossplane_configs() {
    log "Creating Crossplane configurations..."

    # Compute composition
    cat > crossplane/compositions/compute/xcluster.yaml << 'EOF'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: xcluster
spec:
  compositeTypeRef:
    apiVersion: platform.finportiq.io/v1alpha1
    kind: XCluster
  resources:
  - name: cluster
    base:
      apiVersion: kubernetes.crossplane.io/v1alpha1
      kind: Cluster
      spec:
        forProvider:
          region: us-east-1
    patches:
    - type: FromCompositeFieldPath
      fromFieldPath: spec.parameters.region
      toFieldPath: spec.forProvider.region
    - type: FromCompositeFieldPath
      fromFieldPath: spec.parameters.nodeCount
      toFieldPath: spec.forProvider.nodeCount
EOF

    # Database composition
    cat > crossplane/compositions/database/xdatabase.yaml << 'EOF'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: xdatabase
spec:
  compositeTypeRef:
    apiVersion: platform.finportiq.io/v1alpha1
    kind: XDatabase
  resources:
  - name: database
    base:
      apiVersion: rds.aws.crossplane.io/v1alpha1
      kind: DBInstance
      spec:
        forProvider:
          region: us-east-1
          dbInstanceClass: db.t3.micro
    patches:
    - type: FromCompositeFieldPath
      fromFieldPath: spec.parameters.size
      toFieldPath: spec.forProvider.dbInstanceClass
EOF

    # Development environment claim
    cat > crossplane/claims/dev/cluster-claim.yaml << 'EOF'
apiVersion: platform.finportiq.io/v1alpha1
kind: XCluster
metadata:
  name: dev-cluster
  namespace: crossplane-system
spec:
  parameters:
    region: us-east-1
    nodeCount: 3
    nodeSize: medium
  compositionRef:
    name: xcluster
  writeConnectionSecretsToNamespace: crossplane-system
EOF
}

create_helm_charts() {
    log "Creating Helm chart templates..."

    # Airflow chart
    cat > helm-charts/platform-services/airflow/Chart.yaml << 'EOF'
apiVersion: v2
name: finportiq-airflow
description: FinPortIQ Airflow deployment
type: application
version: 0.1.0
appVersion: "2.7.0"

dependencies:
- name: airflow
  version: 1.11.0
  repository: https://airflow.apache.org
EOF

    cat > helm-charts/platform-services/airflow/values/values-dev.yaml << 'EOF'
airflow:
  executor: KubernetesExecutor
  webserver:
    replicas: 1
  scheduler:
    replicas: 1
  workers:
    replicas: 0
  postgresql:
    enabled: true
  redis:
    enabled: false
EOF

    # Monitoring chart
    cat > helm-charts/platform-services/monitoring/Chart.yaml << 'EOF'
apiVersion: v2
name: finportiq-monitoring
description: FinPortIQ monitoring stack
type: application
version: 0.1.0

dependencies:
- name: kube-prometheus-stack
  version: 55.0.0
  repository: https://prometheus-community.github.io/helm-charts
EOF
}

create_airflow_dags() {
    log "Creating Airflow DAGs..."

    # Base ingestion DAG
    cat > airflow/dags/data_pipelines/ingestion_workflows/base_ingestion.py << 'EOF'
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator

default_args = {
    'owner': 'finportiq',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5)
}

def extract_data(**context):
    """Extract data from BASE layer components"""
    print("Extracting data from BASE layer...")
    return "extraction_complete"

def transform_data(**context):
    """Transform data using BASE layer processing"""
    print("Transforming data...")
    return "transformation_complete"

def load_data(**context):
    """Load data to destination"""
    print("Loading data...")
    return "load_complete"

with DAG(
    'base_data_ingestion',
    default_args=default_args,
    description='BASE layer data ingestion pipeline',
    schedule_interval=timedelta(hours=1),
    catchup=False,
    tags=['base-layer', 'ingestion']
) as dag:

    extract_task = PythonOperator(
        task_id='extract_data',
        python_callable=extract_data
    )

    transform_task = PythonOperator(
        task_id='transform_data',
        python_callable=transform_data
    )

    load_task = PythonOperator(
        task_id='load_data',
        python_callable=load_data
    )

    extract_task >> transform_task >> load_task
EOF

    # Airflow configuration
    cat > airflow/config/airflow.cfg << 'EOF'
[core]
dags_folder = /opt/airflow/dags
base_log_folder = /opt/airflow/logs
logging_level = INFO
executor = KubernetesExecutor
sql_alchemy_conn = postgresql+psycopg2://airflow:airflow@postgres:5432/airflow

[kubernetes]
namespace = airflow
worker_container_repository = apache/airflow
worker_container_tag = 2.7.0
EOF
}

create_github_actions() {
    log "Creating GitHub Actions workflows..."

    # CI/CD for BASE components
    cat > .github/workflows/ci-platform.yaml << 'EOF'
name: Platform CI/CD

on:
  push:
    branches: [main, develop]
    paths:
      - 'platform-services/**'
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  validate-structure:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Validate Kustomize
      run: |
        for component in platform-services/kustomize/base-layer/*/; do
          if [ -d "$component" ]; then
            echo "Validating $component"
            kubectl kustomize "$component/overlays/dev" --dry-run
          fi
        done

    - name: Validate ArgoCD Applications
      run: |
        for app in platform-services/argocd/applications/*/*.yaml; do
          if [ -f "$app" ]; then
            echo "Validating $app"
            kubectl apply --dry-run=client -f "$app"
          fi
        done

    - name: Validate Helm Charts
      run: |
        for chart in platform-services/helm-charts/*/; do
          if [ -f "$chart/Chart.yaml" ]; then
            echo "Validating $chart"
            helm lint "$chart"
          fi
        done

  terraform-plan:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
    steps:
    - uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: 1.6.0

    - name: Terraform Init
      working-directory: platform-services/terraform/environments/${{ matrix.environment }}
      run: terraform init

    - name: Terraform Plan
      working-directory: platform-services/terraform/environments/${{ matrix.environment }}
      run: terraform plan
EOF
}

create_monitoring_configs() {
    log "Creating monitoring configurations..."

    # Prometheus rules
    cat > monitoring/prometheus/rules/base-alerts.yaml << 'EOF'
groups:
- name: base-layer-alerts
  rules:
  - alert: HighCPUUsage
    expr: cpu_usage_percent > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage detected"
      description: "CPU usage is above 80% for more than 5 minutes"

  - alert: HighMemoryUsage
    expr: memory_usage_percent > 85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage detected"
      description: "Memory usage is above 85% for more than 5 minutes"

  - alert: BaseComponentDown
    expr: up{job=~"base-.*"} == 0
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "BASE component is down"
      description: "BASE component {{ $labels.job }} has been down for more than 2 minutes"
EOF

    # Grafana dashboard
    cat > monitoring/grafana/dashboards/base-layer-overview.json << 'EOF'
{
  "dashboard": {
    "title": "BASE Layer Overview",
    "panels": [
      {
        "title": "Component Health",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=~\"base-.*\"}"
          }
        ]
      },
      {
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "cpu_usage_percent{job=~\"base-.*\"}"
          }
        ]
      }
    ]
  }
}
EOF
}

create_scripts() {
    log "Creating utility scripts..."

    # Deployment script
    cat > scripts/deployment/deploy.sh << 'EOF'
#!/bin/bash

set -euo pipefail

ENVIRONMENT=${1:-dev}
PROVIDER=${2:-aws}
REGION=${3:-us-east-1}

echo "Deploying FinPortIQ Platform"
echo "Environment: $ENVIRONMENT"
echo "Provider: $PROVIDER"
echo "Region: $REGION"

# Deploy infrastructure
echo "Deploying infrastructure..."
cd terraform/environments/$ENVIRONMENT
terraform init
terraform plan
terraform apply -auto-approve

# Deploy BASE layer components
echo "Deploying BASE layer..."
kubectl apply -k ../../kustomize/base-layer/data-ingestion/overlays/$ENVIRONMENT
kubectl apply -k ../../kustomize/base-layer/data-storage/overlays/$ENVIRONMENT

echo "Deployment completed!"
EOF

    chmod +x scripts/deployment/deploy.sh

    # Testing script
    cat > scripts/testing/run-tests.sh << 'EOF'
#!/bin/bash

set -euo pipefail

echo "Running platform tests..."

# Unit tests
echo "Running unit tests..."
python -m pytest tests/unit/ -v

# Integration tests
echo "Running integration tests..."
python -m pytest tests/integration/ -v

# Security tests
echo "Running security tests..."
python -m pytest tests/security/ -v

echo "All tests completed!"
EOF

    chmod +x scripts/testing/run-tests.sh
}

create_documentation() {
    log "Creating documentation..."

    # Architecture decision record template
    cat > docs/architecture/decision-records/template.md << 'EOF'
# ADR-XXX: [Title]

## Status
[Proposed | Accepted | Deprecated | Superseded]

## Context
[Describe the context and problem statement]

## Decision
[Describe the decision made]

## Consequences
[Describe the consequences, both positive and negative]

## Alternatives Considered
[List alternatives that were considered]
EOF

    # Deployment guide
    cat > docs/deployment/README.md << 'EOF'
# FinPortIQ Platform Deployment Guide

## Prerequisites

- Kubernetes cluster
- ArgoCD installed
- Terraform >= 1.5
- Helm >= 3.0

## Quick Start

1. **Deploy Infrastructure**
   ```bash
   ./scripts/deployment/deploy.sh dev aws us-east-1
   ```

2. **Deploy BASE Layer**
   ```bash
   kubectl apply -f argocd/bootstrap/root-app.yaml
   ```

3. **Verify Deployment**
   ```bash
   kubectl get applications -n argocd
   ```

## Architecture

The platform consists of:
- 14 BASE layer components
- Platform services (Airflow, PostgreSQL, Kafka)
- ML platform (MLflow, Kubeflow)
- Monitoring stack (Prometheus, Grafana)
EOF
}

create_configuration_files() {
    log "Creating configuration files..."

    # Environment configurations
    for env in dev staging prod; do
        cat > "config/environments/${env}/config.yaml" << EOF
environment: ${env}
cluster:
  name: ${CLUSTER_NAME}-${env}
  region: us-east-1

base_layer:
  repository: ${BASE_LAYER_REPO_URL}
  branch: ${BRANCH}
  components:
    - data_ingestion
    - data_control
    - data_distribution
    - data_quality
    - data_security
    - data_storage
    - data_streaming
    - event_coordination
    - feature_engineering
    - metadata_discovery
    - multimodal_processing
    - pipeline_management
    - quality_monitoring
    - schema_contracts

platform_services:
  airflow:
    enabled: true
    replicas: 1
  postgresql:
    enabled: true
    storage: 100Gi
  kafka:
    enabled: true
    replicas: 3
EOF
    done

    # Save stage 1 output
    cat > .stage1-output << EOF
# Stage 1 Output - Platform Services Structure
BASE_LAYER_REPO_URL=${BASE_LAYER_REPO_URL}
GITHUB_ORG=${GITHUB_ORG}
PROJECT_ROOT=${PROJECT_ROOT}
CLUSTER_NAME=${CLUSTER_NAME}
ENVIRONMENT=${ENVIRONMENT}
BASE_LAYER_COMPONENTS=${BASE_LAYER_COMPONENTS}
BASE_LAYER_LOCAL_PATH=${LOCAL_PATH}
BASE_LAYER_BRANCH=${BRANCH}
PLATFORM_SERVICES_PATH=platform-services
CREATED_AT="${CREATED_AT}"
STAGE1_COMPLETED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
EOF
}

create_readme() {
    log "Creating README..."

    cat > README.md << EOF
# FinPortIQ Platform Services

Enterprise-grade financial data platform with BASE layer integration.

## Architecture

- **BASE Layer**: 14 foundational components with complete Kubernetes manifests
- **Platform Services**: Airflow, PostgreSQL, Kafka, Monitoring
- **ML Platform**: MLflow, Kubeflow, Seldon Core
- **Deployment**: Kustomize overlays + ArgoCD GitOps
- **Infrastructure**: Terraform + Crossplane multi-cloud

## Configuration

- **Cluster**: $CLUSTER_NAME
- **Environment**: $ENVIRONMENT
- **BASE Layer**: $BASE_LAYER_REPO_URL

## Quick Start

1. **Deploy Infrastructure**
   \`\`\`bash
   ./scripts/deployment/deploy.sh dev aws us-east-1
   \`\`\`

2. **Deploy Platform**
   \`\`\`bash
   kubectl apply -f argocd/bootstrap/root-app.yaml
   \`\`\`

## Directory Structure

\`\`\`
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
\`\`\`

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
EOF

    # Create Makefile
    cat > Makefile << 'EOF'
.PHONY: help init validate deploy clean test

help:
	@echo "FinPortIQ Platform Management"
	@echo ""
	@echo "Commands:"
	@echo "  init         - Initialize project structure"
	@echo "  validate     - Validate configurations"
	@echo "  deploy       - Deploy platform (ENV=dev PROVIDER=aws)"
	@echo "  clean        - Clean resources"
	@echo "  test         - Run tests"

init:
	@echo "Project structure initialized"

validate:
	@echo "Validating configurations..."
	./scripts/testing/run-tests.sh

deploy:
	@ENV ?= dev
	@PROVIDER ?= aws
	@REGION ?= us-east-1
	./scripts/deployment/deploy.sh $(ENV) $(PROVIDER) $(REGION)

clean:
	@ENV ?= dev
	@echo "Cleaning resources in $(ENV)..."
	cd terraform/environments/$(ENV) && terraform destroy -auto-approve

test:
	./scripts/testing/run-tests.sh
EOF
}

main() {
    log "========================================="
    log "FinPortIQ Platform - Stage 1"
    log "Universal Infrastructure Structure"
    log "========================================="

    parse_args "$@"
    collect_user_input

    log_info "Project: $PROJECT_ROOT"
    log_info "GitHub: $GITHUB_ORG"
    log_info "BASE layer: $BASE_LAYER_REPO_URL"

    check_dependencies

    if [[ -d "$PROJECT_ROOT" ]]; then
        log_warning "Directory $PROJECT_ROOT already exists"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Create all components
    create_project_structure
    create_argocd_configs
    create_kustomize_configs
    create_terraform_structure
    create_crossplane_configs
    create_helm_charts
    create_airflow_dags
    create_github_actions
    create_monitoring_configs
    create_scripts
    create_documentation
    create_configuration_files
    create_readme

    log "========================================="
    log "STAGE 1 COMPLETED SUCCESSFULLY"
    log "========================================="
    log ""
    log "PLATFORM INFORMATION:"
    log "====================="
    log_info "Platform Services: ${INITIAL_DIR}/${PROJECT_ROOT}/"
    log_info "BASE Layer: ${BASE_LAYER_REPO_URL}"
    log_info "Configuration saved to .stage1-output"
    log ""
    log "STRUCTURE CREATED:"
    log "=================="
    log "✅ ArgoCD GitOps applications (14 BASE + platform services)"
    log "✅ Kustomize overlays (dev/staging/prod environments)"
    log "✅ Terraform modules (provider-agnostic + multi-cloud)"
    log "✅ Crossplane compositions (infrastructure as code)"
    log "✅ Helm charts (platform services)"
    log "✅ Airflow DAGs (data pipelines)"
    log "✅ Monitoring stack (Prometheus/Grafana)"
    log "✅ CI/CD pipelines (GitHub Actions)"
    log "✅ Testing framework (unit/integration/security)"
    log "✅ Documentation (architecture/operations)"
    log "✅ Policy as code (OPA/Kyverno/Sentinel)"
    log ""
    log "NEXT STEPS:"
    log "==========="
    log "1. cd ${PROJECT_ROOT}"
    log "2. Configure your cloud provider"
    log "3. ./scripts/deployment/deploy.sh dev aws us-east-1"
    log "4. kubectl apply -f argocd/bootstrap/root-app.yaml"
    log ""
    log "Ready for provider-specific configuration and deployment!"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi