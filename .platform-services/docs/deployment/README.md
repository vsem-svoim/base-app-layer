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
