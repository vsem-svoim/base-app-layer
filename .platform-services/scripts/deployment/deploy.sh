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
