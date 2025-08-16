# Платформенные сервисы

Корпоративная платформа финансовых данных с интеграцией BASE слоя.

## Архитектура платформенных сервисов

### Фактически реализованные сервисы

**Terraform** - создает multi-cluster EKS инфраструктуру:
- BASE layer кластер (Fargate + managed nodes для namespace base-*)
- Platform services кластер (Airflow, MLflow, мониторинг)
- VPC с 3 AZ, NAT gateways, private/public subnets
- IRSA роли для AWS сервисов

**Airflow** - бизнес-оркестрация с KubernetesExecutor:
- Apache Airflow 2.7.2 с встроенной PostgreSQL
- DAG для gitops_platform_deployment.py и data_ingestion_orchestrator.py
- Integration с Argo Workflows для технической оркестрации
- Persistence на gp3 storage, ClusterIP сервисы

**ArgoCD** - GitOps автоматизация всех 14 BASE модулей:
- ApplicationSets для волнового развертывания (waves 1-4)
- Отдельные applications для каждого BASE модуля с AWS overlays
- Projects: base-layer, ml-apps, workflow-apps, monitoring-apps, orchestration-apps
- Автоматическая синхронизация из GitHub репозитория

**Crossplane** - Kubernetes-native Infrastructure as Code:
- AWS providers (EC2, RDS, S3, IAM)
- Compositions для postgresql, s3, cluster ресурсов
- Claims для dev/staging/prod окружений
- Integration с Terraform для hybrid IaC

**MLflow + Seldon Core + Kubeflow** - ML платформа:
- MLflow для experiment tracking и model registry
- Seldon Core для model serving и A/B testing
- Kubeflow для ML pipelines и katib hyperparameter tuning
- AWS-specific values для каждого компонента

**Monitoring Stack** - наблюдаемость:
- Prometheus для метрик, Grafana для dashboards
- AlertManager для уведомлений
- ELK stack (Elasticsearch, Logstash, Kibana) для логов
- Jaeger для distributed tracing

## Конфигурация

**Кластер**: platform-services-dev
**Окружение**: dev
**BASE слой**: https://github.com/vsem-svoim/base-app-layer.git

## Автоматизированное развертывание

### Полная автоматизация одной командой
```bash
./stage2-aws-provider.sh --region us-east-1
```

Этот скрипт выполняет последовательно:

**1. Создание AWS инфраструктуры (Terraform)**
- Создает multi-cluster EKS: base-layer + platform-services кластеры
- Настраивает VPC, subnets, NAT gateways, security groups
- Создает IRSA роли для всех BASE модулей
- Сохраняет state в S3 bucket с DynamoDB locking

**2. Конфигурация Crossplane провайдеров**
- Устанавливает crossplane-core в crossplane-system namespace
- Создает AWS providers (EC2, RDS, S3, IAM)
- Настраивает ProviderConfigs с AWS credentials
- Применяет compositions для database/storage/compute

**3. Волновое развертывание через ArgoCD ApplicationSets**

**Wave 1: Infrastructure**
```bash
kubectl apply -f argocd/applications/infrastructure/crossplane-core-aws.yaml
kubectl apply -f argocd/applications/infrastructure/crossplane-aws-providers.yaml
```

**Wave 2: Platform Services**
```bash
kubectl apply -f argocd/applications/platform-services/airflow-app.yaml
kubectl apply -f argocd/applications/platform-services/monitoring-stack-app.yaml
kubectl apply -f argocd/applications/workflow-apps/argo-*.yaml
```

**Wave 3: BASE Layer (все 14 модулей)**
```bash
kubectl apply -f argocd/applications/base-layer/data-ingestion-aws.yaml
kubectl apply -f argocd/applications/base-layer/data-quality-aws.yaml
kubectl apply -f argocd/applications/base-layer/feature-engineering-aws.yaml
# ... все остальные 11 модулей
```

**Wave 4: ML Platform**
```bash
kubectl apply -f argocd/applications/ml-platform/mlflow-app.yaml
kubectl apply -f argocd/applications/ml-platform/seldon-core-app.yaml
kubectl apply -f argocd/applications/ml-platform/kubeflow-app.yaml
```

**4. Активация автоматизированных ApplicationSets**
```bash
kubectl apply -f argocd/applicationsets/automated-platform-deployment.yaml
```

ApplicationSets автоматически:
- Создают applications для всех BASE модулей
- Применяют AWS-specific overlays из kustomize/
- Мониторят синхронизацию и health status
- Выполняют retry при ошибках

**5. Мониторинг развертывания**
Скрипт отслеживает 20 итераций по 30 секунд статус всех приложений:
```bash
kubectl get applications -n argocd -o custom-columns=NAME,PROJECT,SYNC,HEALTH
```

## Структура каталогов

```
platform-services/
├── argocd/                 # GitOps приложения
├── kustomize/              # BASE слой overlays
├── terraform/              # Infrastructure as Code
├── crossplane/             # Cloud-native инфраструктура
├── helm-charts/            # Платформенные сервисы
├── airflow/                # Конвейеры данных
├── ml-platform/            # ML сервисы
├── monitoring/             # Наблюдаемость
├── scripts/                # Утилиты развертывания
├── tests/                  # Тестовые наборы
├── docs/                   # Документация
├── policies/               # Политики безопасности
└── config/                 # Конфигурации окружений
```

## Компоненты BASE слоя

Все 14 компонентов развертываются через Kustomize overlays:

**Обработка данных:**
- data-ingestion, data-control, data-distribution
- data-quality, data-security, data-storage
- data-streaming, event-coordination

**Расширенная обработка:**
- feature-engineering, metadata-discovery
- multimodal-processing, pipeline-management
- quality-monitoring, schema-contracts

## Интеграция с главной архитектурой

Платформенные сервисы предоставляют инфраструктуру для всех 14 модулей BASE слоя:

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        ПЛАТФОРМЕННЫЕ СЕРВИСЫ                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────┐
│                            INFRASTRUCTURE AS CODE                                  │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐             │
│  │   Terraform  │ │  Crossplane  │ │  Kustomize   │ │    ArgoCD    │             │
│  │   модули     │ │ провайдеры   │ │   overlays   │ │   GitOps     │             │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘             │
│  • Multicloud    • Kubernetes     • Конфигурации  • Автоматизация                │
│    инфраструктура  native IaC       для окружений   развертывания                 │
│  • EKS/AKS/GKE   • AWS/Azure/GCP  • BASE компоненты• ApplicationSets             │
│  • Сети/хранилища • Композиции    • Платформенные • Волны развертывания          │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          ПЛАТФОРМЕННЫЕ СЕРВИСЫ                                     │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐             │
│  │   Airflow    │ │ PostgreSQL   │ │    Kafka     │ │ Мониторинг   │             │
│  │ оркестрация  │ │ база данных  │ │  сообщения   │ │ и алерты     │             │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘             │
│  • DAG управление• Метаданные     • Event streaming• Prometheus                   │
│  • Планировщик   • Конфигурации   • Pub/Sub модель • Grafana                     │
│  • Зависимости   • Состояние      • Партиционирование• AlertManager              │
│  • Мониторинг    • Репликация     • Retention       • Логирование                │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              ML ПЛАТФОРМА                                          │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐             │
│  │   MLflow     │ │  Kubeflow    │ │ Seldon Core  │ │   Jupiter    │             │
│  │ эксперименты │ │  конвейеры   │ │  serving     │ │  notebooks   │             │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘             │
│  • Tracking      • Pipeline       • Model serving • Интерактивная                │
│  • Model registry • Components    • A/B testing   • разработка                   │
│  • Artifacts     • Experiments    • Canary deploy • Исследования                 │
│  • Параметры     • Orchestration  • Scaling       • Visualization                │
└─────────────────────────────────────────────────────────────────────────────────────┘

## Интеграция с BASE слоем через AWS Overlays

### Как работают Kustomize overlays

Каждый из 14 BASE модулей имеет структуру:
```
kustomize/base-layer/data-ingestion/
├── base/kustomization.yaml          # Базовые манифесты
└── overlays/
    ├── aws/kustomization.yaml       # AWS-specific конфигурации
    ├── dev/kustomization.yaml       # Development окружение
    └── prod/kustomization.yaml      # Production окружение
```

### AWS overlay применяет:
```yaml
# kustomize/base-layer/data-ingestion/overlays/aws/kustomization.yaml
resources:
  - ../../base

patches:
  - target:
      kind: Deployment
    patch: |-
      - op: add
        path: /spec/template/spec/containers/0/env/-
        value:
          name: CLOUD_PROVIDER
          value: aws
      - op: add
        path: /spec/template/spec/nodeSelector
        value:
          kubernetes.io/os: linux
          node.kubernetes.io/instance-type: t3.medium

configMapGenerator:
  - name: data-ingestion-aws-config
    literals:
      - CLOUD_PROVIDER=aws
      - AWS_REGION=us-east-1
      - STORAGE_CLASS=gp3

commonLabels:
  cloud.provider: aws
```

### ArgoCD applications ссылаются на оба:
```yaml
# argocd/applications/base-layer/data-ingestion-aws.yaml
spec:
  sources:
    - repoURL: https://github.com/vsem-svoim/base-app-layer.git
      path: data_ingestion                    # Базовые манифесты
    - repoURL: https://github.com/vsem-svoim/base-app-layer.git  
      path: platform-services/kustomize/base-layer/data-ingestion/overlays/aws  # AWS конфигурации
```

### Результат для каждого BASE модуля:
- Pods получают environment variables для AWS
- NodeSelector для правильных instance types
- Storage class gp3 для AWS EBS
- Labels cloud.provider=aws для мониторинга
- ConfigMaps с AWS-specific настройками

## Следующие шаги

### 1. Проверка готовности
```bash
aws sts get-caller-identity
kubectl cluster-info
ls data_ingestion/  # Убедиться что BASE модули на месте
```

### 2. Запуск полной автоматизации
```bash
./stage2-aws-provider.sh --region us-east-1
```

### 3. Мониторинг развертывания
```bash
# Проверка ApplicationSets
kubectl get applicationsets -n argocd

# Проверка всех приложений по проектам
kubectl get applications -n argocd -o custom-columns=NAME,PROJECT,SYNC,HEALTH

# Проверка AWS-specific ресурсов
kubectl get pods -A -l cloud.provider=aws
kubectl get configmap -A | grep aws-config
```

### 4. Доступ к сервисам
```bash
# ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Airflow 
kubectl port-forward svc/airflow-webserver -n airflow 8081:8080

# MLflow
kubectl port-forward svc/mlflow -n mlflow 5000:5000

# Grafana
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
```

Платформа полностью автоматизирована: от Terraform инфраструктуры до GitOps развертывания всех 14 BASE модулей с AWS интеграцией.
