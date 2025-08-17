"""
GitOps Platform Deployment DAG
Automated deployment orchestration using Airflow + Argo Workflows + ArgoCD
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.providers.kubernetes.operators.kubernetes_pod import KubernetesPodOperator
from airflow.providers.kubernetes.sensors.spark_kubernetes import SparkKubernetesSensor
from airflow.sensors.external_task import ExternalTaskSensor
from airflow.models import Variable
import subprocess
import json
import logging

# DAG Configuration
default_args = {
    'owner': 'platform-team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
    'max_active_runs': 1,
}

dag = DAG(
    'gitops_platform_deployment',
    default_args=default_args,
    description='Automated GitOps platform deployment with wave orchestration',
    schedule_interval='@daily',  # Can be triggered manually or by webhook
    catchup=False,
    tags=['gitops', 'platform', 'deployment', 'automated'],
)

# Configuration variables
GIT_REPO = Variable.get("GIT_REPO", default_var="https://github.com/vsem-svoim/base-app-layer.git")
GIT_REVISION = Variable.get("GIT_REVISION", default_var="main")
ENVIRONMENT = Variable.get("DEPLOYMENT_ENVIRONMENT", default_var="dev")
ARGOCD_NAMESPACE = "argocd"

def check_prerequisites(**context):
    """Check if cluster and ArgoCD are ready for deployment"""
    logging.info("🔍 Checking deployment prerequisites...")
    
    try:
        # Check ArgoCD availability
        result = subprocess.run([
            'kubectl', 'get', 'deployment', 'argocd-server', 
            '-n', ARGOCD_NAMESPACE, '-o', 'json'
        ], capture_output=True, text=True, check=True)
        
        argocd_info = json.loads(result.stdout)
        ready_replicas = argocd_info.get('status', {}).get('readyReplicas', 0)
        
        if ready_replicas > 0:
            logging.info("✅ ArgoCD is ready")
            return True
        else:
            raise Exception("❌ ArgoCD is not ready")
            
    except Exception as e:
        logging.error(f"Prerequisites check failed: {e}")
        raise

def cleanup_previous_deployment(**context):
    """Clean up any existing deployments for a fresh start"""
    logging.info("🧹 Cleaning up previous deployments...")
    
    try:
        # Clean up applications
        subprocess.run([
            'kubectl', 'delete', 'applications', '--all', 
            '-n', ARGOCD_NAMESPACE, '--timeout=60s'
        ], check=False)  # Don't fail if nothing to delete
        
        # Clean up ApplicationSets
        subprocess.run([
            'kubectl', 'delete', 'applicationsets', '--all', 
            '-n', ARGOCD_NAMESPACE, '--timeout=60s'
        ], check=False)
        
        logging.info("✅ Cleanup completed")
        return True
        
    except Exception as e:
        logging.error(f"Cleanup failed: {e}")
        # Don't fail the DAG if cleanup has issues
        return True

def trigger_gitops_workflow(**context):
    """Trigger the GitOps deployment workflow"""
    logging.info("🚀 Triggering GitOps deployment workflow...")
    
    workflow_yaml = f"""
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: airflow-triggered-gitops-
  namespace: {ARGOCD_NAMESPACE}
  labels:
    workflows.argoproj.io/triggered-by: "airflow"
    airflow-dag-id: "{context['dag'].dag_id}"
    airflow-run-id: "{context['dag_run'].run_id}"
spec:
  entrypoint: gitops-deployment-pipeline
  serviceAccountName: argo-workflows
  workflowTemplateRef:
    name: gitops-automated-deployment
  arguments:
    parameters:
      - name: git-repo
        value: "{GIT_REPO}"
      - name: git-revision
        value: "{GIT_REVISION}"
      - name: environment
        value: "{ENVIRONMENT}"
"""
    
    try:
        # Apply the workflow
        process = subprocess.run([
            'kubectl', 'apply', '-f', '-'
        ], input=workflow_yaml, text=True, capture_output=True, check=True)
        
        logging.info("✅ GitOps workflow triggered successfully")
        
        # Get the workflow name for monitoring
        result = subprocess.run([
            'kubectl', 'get', 'workflows', '-n', ARGOCD_NAMESPACE,
            '-l', f'airflow-run-id={context["dag_run"].run_id}',
            '-o', 'jsonpath={.items[0].metadata.name}'
        ], capture_output=True, text=True, check=True)
        
        workflow_name = result.stdout.strip()
        logging.info(f"📋 Workflow name: {workflow_name}")
        
        # Store workflow name for downstream tasks
        context['task_instance'].xcom_push(key='workflow_name', value=workflow_name)
        return workflow_name
        
    except Exception as e:
        logging.error(f"Failed to trigger workflow: {e}")
        raise

def monitor_deployment_progress(**context):
    """Monitor the deployment progress"""
    workflow_name = context['task_instance'].xcom_pull(key='workflow_name')
    
    if not workflow_name:
        raise Exception("No workflow name found in XCom")
    
    logging.info(f"📊 Monitoring workflow: {workflow_name}")
    
    try:
        # Get workflow status
        result = subprocess.run([
            'kubectl', 'get', 'workflow', workflow_name, 
            '-n', ARGOCD_NAMESPACE, '-o', 'json'
        ], capture_output=True, text=True, check=True)
        
        workflow_info = json.loads(result.stdout)
        phase = workflow_info.get('status', {}).get('phase', 'Unknown')
        progress = workflow_info.get('status', {}).get('progress', '0/0')
        
        logging.info(f"📈 Workflow Status: {phase}, Progress: {progress}")
        
        # Store status for next tasks
        context['task_instance'].xcom_push(key='deployment_status', value=phase)
        context['task_instance'].xcom_push(key='deployment_progress', value=progress)
        
        return phase
        
    except Exception as e:
        logging.error(f"Failed to get workflow status: {e}")
        raise

def validate_deployment(**context):
    """Validate the complete deployment"""
    logging.info("🔍 Validating deployment...")
    
    try:
        # Count applications
        result = subprocess.run([
            'kubectl', 'get', 'applications', '-n', ARGOCD_NAMESPACE, 
            '--no-headers'
        ], capture_output=True, text=True, check=True)
        
        total_apps = len(result.stdout.strip().split('\n')) if result.stdout.strip() else 0
        
        # Check healthy applications
        result = subprocess.run([
            'kubectl', 'get', 'applications', '-n', ARGOCD_NAMESPACE,
            '-o', 'jsonpath={.items[?(@.status.health.status=="Healthy")].metadata.name}'
        ], capture_output=True, text=True, check=True)
        
        healthy_apps = len(result.stdout.strip().split()) if result.stdout.strip() else 0
        
        logging.info(f"📊 Deployment Summary: {healthy_apps}/{total_apps} applications healthy")
        
        # Validation criteria
        if total_apps > 0 and healthy_apps >= (total_apps * 0.8):  # 80% success rate
            logging.info("✅ Deployment validation PASSED")
            return True
        else:
            logging.warning("⚠️  Deployment validation WARNING")
            return False
            
    except Exception as e:
        logging.error(f"Validation failed: {e}")
        raise

def send_deployment_notification(**context):
    """Send deployment completion notification"""
    status = context['task_instance'].xcom_pull(key='deployment_status')
    progress = context['task_instance'].xcom_pull(key='deployment_progress')
    
    logging.info(f"📢 Deployment completed with status: {status}")
    logging.info(f"📊 Final progress: {progress}")
    
    # Here you could integrate with Slack, Teams, email, etc.
    return True

# Task Definitions
check_prerequisites_task = PythonOperator(
    task_id='check_prerequisites',
    python_callable=check_prerequisites,
    dag=dag,
)

cleanup_task = PythonOperator(
    task_id='cleanup_previous_deployment',
    python_callable=cleanup_previous_deployment,
    dag=dag,
)

trigger_workflow_task = PythonOperator(
    task_id='trigger_gitops_workflow',
    python_callable=trigger_gitops_workflow,
    dag=dag,
)

# Monitor deployment with retries
monitor_task = PythonOperator(
    task_id='monitor_deployment_progress',
    python_callable=monitor_deployment_progress,
    dag=dag,
    retries=10,
    retry_delay=timedelta(minutes=2),
)

# Wait for Argo Workflows completion using Kubernetes sensor
wait_for_completion = KubernetesPodOperator(
    task_id='wait_for_workflow_completion',
    name='workflow-monitor',
    namespace=ARGOCD_NAMESPACE,
    image='argoproj/argocd:v2.8.4',
    cmds=['sh', '-c'],
    arguments=["""
        WORKFLOW_NAME=$(kubectl get workflows -n argocd -l airflow-run-id={{ dag_run.run_id }} -o jsonpath='{.items[0].metadata.name}')
        echo "Waiting for workflow: $WORKFLOW_NAME"
        
        while true; do
            PHASE=$(kubectl get workflow $WORKFLOW_NAME -n argocd -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
            echo "Workflow $WORKFLOW_NAME status: $PHASE"
            
            case $PHASE in
                "Succeeded")
                    echo "✅ Workflow completed successfully"
                    exit 0
                    ;;
                "Failed"|"Error")
                    echo "❌ Workflow failed"
                    exit 1
                    ;;
                *)
                    echo "⏳ Workflow still running..."
                    sleep 30
                    ;;
            esac
        done
    """],
    is_delete_operator_pod=True,
    dag=dag,
)

validate_task = PythonOperator(
    task_id='validate_deployment',
    python_callable=validate_deployment,
    dag=dag,
)

notification_task = PythonOperator(
    task_id='send_deployment_notification',
    python_callable=send_deployment_notification,
    dag=dag,
    trigger_rule='all_done',  # Run even if previous tasks fail
)

# Task Dependencies
check_prerequisites_task >> cleanup_task >> trigger_workflow_task
trigger_workflow_task >> monitor_task >> wait_for_completion
wait_for_completion >> validate_task >> notification_task

# Additional parallel monitoring task
health_check_task = BashOperator(
    task_id='continuous_health_check',
    bash_command="""
    echo "🔍 Running continuous health checks..."
    
    for i in {1..10}; do
        echo "Health check iteration $i"
        
        # Check ArgoCD applications
        kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,HEALTH:.status.health.status,SYNC:.status.sync.status
        
        # Check pod status in key namespaces
        for ns in argocd mlflow seldon-system monitoring; do
            if kubectl get namespace $ns >/dev/null 2>&1; then
                echo "=== Namespace: $ns ==="
                kubectl get pods -n $ns --no-headers | head -5
            fi
        done
        
        sleep 30
    done
    """,
    dag=dag,
)

# Parallel health monitoring
trigger_workflow_task >> health_check_task
health_check_task >> validate_task