#!/bin/bash
set -e

echo "BASE App Layer Infrastructure Validation"
echo "========================================"

TERRAFORM_DIR="platform-services-v2/bootstrap/terraform/providers/aws/environments/dev"
FAILED_CHECKS=0

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    if [ $2 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
        ((FAILED_CHECKS++))
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo
echo "Phase 1: AWS Infrastructure Validation"
echo "-----------------------------------"

# Check if Terraform directory exists
if [ -d "$TERRAFORM_DIR" ]; then
    print_status "Terraform configuration directory exists" 0
else
    print_status "Terraform configuration directory missing" 1
fi

# Check AWS CLI configuration
if aws sts get-caller-identity &>/dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    REGION=$(aws configure get region)
    print_status "AWS CLI configured - Account: $ACCOUNT_ID, Region: ${REGION:-us-east-1}" 0
else
    print_status "AWS CLI not configured or no credentials" 1
fi

# Check Terraform state bucket
STATE_BUCKET="base-app-layer-terraform-state-us-east-1"
if aws s3 ls "s3://$STATE_BUCKET" &>/dev/null; then
    print_status "Terraform state bucket exists: $STATE_BUCKET" 0
else
    print_warning "Terraform state bucket does not exist: $STATE_BUCKET"
    echo "  Run: aws s3 mb s3://$STATE_BUCKET --region us-east-1"
fi

cd "$TERRAFORM_DIR" 2>/dev/null || exit 1

# Check if Terraform is initialized
if [ -d ".terraform" ]; then
    print_status "Terraform initialized" 0
else
    print_warning "Terraform not initialized"
    echo "  Run: terraform init"
fi

# Check Terraform plan (if initialized)
if [ -d ".terraform" ]; then
    echo
    echo "Running terraform plan to check infrastructure state..."
    if terraform plan -detailed-exitcode &>/dev/null; then
        case $? in
            0) print_status "Infrastructure is up to date" 0 ;;
            1) print_status "Terraform plan failed" 1 ;;
            2) print_warning "Infrastructure changes detected - run terraform apply" ;;
        esac
    else
        print_status "Unable to run terraform plan" 1
    fi
fi

cd - >/dev/null

echo
echo "Phase 2: EKS Cluster Validation"
echo "------------------------------"

# Check if EKS clusters exist
PLATFORM_CLUSTER="base-app-layer-dev-platform"
BASE_CLUSTER="base-app-layer-dev-base"

if aws eks describe-cluster --name "$PLATFORM_CLUSTER" &>/dev/null; then
    CLUSTER_STATUS=$(aws eks describe-cluster --name "$PLATFORM_CLUSTER" --query 'cluster.status' --output text)
    if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
        print_status "Platform cluster ($PLATFORM_CLUSTER) is active" 0
    else
        print_status "Platform cluster status: $CLUSTER_STATUS" 1
    fi
else
    print_status "Platform cluster ($PLATFORM_CLUSTER) does not exist" 1
fi

if aws eks describe-cluster --name "$BASE_CLUSTER" &>/dev/null; then
    CLUSTER_STATUS=$(aws eks describe-cluster --name "$BASE_CLUSTER" --query 'cluster.status' --output text)
    if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
        print_status "Base cluster ($BASE_CLUSTER) is active" 0
    else
        print_status "Base cluster status: $CLUSTER_STATUS" 1
    fi
else
    print_status "Base cluster ($BASE_CLUSTER) does not exist" 1
fi

echo
echo "Phase 3: Node Groups Validation"
echo "------------------------------"

NODE_GROUPS=("platform_system" "platform_general" "platform_compute" "platform_memory" "platform_gpu")

for ng in "${NODE_GROUPS[@]}"; do
    if aws eks describe-nodegroup --cluster-name "$PLATFORM_CLUSTER" --nodegroup-name "$ng" &>/dev/null; then
        NG_STATUS=$(aws eks describe-nodegroup --cluster-name "$PLATFORM_CLUSTER" --nodegroup-name "$ng" --query 'nodegroup.status' --output text)
        if [ "$NG_STATUS" = "ACTIVE" ]; then
            print_status "Node group $ng is active" 0
        else
            print_status "Node group $ng status: $NG_STATUS" 1
        fi
    else
        if [ "$ng" = "platform_gpu" ]; then
            print_warning "Node group $ng does not exist (optional for GPU workloads)"
        else
            print_status "Node group $ng does not exist" 1
        fi
    fi
done

echo
echo "Phase 4: Storage and IAM Validation"
echo "-----------------------------------"

# Check if kubectl is configured
if kubectl cluster-info &>/dev/null; then
    print_status "kubectl configured and connected" 0
    
    # Check storage classes
    if kubectl get storageclass gp3 &>/dev/null; then
        print_status "Storage class 'gp3' exists" 0
    else
        print_status "Storage class 'gp3' missing" 1
    fi
    
    if kubectl get storageclass gp3-immediate &>/dev/null; then
        print_status "Storage class 'gp3-immediate' exists" 0
    else
        print_status "Storage class 'gp3-immediate' missing" 1
    fi
else
    print_warning "kubectl not configured - run: aws eks update-kubeconfig --name $PLATFORM_CLUSTER"
fi

# Check IRSA roles
IRSA_ROLES=(
    "base-app-layer-dev-platform-argocd-irsa"
    "base-app-layer-dev-platform-airflow-irsa"
    "base-app-layer-dev-platform-prometheus-irsa"
    "base-app-layer-dev-platform-aws_load_balancer_controller-irsa"
)

for role in "${IRSA_ROLES[@]}"; do
    if aws iam get-role --role-name "$role" &>/dev/null; then
        print_status "IRSA role $role exists" 0
    else
        print_warning "IRSA role $role does not exist"
    fi
done

echo
echo "Phase 5: Certificate and Load Balancer"
echo "-------------------------------------"

# Note: We cannot validate the hardcoded certificate ARN without knowing the actual certificate
print_warning "Certificate ARN is hardcoded in manifests - manual verification needed"
print_warning "Verify: arn:aws:acm:us-east-1:084129280818:certificate/base-platform-cert"

echo
echo "Validation Summary"
echo "=================="
if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${GREEN}All critical infrastructure checks passed!${NC}"
    echo "Platform is ready for deployment."
else
    echo -e "${RED}$FAILED_CHECKS critical issues found.${NC}"
    echo "Please resolve the above issues before proceeding with deployment."
fi

exit $FAILED_CHECKS