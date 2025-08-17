#!/bin/bash
# ===================================================================
# Automated Platform Setup Script
# Automates all manual deployment steps for BASE App Layer platform
# ===================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="../terraform-new/providers/aws/environments/dev"
ARGOCD_DIR="../argocd"
PLATFORM_UI_DIR="../platform-ui"
AWS_PROFILE="${AWS_PROFILE:-akovalenko-084129280818-AdministratorAccess}"
REGION="${REGION:-us-east-1}"
USER_IP="${USER_IP:-72.79.77.223/32}"

echo "🚀 Starting automated BASE platform deployment..."
echo "📍 Region: $REGION"
echo "🔐 Profile: $AWS_PROFILE" 
echo "🌐 Restricted IP: $USER_IP"

# ===================================================================
# Step 1: Deploy Infrastructure via Terraform
# ===================================================================
deploy_infrastructure() {
    echo "🏗️  Step 1: Deploying infrastructure..."
    cd "$SCRIPT_DIR/$TERRAFORM_DIR"
    
    # Initialize Terraform
    terraform init
    
    # Handle any state locks
    if ! terraform plan -lock=false >/dev/null 2>&1; then
        echo "⚠️  Terraform state may be locked, checking..."
        # Force unlock if needed (you may need to adjust the lock ID)
        # terraform force-unlock [LOCK_ID] -auto-approve || true
    fi
    
    # Apply infrastructure
    terraform apply -auto-approve
    
    echo "✅ Infrastructure deployed"
}

# ===================================================================
# Step 2: Setup ArgoCD and Applications
# ===================================================================
setup_argocd() {
    echo "⚙️  Step 2: Setting up ArgoCD..."
    cd "$SCRIPT_DIR"
    
    # Wait for ArgoCD to be ready
    echo "⏳ Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
    
    # Create GitHub repository secret
    kubectl create secret generic github-repo -n argocd \
        --from-literal=type=git \
        --from-literal=url=https://github.com/vsem-svoim/base-app-layer.git \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy ApplicationSets
    kubectl apply -f "$ARGOCD_DIR/applicationsets/base-layer-apps.yaml"
    kubectl apply -f "$ARGOCD_DIR/applicationsets/orchestration-apps.yaml"
    kubectl apply -f "$ARGOCD_DIR/applicationsets/aws-load-balancer-controller.yaml"
    
    echo "✅ ArgoCD configured"
}

# ===================================================================
# Step 3: Fix AWS Load Balancer Controller IAM
# ===================================================================
setup_load_balancer_controller() {
    echo "🔧 Step 3: Setting up AWS Load Balancer Controller..."
    
    # Get OIDC issuer for the platform cluster
    OIDC_ISSUER=$(aws eks describe-cluster --name base-app-layer-dev-platform --region $REGION --query 'cluster.identity.oidc.issuer' --output text)
    OIDC_ID=$(echo $OIDC_ISSUER | sed 's|https://oidc.eks.'$REGION'.amazonaws.com/id/||')
    
    echo "📋 OIDC Provider: $OIDC_ID"
    
    # Create IRSA role for AWS Load Balancer Controller
    cat > /tmp/alb-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/oidc.eks.$REGION.amazonaws.com/id/$OIDC_ID"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.$REGION.amazonaws.com/id/$OIDC_ID:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
          "oidc.eks.$REGION.amazonaws.com/id/$OIDC_ID:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF
    
    # Create or update IAM role
    aws iam create-role \
        --role-name base-dev-platform-alb-controller-role \
        --assume-role-policy-document file:///tmp/alb-trust-policy.json \
        --region $REGION || \
    aws iam update-assume-role-policy \
        --role-name base-dev-platform-alb-controller-role \
        --policy-document file:///tmp/alb-trust-policy.json
    
    # Attach Load Balancer Controller policy
    aws iam attach-role-policy \
        --role-name base-dev-platform-alb-controller-role \
        --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy
    
    # Annotate service account
    kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
        eks.amazonaws.com/role-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/base-dev-platform-alb-controller-role \
        --overwrite
    
    # Restart controller
    kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
    kubectl rollout status deployment aws-load-balancer-controller -n kube-system
    
    echo "✅ Load Balancer Controller configured"
    
    # Clean up temp file
    rm -f /tmp/alb-trust-policy.json
}

# ===================================================================
# Step 4: Deploy Platform UI with IP Restriction
# ===================================================================
setup_platform_ui() {
    echo "🎨 Step 4: Setting up Platform UI..."
    
    # Update platform UI with IP restriction
    sed -i.bak "s|alb.ingress.kubernetes.io/inbound-cidrs:.*|alb.ingress.kubernetes.io/inbound-cidrs: \"$USER_IP\"|" \
        "$PLATFORM_UI_DIR/dashboard.yaml"
    
    # Apply platform UI
    kubectl apply -f "$PLATFORM_UI_DIR/dashboard.yaml"
    
    # Wait for platform UI pods to be ready
    kubectl wait --for=condition=ready pod -l app=platform-ui-dashboard -n platform-ui --timeout=300s
    
    echo "✅ Platform UI deployed"
}

# ===================================================================
# Step 5: Clean up orphaned resources
# ===================================================================
cleanup_orphaned_resources() {
    echo "🧹 Step 5: Cleaning up orphaned resources..."
    
    # Remove classic load balancers (if any exist)
    CLASSIC_LBS=$(aws elb describe-load-balancers --region $REGION --query 'LoadBalancerDescriptions[?starts_with(LoadBalancerName, `a`) && length(LoadBalancerName) == `32`].LoadBalancerName' --output text)
    
    for lb in $CLASSIC_LBS; do
        echo "🗑️  Removing classic load balancer: $lb"
        aws elb delete-load-balancer --load-balancer-name "$lb" --region $REGION || true
    done
    
    echo "✅ Cleanup completed"
}

# ===================================================================
# Step 6: Validate Deployment
# ===================================================================
validate_deployment() {
    echo "🔍 Step 6: Validating deployment..."
    
    # Check node groups
    echo "📊 Node Groups:"
    aws eks list-nodegroups --cluster-name base-app-layer-dev-platform --region $REGION
    
    # Check ArgoCD applications
    echo "📱 ArgoCD Applications:"
    kubectl get applications -n argocd -o custom-columns=NAME:metadata.name,SYNC:status.sync.status,HEALTH:status.health.status
    
    # Get Platform UI URL
    ALB_DNS=$(aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[?contains(LoadBalancerName, `base-platform-dashboard`)].DNSName' --output text)
    
    echo ""
    echo "🎉 DEPLOYMENT COMPLETED!"
    echo "====================================="
    echo "Platform Dashboard URL: http://$ALB_DNS"
    echo "Restricted to IP: $USER_IP"
    echo "====================================="
    echo ""
    echo "Available Services:"
    echo "- /argocd    → GitOps Management"
    echo "- /airflow   → Workflow Orchestration"  
    echo "- /grafana   → Monitoring Dashboards"
    echo "- /mlflow    → ML Lifecycle"
    echo "- /kubeflow  → ML Workflows"
    echo "- /vault     → Secrets Management"
    echo ""
}

# ===================================================================
# Main Execution
# ===================================================================
main() {
    echo "🔒 Using AWS Profile: $AWS_PROFILE"
    export AWS_PROFILE="$AWS_PROFILE"
    
    # Check prerequisites
    command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found"; exit 1; }
    command -v terraform >/dev/null 2>&1 || { echo "❌ terraform not found"; exit 1; }
    command -v aws >/dev/null 2>&1 || { echo "❌ aws cli not found"; exit 1; }
    
    # Execute deployment steps
    deploy_infrastructure
    setup_argocd
    setup_load_balancer_controller
    setup_platform_ui
    cleanup_orphaned_resources
    validate_deployment
}

# Allow running specific steps
case "${1:-all}" in
    "infrastructure") deploy_infrastructure ;;
    "argocd") setup_argocd ;;
    "loadbalancer") setup_load_balancer_controller ;;
    "platform-ui") setup_platform_ui ;;
    "cleanup") cleanup_orphaned_resources ;;
    "validate") validate_deployment ;;
    "all") main ;;
    *) echo "Usage: $0 [infrastructure|argocd|loadbalancer|platform-ui|cleanup|validate|all]" ;;
esac