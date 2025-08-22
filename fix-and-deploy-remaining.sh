#!/bin/bash

# Fix and deploy remaining BASE modules
set -e

MODULES=(
    "data_distribution" 
    "data_quality"
    "data_security"
    "data_storage"
    "data_streaming"
    "event_coordination"
    "feature_engineering"
    "metadata_discovery"
    "multimodal_processing"
    "pipeline_management"
    "quality_monitoring"
    "schema_contracts"
)

# Fix kustomization for a module component
fix_kustomization() {
    local module=$1
    local component=$2
    local kustomize_file="/Users/ak/PycharmProjects/FinPortIQ/base-app-layer/${module}/${component}/kustomization.yaml"
    
    if [ -f "$kustomize_file" ]; then
        # Get list of yaml files
        yaml_files=$(find "/Users/ak/PycharmProjects/FinPortIQ/base-app-layer/${module}/${component}" -name "base-*.yaml" -exec basename {} \; | sort)
        
        if [ ! -z "$yaml_files" ]; then
            echo "  📝 Fixing kustomization for ${module}/${component}"
            
            # Create new kustomization content
            cat > "$kustomize_file" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
EOF
            # Add each yaml file
            echo "$yaml_files" | while read -r file; do
                echo "- $file" >> "$kustomize_file"
            done
            
            cat >> "$kustomize_file" << EOF

labels:
- includeSelectors: true
  pairs:
    app.kubernetes.io/part-of: base-platform
EOF
        fi
    fi
}

# Deploy a module
deploy_module() {
    local module=$1
    local namespace="base-${module//_/-}"
    
    echo "🔧 Deploying module: $module"
    
    # Fix kustomizations for all components
    fix_kustomization "$module" "agents"
    fix_kustomization "$module" "configs"
    fix_kustomization "$module" "models"
    fix_kustomization "$module" "orchestrators"
    fix_kustomization "$module" "workflows"
    
    # Deploy agents (these have content)
    echo "  🤖 Deploying agents for $module..."
    kubectl apply -k "/Users/ak/PycharmProjects/FinPortIQ/base-app-layer/${module}/agents/" || echo "  ⚠️  Agents deployment had issues"
    
    # Wait for pods to start
    sleep 3
    
    # Count running pods
    running=$(kubectl get pods -n "$namespace" 2>/dev/null | grep Running | wc -l || echo 0)
    total=$(kubectl get pods -n "$namespace" 2>/dev/null | tail -n +2 | wc -l || echo 0)
    echo "  📊 $module: $running/$total agents running"
    
    echo "  ✅ Module $module processed"
}

echo "🚀 Fixing and deploying remaining BASE modules"

for module in "${MODULES[@]}"; do
    deploy_module "$module"
done

echo ""
echo "📊 Final Status Summary:"
echo "========================"

total_running=0
total_pods=0

for ns in $(kubectl get namespaces | grep base- | awk '{print $1}'); do
    running=$(kubectl get pods -n "$ns" 2>/dev/null | grep Running | wc -l || echo 0)
    total=$(kubectl get pods -n "$ns" 2>/dev/null | tail -n +2 | wc -l || echo 0)
    total_running=$((total_running + running))
    total_pods=$((total_pods + total))
    echo "$ns: $running/$total running"
done

echo ""
echo "🎉 TOTAL: $total_running/$total_pods Gen AI agents running across all BASE modules"
echo "📦 $(kubectl get namespaces | grep base- | wc -l) BASE module namespaces deployed"