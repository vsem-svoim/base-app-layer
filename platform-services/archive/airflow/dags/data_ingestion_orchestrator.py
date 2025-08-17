"""
Airflow DAG: Data Ingestion Business Orchestration
Handles business workflows, scheduling, SLA management, and triggers Argo Workflows for technical execution
"""

from datetime import datetime, timedelta
from typing import Dict, Any, List

from airflow import DAG
from airflow.providers.kubernetes.operators.kubernetes_pod import KubernetesPodOperator
from airflow.providers.http.operators.http import SimpleHttpOperator
from airflow.operators.python import PythonOperator, BranchPythonOperator
from airflow.operators.dummy import DummyOperator
from airflow.sensors.http_sensor import HttpSensor
from airflow.models import Variable
from airflow.utils.dates import days_ago
from airflow.utils.trigger_rule import TriggerRule

# Business Configuration
BUSINESS_CONFIG = {
    'market_data_sources': [
        {'name': 'bloomberg_api', 'priority': 'critical', 'sla_minutes': 5},
        {'name': 'reuters_api', 'priority': 'high', 'sla_minutes': 10},
        {'name': 'nyse_feed', 'priority': 'high', 'sla_minutes': 15},
    ],
    'reference_data_sources': [
        {'name': 'master_securities_db', 'priority': 'medium', 'sla_minutes': 60},
        {'name': 'corporate_actions_api', 'priority': 'medium', 'sla_minutes': 120},
    ],
    'alternative_data_sources': [
        {'name': 'social_sentiment_api', 'priority': 'low', 'sla_minutes': 240},
        {'name': 'satellite_imagery', 'priority': 'low', 'sla_minutes': 480},
    ],
    'business_hours': {
        'market_open': '09:00',
        'market_close': '16:00',
        'timezone': 'America/New_York'
    },
    'retry_policies': {
        'critical': {'max_retries': 5, 'retry_delay_minutes': 1},
        'high': {'max_retries': 3, 'retry_delay_minutes': 5},
        'medium': {'max_retries': 2, 'retry_delay_minutes': 15},
        'low': {'max_retries': 1, 'retry_delay_minutes': 60}
    }
}

default_args = {
    'owner': 'data-engineering',
    'depends_on_past': False,
    'start_date': days_ago(1),
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
    'email': ['data-engineering@company.com', 'data-alerts@company.com']
}

dag = DAG(
    'data_ingestion_orchestrator',
    default_args=default_args,
    description='Business orchestration for data ingestion with Argo Workflows execution',
    schedule_interval='@hourly',  # Business-level scheduling
    catchup=False,
    max_active_runs=3,
    tags=['data-ingestion', 'business-orchestration', 'production']
)

def determine_business_priority(**context) -> str:
    """
    Business logic to determine processing priority based on market conditions,
    time of day, and data source criticality
    """
    current_time = datetime.now()
    execution_date = context['execution_date']
    
    # Market hours logic
    market_hours = BUSINESS_CONFIG['business_hours']
    if (current_time.hour >= 9 and current_time.hour <= 16 and 
        current_time.weekday() < 5):  # Weekdays during market hours
        return "market_hours_critical"
    elif current_time.weekday() >= 5:  # Weekends
        return "weekend_maintenance"
    else:
        return "off_hours_standard"

def select_data_sources(**context) -> List[str]:
    """
    Business logic to select which data sources to process based on business rules
    """
    business_context = context['task_instance'].xcom_pull(task_ids='determine_business_priority')
    selected_sources = []
    
    if business_context == "market_hours_critical":
        # Process critical market data during business hours
        selected_sources.extend([
            source['name'] for source in BUSINESS_CONFIG['market_data_sources']
            if source['priority'] in ['critical', 'high']
        ])
        # Add reference data for market hours
        selected_sources.extend([
            source['name'] for source in BUSINESS_CONFIG['reference_data_sources']
        ])
        
    elif business_context == "off_hours_standard":
        # Process all data sources during off hours
        all_sources = (BUSINESS_CONFIG['market_data_sources'] + 
                      BUSINESS_CONFIG['reference_data_sources'] + 
                      BUSINESS_CONFIG['alternative_data_sources'])
        selected_sources.extend([source['name'] for source in all_sources])
        
    elif business_context == "weekend_maintenance":
        # Only low priority and maintenance tasks on weekends
        selected_sources.extend([
            source['name'] for source in BUSINESS_CONFIG['alternative_data_sources']
        ])
    
    print(f"Selected data sources for {business_context}: {selected_sources}")
    return selected_sources

def calculate_sla_deadline(source_name: str, business_context: str) -> str:
    """
    Calculate SLA deadline based on business rules and source priority
    """
    # Find source configuration
    all_sources = (BUSINESS_CONFIG['market_data_sources'] + 
                  BUSINESS_CONFIG['reference_data_sources'] + 
                  BUSINESS_CONFIG['alternative_data_sources'])
    
    source_config = next((s for s in all_sources if s['name'] == source_name), None)
    if not source_config:
        return (datetime.now() + timedelta(hours=1)).isoformat()
    
    # Adjust SLA based on business context
    sla_minutes = source_config['sla_minutes']
    if business_context == "market_hours_critical":
        sla_minutes = int(sla_minutes * 0.5)  # Tighter SLA during market hours
    elif business_context == "weekend_maintenance":
        sla_minutes = int(sla_minutes * 2.0)  # Relaxed SLA on weekends
    
    deadline = datetime.now() + timedelta(minutes=sla_minutes)
    return deadline.isoformat()

# Business Priority Determination
determine_priority_task = PythonOperator(
    task_id='determine_business_priority',
    python_callable=determine_business_priority,
    dag=dag
)

# Data Source Selection
select_sources_task = PythonOperator(
    task_id='select_data_sources',
    python_callable=select_data_sources,
    dag=dag
)

# Business Validation Gates
market_hours_gate = BranchPythonOperator(
    task_id='market_hours_gate',
    python_callable=lambda **context: (
        'critical_path_processing' if 
        context['task_instance'].xcom_pull(task_ids='determine_business_priority') == 'market_hours_critical'
        else 'standard_path_processing'
    ),
    dag=dag
)

# Critical Path for Market Hours
critical_path_start = DummyOperator(
    task_id='critical_path_processing',
    dag=dag
)

# Standard Path for Off Hours
standard_path_start = DummyOperator(
    task_id='standard_path_processing',
    dag=dag
)

# Function to create Argo Workflow execution tasks
def create_argo_workflow_task(source_name: str, priority: str) -> KubernetesPodOperator:
    """
    Create a KubernetesPodOperator that triggers an Argo Workflow for technical execution
    """
    return KubernetesPodOperator(
        task_id=f'execute_argo_workflow_{source_name}',
        name=f'argo-trigger-{source_name}',
        namespace='base-ingestion',
        image='argoproj/argo-cli:v3.5.5',
        cmds=['/bin/sh'],
        arguments=[
            '-c', f'''
            # Submit Argo Workflow with business context
            argo submit /templates/standard-ingestion-template.yaml \
                --name "ingestion-{source_name}-{{{{ ds_nodash }}}}-{{{{ ts_nodash }}}}" \
                --parameter source-url="{{{{ var.value.{source_name}_url }}}}" \
                --parameter source-type="{{{{ var.value.{source_name}_type }}}}" \
                --parameter priority="{priority}" \
                --parameter business-context="{{{{ ti.xcom_pull(task_ids='determine_business_priority') }}}}" \
                --parameter sla-deadline="$(python3 -c "from datetime import datetime, timedelta; print((datetime.now() + timedelta(minutes={BUSINESS_CONFIG['retry_policies'][priority]['retry_delay_minutes']})).isoformat())")" \
                --wait \
                --log
            '''
        ],
        volume_mounts=[{
            'name': 'workflow-templates',
            'mount_path': '/templates',
            'read_only': True
        }],
        volumes=[{
            'name': 'workflow-templates',
            'config_map': {'name': 'argo-workflow-templates'}
        }],
        env_vars={
            'ARGO_SERVER': 'argo-server.argo-workflows.svc.cluster.local:2746',
            'ARGO_NAMESPACE': 'base-ingestion'
        },
        get_logs=True,
        dag=dag,
        trigger_rule=TriggerRule.NONE_FAILED
    )

# Generate dynamic workflow execution tasks for each data source
workflow_tasks = {}
for source_list_name, source_list in [
    ('market_data_sources', BUSINESS_CONFIG['market_data_sources']),
    ('reference_data_sources', BUSINESS_CONFIG['reference_data_sources']),
    ('alternative_data_sources', BUSINESS_CONFIG['alternative_data_sources'])
]:
    for source in source_list:
        task_name = source['name']
        priority = source['priority']
        workflow_tasks[task_name] = create_argo_workflow_task(task_name, priority)

# Business Monitoring and SLA Tracking
def monitor_sla_compliance(**context):
    """
    Monitor SLA compliance and trigger business alerts if needed
    """
    execution_date = context['execution_date']
    business_context = context['task_instance'].xcom_pull(task_ids='determine_business_priority')
    
    # Check if any workflows are running beyond SLA
    print(f"Monitoring SLA compliance for execution: {execution_date}")
    print(f"Business context: {business_context}")
    
    # This would typically query Argo Workflows API to check status
    # and compare against business SLAs
    return "sla_monitoring_completed"

sla_monitoring_task = PythonOperator(
    task_id='monitor_sla_compliance',
    python_callable=monitor_sla_compliance,
    dag=dag,
    trigger_rule=TriggerRule.NONE_FAILED
)

# Business Reporting and Analytics
def generate_business_report(**context):
    """
    Generate business-level reporting on data ingestion performance
    """
    execution_date = context['execution_date']
    
    # This would typically aggregate metrics from Argo Workflows
    # and generate business-level KPIs
    business_metrics = {
        'execution_date': execution_date.isoformat(),
        'total_sources_processed': len([task for task in workflow_tasks.values()]),
        'sla_compliance_rate': 0.95,  # Would be calculated from actual data
        'business_impact_score': 'high',
        'data_freshness_score': 0.92
    }
    
    print(f"Business Report Generated: {business_metrics}")
    return business_metrics

business_report_task = PythonOperator(
    task_id='generate_business_report',
    python_callable=generate_business_report,
    dag=dag
)

# Error Handling and Business Escalation
def handle_business_escalation(**context):
    """
    Handle business-level escalations for failed ingestions
    """
    failed_tasks = context.get('failed_task_instances', [])
    
    if failed_tasks:
        critical_failures = [
            task for task in failed_tasks 
            if 'critical' in task.task_id or 'bloomberg' in task.task_id
        ]
        
        if critical_failures:
            # This would trigger business escalation procedures
            print("CRITICAL BUSINESS ESCALATION: Market data ingestion failures detected")
            # Send to business stakeholders, risk management, etc.
        
    return "escalation_handled"

escalation_task = PythonOperator(
    task_id='handle_business_escalation',
    python_callable=handle_business_escalation,
    dag=dag,
    trigger_rule=TriggerRule.ONE_FAILED
)

# Success Path Completion
success_completion = DummyOperator(
    task_id='business_workflow_completed',
    dag=dag,
    trigger_rule=TriggerRule.NONE_FAILED
)

# DAG Dependencies - Business Orchestration Flow
determine_priority_task >> select_sources_task >> market_hours_gate
market_hours_gate >> [critical_path_start, standard_path_start]

# Connect workflow execution tasks
for task_name, workflow_task in workflow_tasks.items():
    # Critical sources connect to critical path
    if any(source['name'] == task_name and source['priority'] == 'critical' 
           for source in BUSINESS_CONFIG['market_data_sources']):
        critical_path_start >> workflow_task
    else:
        standard_path_start >> workflow_task
    
    # All workflows feed into monitoring
    workflow_task >> sla_monitoring_task

# Final business workflow steps
sla_monitoring_task >> business_report_task >> success_completion

# Error handling path
sla_monitoring_task >> escalation_task
business_report_task >> escalation_task

if __name__ == "__main__":
    dag.test()