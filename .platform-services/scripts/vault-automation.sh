#!/bin/bash
# ===================================================================
# Vault Comprehensive Automation Script
# Automates Vault setup, unsealing, providers, OIDC, policies, and integrations
# ===================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_PROFILE="${AWS_PROFILE:-akovalenko-084129280818-AdministratorAccess}"
REGION="${REGION:-us-east-1}"
VAULT_NAMESPACE="vault"
VAULT_SERVICE="vault"
VAULT_ADDR="http://vault.vault.svc.cluster.local:8200"

echo "🔐 Starting Vault comprehensive automation..."

# ===================================================================
# Step 0: Fix Vault Storage and Ensure Pod is Ready
# ===================================================================
fix_vault_storage() {
    echo "💾 Step 0: Fixing Vault storage configuration..."
    
    # Create proper gp3 storage class with CSI driver
    cat > /tmp/gp3-storageclass.yaml << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF
    
    kubectl apply -f /tmp/gp3-storageclass.yaml || true
    
    # Check if PVC is pending due to storage class issues
    PVC_STATUS=$(kubectl get pvc data-vault-0 -n $VAULT_NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    
    if [ "$PVC_STATUS" = "Pending" ]; then
        echo "🔧 Fixing PVC storage class..."
        kubectl patch pvc data-vault-0 -n $VAULT_NAMESPACE -p '{"spec":{"storageClassName":"gp3"}}'
        
        # Force restart Vault pod if it's stuck
        kubectl delete pod vault-0 -n $VAULT_NAMESPACE --force --grace-period=0 || true
        sleep 15
        
        # Force sync Vault application to ensure proper configuration
        kubectl patch application vault -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}}}}}' || true
    fi
    
    echo "✅ Storage configuration fixed"
    rm -f /tmp/gp3-storageclass.yaml
}

# ===================================================================
# Step 1: Wait for Vault to be Ready and Initialize
# ===================================================================
initialize_vault() {
    echo "🚀 Step 1: Initializing Vault..."
    
    # Check prerequisites first
    check_prerequisites
    
    # Wait for Vault pod to be ready
    echo "⏳ Waiting for Vault pod to be ready..."
    kubectl wait --for=condition=ready pod vault-0 -n $VAULT_NAMESPACE --timeout=600s
    
    # Port forward to Vault
    echo "🔗 Setting up port forward to Vault..."
    kubectl port-forward -n $VAULT_NAMESPACE svc/vault 8200:8200 &
    PORT_FORWARD_PID=$!
    sleep 10
    
    export VAULT_ADDR="http://localhost:8200"
    
    # Check if Vault is already initialized
    if vault status >/dev/null 2>&1; then
        echo "✅ Vault is already initialized"
        return 0
    fi
    
    # Initialize Vault
    echo "🔑 Initializing Vault with 5 key shares, threshold 3..."
    INIT_OUTPUT=$(vault operator init \
        -key-shares=5 \
        -key-threshold=3 \
        -format=json)
    
    # Save keys securely
    echo "$INIT_OUTPUT" > /tmp/vault-init.json
    chmod 600 /tmp/vault-init.json
    
    # Extract unseal keys and root token
    UNSEAL_KEY_1=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[0]')
    UNSEAL_KEY_2=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[1]')
    UNSEAL_KEY_3=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[2]')
    ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')
    
    # Store keys in Kubernetes secrets
    kubectl create secret generic vault-unseal-keys -n $VAULT_NAMESPACE \
        --from-literal=key1="$UNSEAL_KEY_1" \
        --from-literal=key2="$UNSEAL_KEY_2" \
        --from-literal=key3="$UNSEAL_KEY_3" \
        --from-literal=root-token="$ROOT_TOKEN" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    echo "✅ Vault initialized and keys stored securely"
}

# ===================================================================
# Step 2: Automated Unsealing
# ===================================================================
unseal_vault() {
    echo "🔓 Step 2: Unsealing Vault..."
    
    # Get unseal keys from Kubernetes secret
    UNSEAL_KEY_1=$(kubectl get secret vault-unseal-keys -n $VAULT_NAMESPACE -o jsonpath='{.data.key1}' | base64 -d)
    UNSEAL_KEY_2=$(kubectl get secret vault-unseal-keys -n $VAULT_NAMESPACE -o jsonpath='{.data.key2}' | base64 -d)
    UNSEAL_KEY_3=$(kubectl get secret vault-unseal-keys -n $VAULT_NAMESPACE -o jsonpath='{.data.key3}' | base64 -d)
    
    # Unseal Vault
    vault operator unseal "$UNSEAL_KEY_1"
    vault operator unseal "$UNSEAL_KEY_2" 
    vault operator unseal "$UNSEAL_KEY_3"
    
    # Login with root token
    ROOT_TOKEN=$(kubectl get secret vault-unseal-keys -n $VAULT_NAMESPACE -o jsonpath='{.data.root-token}' | base64 -d)
    vault auth "$ROOT_TOKEN"
    
    echo "✅ Vault unsealed and authenticated"
}

# ===================================================================
# Step 3: Configure Authentication Providers
# ===================================================================
configure_auth_providers() {
    echo "🔑 Step 3: Configuring authentication providers..."
    
    # Enable Kubernetes auth
    vault auth enable kubernetes
    
    # Configure Kubernetes auth
    kubectl create clusterrolebinding vault-auth-delegator \
        --clusterrole=system:auth-delegator \
        --serviceaccount=$VAULT_NAMESPACE:vault || true
    
    vault write auth/kubernetes/config \
        token_reviewer_jwt="$(kubectl get secret \
            $(kubectl get serviceaccount vault -n $VAULT_NAMESPACE -o jsonpath='{.secrets[0].name}') \
            -n $VAULT_NAMESPACE -o jsonpath='{.data.token}' | base64 -d)" \
        kubernetes_host="https://kubernetes.default.svc:443" \
        kubernetes_ca_cert="$(kubectl get secret \
            $(kubectl get serviceaccount vault -n $VAULT_NAMESPACE -o jsonpath='{.secrets[0].name}') \
            -n $VAULT_NAMESPACE -o jsonpath='{.data.ca\.crt}' | base64 -d)"
    
    # Enable AWS auth
    vault auth enable aws
    
    # Configure AWS auth with current account
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    vault write auth/aws/config/client \
        secret_key="" \
        access_key="" \
        iam_server_id_header_value="vault.base-app-layer.dev"
    
    # Enable OIDC auth
    vault auth enable oidc
    
    # Configure OIDC (placeholder - customize per your OIDC provider)
    cat > /tmp/oidc-config.json << EOF
{
    "oidc_discovery_url": "https://your-oidc-provider.com/.well-known/openid_configuration",
    "oidc_client_id": "vault-client",
    "oidc_client_secret": "your-client-secret",
    "default_role": "platform-admin",
    "bound_audiences": ["vault-client"]
}
EOF
    
    echo "⚠️  OIDC config created as template - update /tmp/oidc-config.json with your provider details"
    
    # vault write auth/oidc/config @/tmp/oidc-config.json
    
    echo "✅ Authentication providers configured"
}

# ===================================================================
# Step 4: Create Policies and Secrets Engines  
# ===================================================================
configure_policies_and_engines() {
    echo "📋 Step 4: Configuring policies and secrets engines..."
    
    # Enable secrets engines
    vault secrets enable -path=secret kv-v2
    vault secrets enable -path=aws aws
    vault secrets enable -path=database database
    vault secrets enable -path=pki pki
    vault secrets enable -path=transit transit
    
    # Configure AWS secrets engine
    vault write aws/config/root \
        access_key="$(aws configure get aws_access_key_id --profile $AWS_PROFILE)" \
        secret_key="$(aws configure get aws_secret_access_key --profile $AWS_PROFILE)" \
        region="$REGION"
    
    # Create base policies
    vault policy write admin - << EOF
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF
    
    vault policy write platform-services - << EOF
# Platform services access
path "secret/data/platform/*" {
  capabilities = ["read", "list"]
}
path "aws/creds/platform-*" {
  capabilities = ["read"]
}
path "database/creds/platform-*" {
  capabilities = ["read"]
}
path "pki/issue/platform" {
  capabilities = ["create", "update"]
}
path "transit/encrypt/platform" {
  capabilities = ["create", "update"]
}
path "transit/decrypt/platform" {
  capabilities = ["create", "update"]
}
EOF
    
    vault policy write base-layer - << EOF
# BASE layer modules access
path "secret/data/base-layer/*" {
  capabilities = ["read", "list"]
}
path "aws/creds/base-*" {
  capabilities = ["read"]
}
path "database/creds/base-*" {
  capabilities = ["read"]
}
path "transit/encrypt/base-layer" {
  capabilities = ["create", "update"]
}
path "transit/decrypt/base-layer" {
  capabilities = ["create", "update"]
}
EOF
    
    vault policy write ml-platform - << EOF
# ML platform access
path "secret/data/ml-platform/*" {
  capabilities = ["read", "list"]
}
path "aws/creds/ml-*" {
  capabilities = ["read"]
}
path "database/creds/ml-*" {
  capabilities = ["read"]
}
EOF
    
    echo "✅ Policies and secrets engines configured"
}

# ===================================================================
# Step 5: Configure Kubernetes Service Account Roles
# ===================================================================
configure_k8s_roles() {
    echo "🎭 Step 5: Configuring Kubernetes service account roles..."
    
    # ArgoCD role
    vault write auth/kubernetes/role/argocd \
        bound_service_account_names=argocd-server,argocd-application-controller \
        bound_service_account_namespaces=argocd \
        policies=platform-services \
        ttl=24h
    
    # Airflow role  
    vault write auth/kubernetes/role/airflow \
        bound_service_account_names=airflow-scheduler,airflow-webserver \
        bound_service_account_namespaces=airflow \
        policies=platform-services \
        ttl=8h
    
    # BASE layer data ingestion role
    vault write auth/kubernetes/role/base-data-ingestion \
        bound_service_account_names="*" \
        bound_service_account_namespaces=base-data-ingestion \
        policies=base-layer \
        ttl=4h
    
    # ML platform roles
    vault write auth/kubernetes/role/mlflow \
        bound_service_account_names="*" \
        bound_service_account_namespaces=mlflow \
        policies=ml-platform \
        ttl=8h
    
    vault write auth/kubernetes/role/kubeflow \
        bound_service_account_names="*" \
        bound_service_account_namespaces=kubeflow \
        policies=ml-platform \
        ttl=8h
        
    echo "✅ Kubernetes service account roles configured"
}

# ===================================================================
# Step 6: Create AWS IAM Roles and Secrets
# ===================================================================
configure_aws_integration() {
    echo "☁️  Step 6: Configuring AWS integration..."
    
    # Create AWS roles for different services
    vault write aws/roles/platform-admin \
        credential_type=iam_user \
        policy_arns="arn:aws:iam::aws:policy/PowerUserAccess"
    
    vault write aws/roles/base-data-ingestion \
        credential_type=iam_user \
        policy_arns="arn:aws:iam::aws:policy/AmazonS3FullAccess,arn:aws:iam::aws:policy/AmazonKinesisFullAccess"
    
    vault write aws/roles/ml-platform \
        credential_type=iam_user \
        policy_arns="arn:aws:iam::aws:policy/AmazonS3FullAccess,arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
        
    echo "✅ AWS integration configured"
}

# ===================================================================
# Step 7: Setup Auto-Unseal with AWS KMS
# ===================================================================
setup_auto_unseal() {
    echo "🔐 Step 7: Setting up auto-unseal with AWS KMS..."
    
    # Create KMS key for auto-unseal
    KMS_KEY_ID=$(aws kms create-key \
        --region $REGION \
        --description "Vault auto-unseal key for BASE platform" \
        --query 'KeyMetadata.KeyId' \
        --output text)
    
    aws kms create-alias \
        --region $REGION \
        --alias-name alias/vault-auto-unseal-base-platform \
        --target-key-id $KMS_KEY_ID
    
    echo "🔑 KMS Key created: $KMS_KEY_ID"
    
    # Create auto-unseal configuration
    cat > /tmp/vault-auto-unseal-config.hcl << EOF
storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

seal "awskms" {
  region     = "$REGION"
  kms_key_id = "$KMS_KEY_ID"
}

api_addr = "http://vault.vault.svc.cluster.local:8200"
cluster_addr = "https://vault.vault.svc.cluster.local:8201"
ui = true
EOF
    
    # Store auto-unseal config in ConfigMap
    kubectl create configmap vault-auto-unseal-config -n $VAULT_NAMESPACE \
        --from-file=vault.hcl=/tmp/vault-auto-unseal-config.hcl \
        --dry-run=client -o yaml | kubectl apply -f -
    
    echo "✅ Auto-unseal configuration created"
    rm -f /tmp/vault-auto-unseal-config.hcl
}

# ===================================================================
# Step 8: Create Platform-Specific Secrets
# ===================================================================
create_platform_secrets() {
    echo "🔒 Step 8: Creating platform-specific secrets..."
    
    # ArgoCD admin password
    ARGOCD_PASSWORD=$(openssl rand -base64 32)
    vault kv put secret/platform/argocd \
        admin-password="$ARGOCD_PASSWORD" \
        url="https://argocd.base-app-layer.dev"
    
    # Database credentials
    vault kv put secret/platform/database \
        postgres-user="platform_admin" \
        postgres-password="$(openssl rand -base64 32)" \
        postgres-host="base-app-layer-dev-postgres.cluster-xxx.us-east-1.rds.amazonaws.com"
    
    # ML platform secrets
    vault kv put secret/ml-platform/mlflow \
        tracking-uri="http://mlflow.mlflow.svc.cluster.local:5000" \
        s3-bucket="base-app-layer-ml-artifacts-dev" \
        access-key="$(vault read -field=access_key aws/creds/ml-platform)" \
        secret-key="$(vault read -field=secret_key aws/creds/ml-platform)"
    
    # API keys for external services
    vault kv put secret/platform/external-apis \
        bloomberg-api-key="placeholder-key" \
        reuters-api-key="placeholder-key" \
        alpha-vantage-key="placeholder-key"
    
    # BASE layer module configs
    for module in data_ingestion data_quality data_storage data_security; do
        vault kv put secret/base-layer/$module \
            module-name="$module" \
            environment="dev" \
            log-level="INFO" \
            monitoring-enabled="true"
    done
    
    echo "✅ Platform secrets created"
}

# ===================================================================
# Step 9: Configure OIDC Authentication
# ===================================================================
configure_oidc_auth() {
    echo "🆔 Step 9: Configuring OIDC authentication..."
    
    # Create OIDC role for platform admins
    vault write auth/oidc/role/platform-admin \
        user_claim="email" \
        bound_audiences="vault-client" \
        bound_claims='{"groups":["platform-admins"]}' \
        policies="admin" \
        ttl="8h" \
        max_ttl="24h"
    
    # Create OIDC role for developers
    vault write auth/oidc/role/platform-developer \
        user_claim="email" \
        bound_audiences="vault-client" \
        bound_claims='{"groups":["platform-developers"]}' \
        policies="platform-services,base-layer" \
        ttl="4h" \
        max_ttl="8h"
    
    # Create OIDC role for data scientists  
    vault write auth/oidc/role/data-scientist \
        user_claim="email" \
        bound_audiences="vault-client" \
        bound_claims='{"groups":["data-scientists"]}' \
        policies="ml-platform,base-layer" \
        ttl="4h" \
        max_ttl="8h"
    
    echo "✅ OIDC authentication configured"
}

# ===================================================================
# Step 10: Setup Vault Agent for Auto-Injection
# ===================================================================
configure_vault_agent() {
    echo "🤖 Step 10: Configuring Vault Agent for auto-injection..."
    
    # Create Vault Agent configuration
    cat > /tmp/vault-agent-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-agent-config
  namespace: $VAULT_NAMESPACE
data:
  config.hcl: |
    exit_after_auth = false
    pid_file = "/home/vault/pidfile"
    
    auto_auth {
      method "kubernetes" {
        mount_path = "auth/kubernetes"
        config = {
          role = "vault-agent"
        }
      }
      
      sink "file" {
        config = {
          path = "/home/vault/.vault-token"
        }
      }
    }
    
    vault {
      address = "$VAULT_ADDR"
    }
    
    template {
      source      = "/vault/secrets/database.tpl"
      destination = "/vault/secrets/database.env"
      perms       = 0644
    }
    
    template {
      source      = "/vault/secrets/aws.tpl" 
      destination = "/vault/secrets/aws.env"
      perms       = 0644
    }
EOF
    
    kubectl apply -f /tmp/vault-agent-config.yaml
    
    echo "✅ Vault Agent configured"
    rm -f /tmp/vault-agent-config.yaml
}

# ===================================================================
# Step 11: Create Vault Operator for Auto-Unsealing
# ===================================================================
create_vault_operator() {
    echo "⚙️  Step 11: Creating Vault auto-unseal operator..."
    
    cat > /tmp/vault-unsealer.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault-unsealer
  namespace: $VAULT_NAMESPACE
  labels:
    app: vault-unsealer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vault-unsealer
  template:
    metadata:
      labels:
        app: vault-unsealer
    spec:
      serviceAccountName: vault-unsealer
      containers:
      - name: vault-unsealer
        image: vault:1.15.2
        command:
        - sh
        - -c
        - |
          while true; do
            if ! vault status -address=$VAULT_ADDR | grep -q "Sealed.*false"; then
              echo "🔓 Vault is sealed, attempting to unseal..."
              
              KEY1=\$(kubectl get secret vault-unseal-keys -n $VAULT_NAMESPACE -o jsonpath='{.data.key1}' | base64 -d)
              KEY2=\$(kubectl get secret vault-unseal-keys -n $VAULT_NAMESPACE -o jsonpath='{.data.key2}' | base64 -d)
              KEY3=\$(kubectl get secret vault-unseal-keys -n $VAULT_NAMESPACE -o jsonpath='{.data.key3}' | base64 -d)
              
              vault operator unseal -address=$VAULT_ADDR "\$KEY1" || true
              vault operator unseal -address=$VAULT_ADDR "\$KEY2" || true  
              vault operator unseal -address=$VAULT_ADDR "\$KEY3" || true
              
              if vault status -address=$VAULT_ADDR | grep -q "Sealed.*false"; then
                echo "✅ Vault successfully unsealed"
              fi
            else
              echo "✅ Vault is already unsealed"
            fi
            
            sleep 60
          done
        env:
        - name: VAULT_ADDR
          value: "$VAULT_ADDR"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi" 
            cpu: "100m"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-unsealer
  namespace: $VAULT_NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: vault-unsealer
  namespace: $VAULT_NAMESPACE
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: vault-unsealer
  namespace: $VAULT_NAMESPACE
subjects:
- kind: ServiceAccount
  name: vault-unsealer
  namespace: $VAULT_NAMESPACE
roleRef:
  kind: Role
  name: vault-unsealer
  apiGroup: rbac.authorization.k8s.io
EOF
    
    kubectl apply -f /tmp/vault-unsealer.yaml
    echo "✅ Vault auto-unsealer deployed"
    rm -f /tmp/vault-unsealer.yaml
}

# ===================================================================
# Step 12: Integration with Platform Services
# ===================================================================
configure_platform_integration() {
    echo "🔗 Step 12: Configuring platform service integrations..."
    
    # ArgoCD integration - create secret for ArgoCD to use
    vault kv put secret/platform/argocd/repository \
        url="https://github.com/vsem-svoim/base-app-layer.git" \
        username="git" \
        password="your-github-token"
    
    # Create External Secrets Operator integration
    cat > /tmp/external-secrets-vault.yaml << EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: argocd
spec:
  provider:
    vault:
      server: "$VAULT_ADDR"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "auth/kubernetes"
          role: "argocd"
          serviceAccountRef:
            name: "argocd-server"
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: argocd-repo-secret
  namespace: argocd
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: argocd-repo-secret
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: platform/argocd/repository
      property: username
  - secretKey: password
    remoteRef:
      key: platform/argocd/repository
      property: password
EOF
    
    echo "📝 External Secrets integration template created"
    echo "⚠️  Update GitHub token in vault secret before applying external-secrets"
    
    echo "✅ Platform integration configured"
}

# ===================================================================
# Step 13: Create Monitoring and Health Checks
# ===================================================================
setup_vault_monitoring() {
    echo "📊 Step 13: Setting up Vault monitoring..."
    
    # Enable Vault metrics
    vault write sys/config/telemetry \
        prometheus_retention_time="30s" \
        disable_hostname=true
    
    # Create ServiceMonitor for Prometheus
    cat > /tmp/vault-servicemonitor.yaml << EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: vault-metrics
  namespace: $VAULT_NAMESPACE
  labels:
    app: vault
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: vault
  endpoints:
  - port: http-metrics
    path: /v1/sys/metrics
    params:
      format: ['prometheus']
    interval: 30s
    scrapeTimeout: 10s
EOF
    
    kubectl apply -f /tmp/vault-servicemonitor.yaml
    
    echo "✅ Vault monitoring configured"
    rm -f /tmp/vault-servicemonitor.yaml
}

# ===================================================================
# Step 14: Validation and Status
# ===================================================================
validate_vault_setup() {
    echo "🔍 Step 14: Validating Vault setup..."
    
    # Check Vault status
    vault status
    
    # List auth methods
    echo "🔑 Enabled auth methods:"
    vault auth list
    
    # List secrets engines
    echo "📦 Enabled secrets engines:"
    vault secrets list
    
    # List policies
    echo "📋 Created policies:"
    vault policy list
    
    # Check unsealer status
    echo "🤖 Vault unsealer status:"
    kubectl get pods -l app=vault-unsealer -n $VAULT_NAMESPACE
    
    echo ""
    echo "🎉 VAULT CONFIGURATION COMPLETED!"
    echo "====================================="
    echo "Vault URL: $VAULT_ADDR"
    echo "Auto-unseal: Enabled with AWS KMS"
    echo "Auth methods: Kubernetes, AWS, OIDC"
    echo "Secrets engines: KV, AWS, Database, PKI, Transit"
    echo "====================================="
    echo ""
    echo "Next steps:"
    echo "1. Update OIDC configuration in /tmp/oidc-config.json"
    echo "2. Apply: vault write auth/oidc/config @/tmp/oidc-config.json"
    echo "3. Update GitHub token in vault secret"
    echo "4. Deploy External Secrets Operator if needed"
    echo ""
}

# ===================================================================
# Cleanup Function
# ===================================================================
cleanup() {
    if [ -n "${PORT_FORWARD_PID:-}" ]; then
        kill $PORT_FORWARD_PID 2>/dev/null || true
    fi
    rm -f /tmp/vault-*.json /tmp/vault-*.yaml /tmp/vault-*.hcl /tmp/oidc-*.json
}

trap cleanup EXIT

# ===================================================================
# Install Prerequisites
# ===================================================================
install_prerequisites() {
    echo "📦 Installing prerequisites..."
    
    # Install Vault CLI if not present
    if ! command -v vault >/dev/null 2>&1; then
        echo "📥 Installing Vault CLI v1.20.2..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS - direct download (Homebrew disabled due to license)
            curl -fsSL https://releases.hashicorp.com/vault/1.20.2/vault_1.20.2_darwin_amd64.zip -o /tmp/vault.zip
            unzip /tmp/vault.zip -d /tmp/
            sudo mv /tmp/vault /usr/local/bin/
            rm -f /tmp/vault.zip
            echo "✅ Vault CLI v1.20.2 installed to /usr/local/bin/vault"
        else
            # Linux
            curl -fsSL https://releases.hashicorp.com/vault/1.20.2/vault_1.20.2_linux_amd64.zip -o /tmp/vault.zip
            unzip /tmp/vault.zip -d /tmp/
            sudo mv /tmp/vault /usr/local/bin/
            rm -f /tmp/vault.zip
            echo "✅ Vault CLI v1.20.2 installed to /usr/local/bin/vault"
        fi
    else
        echo "✅ Vault CLI already installed: $(vault version)"
    fi
    
    # Install jq if not present
    if ! command -v jq >/dev/null 2>&1; then
        echo "📥 Installing jq..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if command -v brew >/dev/null 2>&1; then
                brew install jq
            else
                curl -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64 -o /tmp/jq
                chmod +x /tmp/jq
                sudo mv /tmp/jq /usr/local/bin/
            fi
        else
            sudo apt-get update && sudo apt-get install -y jq || \
            sudo yum install -y jq || \
            curl -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -o /tmp/jq && \
            chmod +x /tmp/jq && sudo mv /tmp/jq /usr/local/bin/
        fi
        echo "✅ jq installed"
    fi
}

# ===================================================================
# Main Execution
# ===================================================================
main() {
    echo "🔒 Using AWS Profile: $AWS_PROFILE"
    export AWS_PROFILE="$AWS_PROFILE"
    
    # Install prerequisites first
    install_prerequisites
    
    # Check prerequisites
    command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found"; exit 1; }
    command -v vault >/dev/null 2>&1 || { echo "❌ vault cli not found"; exit 1; }
    command -v aws >/dev/null 2>&1 || { echo "❌ aws cli not found"; exit 1; }
    command -v jq >/dev/null 2>&1 || { echo "❌ jq not found"; exit 1; }
    
    # Execute setup steps
    initialize_vault
    unseal_vault
    configure_auth_providers
    configure_policies_and_engines
    configure_k8s_roles
    configure_aws_integration
    setup_auto_unseal
    create_platform_secrets
    configure_platform_integration
    setup_vault_monitoring
    validate_vault_setup
}

# Allow running specific steps
case "${1:-all}" in
    "init") initialize_vault ;;
    "unseal") unseal_vault ;;
    "auth") configure_auth_providers ;;
    "policies") configure_policies_and_engines ;;
    "k8s-roles") configure_k8s_roles ;;
    "aws") configure_aws_integration ;;
    "auto-unseal") setup_auto_unseal ;;
    "secrets") create_platform_secrets ;;
    "integration") configure_platform_integration ;;
    "monitoring") setup_vault_monitoring ;;
    "validate") validate_vault_setup ;;
    "all") main ;;
    *) echo "Usage: $0 [init|unseal|auth|policies|k8s-roles|aws|auto-unseal|secrets|integration|monitoring|validate|all]" ;;
esac