#!/bin/bash

# Fix resource constraints by reducing CPU/memory requests
set -e

echo "🔧 Fixing resource constraints for BASE agents"

# Get all BASE namespaces
NAMESPACES=$(kubectl get namespaces | grep base- | awk '{print $1}')

for ns in $NAMESPACES; do
    echo "📦 Processing namespace: $ns"
    
    # Get all deployments in this namespace
    DEPLOYMENTS=$(kubectl get deployments -n $ns -o name 2>/dev/null || echo "")
    
    if [ ! -z "$DEPLOYMENTS" ]; then
        for deployment in $DEPLOYMENTS; do
            echo "  🔄 Patching $deployment in $ns"
            
            # Patch the deployment to reduce resource requests
            kubectl patch $deployment -n $ns --type='merge' -p='{
                "spec": {
                    "template": {
                        "spec": {
                            "containers": [
                                {
                                    "name": "'$(echo $deployment | sed 's/.*-agent-//' | sed 's/deployment.apps\///')'",
                                    "resources": {
                                        "requests": {
                                            "cpu": "100m",
                                            "memory": "256Mi",
                                            "ephemeral-storage": "1Gi"
                                        },
                                        "limits": {
                                            "cpu": "500m",
                                            "memory": "1Gi",
                                            "ephemeral-storage": "5Gi"
                                        }
                                    }
                                }
                            ]
                        }
                    }
                }
            }' || echo "    ⚠️  Failed to patch $deployment"
        done
    else
        echo "  📭 No deployments found in $ns"
    fi
done

echo ""
echo "⏳ Waiting for pods to reschedule..."
sleep 10

echo ""
echo "📊 Updated Status:"
total_running=0
total_pods=0

for ns in $(kubectl get namespaces | grep base- | awk '{print $1}'); do
    running=$(kubectl get pods -n "$ns" 2>/dev/null | grep Running | wc -l || echo 0)
    total=$(kubectl get pods -n "$ns" 2>/dev/null | tail -n +2 | wc -l || echo 0)
    pending=$(kubectl get pods -n "$ns" 2>/dev/null | grep Pending | wc -l || echo 0)
    total_running=$((total_running + running))
    total_pods=$((total_pods + total))
    echo "$ns: $running running, $pending pending, $total total"
done

echo ""
echo "🎉 TOTAL: $total_running/$total_pods Gen AI agents running"

echo ""
echo "🔍 Checking for remaining scheduling issues..."
kubectl get events --all-namespaces | grep FailedScheduling | tail -5 || echo "No recent scheduling failures"