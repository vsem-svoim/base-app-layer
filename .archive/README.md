# BASE App Layer Platform v2
## Корпоративная платформа обработки данных с улучшенной архитектурой

### 🚀 Быстрый старт
```bash
# Полное развертывание
./automation/scripts/deploy-platform.sh

# Поэтапное развертывание
./automation/scripts/deploy-platform.sh core

ak@Alexanders-MBP scripts % ./deploy-platform.sh core
[2025-08-17 12:01:30] Deploying only core services (ArgoCD)
[STEP] Wave 0: Deploying Core Services
[2025-08-17 12:01:30] Deploying ArgoCD...
[2025-08-17 12:01:30] Cleaning up existing ArgoCD resources...
No existing namespace
No existing CRDs
No existing cluster resources
[2025-08-17 12:01:32] AWS Load Balancer Controller not found, removing orphaned webhooks...
[2025-08-17 12:01:33] Checking for conflicting Fargate profiles...
namespace/argocd created
[2025-08-17 12:01:35] Downloading ArgoCD manifests and adding EC2 node selectors...
[2025-08-17 12:01:35] yq not found, using python to add node selectors...
customresourcedefinition.apiextensions.k8s.io/applications.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/applicationsets.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/appprojects.argoproj.io created
serviceaccount/argocd-application-controller created
serviceaccount/argocd-applicationset-controller created
serviceaccount/argocd-dex-server created
serviceaccount/argocd-notifications-controller created
serviceaccount/argocd-redis created
serviceaccount/argocd-repo-server created
serviceaccount/argocd-server created
role.rbac.authorization.k8s.io/argocd-application-controller created
role.rbac.authorization.k8s.io/argocd-applicationset-controller created
role.rbac.authorization.k8s.io/argocd-dex-server created
role.rbac.authorization.k8s.io/argocd-notifications-controller created
role.rbac.authorization.k8s.io/argocd-redis created
role.rbac.authorization.k8s.io/argocd-server created
clusterrole.rbac.authorization.k8s.io/argocd-application-controller created
clusterrole.rbac.authorization.k8s.io/argocd-applicationset-controller created
clusterrole.rbac.authorization.k8s.io/argocd-server created
rolebinding.rbac.authorization.k8s.io/argocd-application-controller created
rolebinding.rbac.authorization.k8s.io/argocd-applicationset-controller created
rolebinding.rbac.authorization.k8s.io/argocd-dex-server created
rolebinding.rbac.authorization.k8s.io/argocd-notifications-controller created
rolebinding.rbac.authorization.k8s.io/argocd-redis created
rolebinding.rbac.authorization.k8s.io/argocd-server created
clusterrolebinding.rbac.authorization.k8s.io/argocd-application-controller created
clusterrolebinding.rbac.authorization.k8s.io/argocd-applicationset-controller created
clusterrolebinding.rbac.authorization.k8s.io/argocd-server created
configmap/argocd-cm created
configmap/argocd-cmd-params-cm created
configmap/argocd-gpg-keys-cm created
configmap/argocd-notifications-cm created
configmap/argocd-rbac-cm created
configmap/argocd-ssh-known-hosts-cm created
configmap/argocd-tls-certs-cm created
secret/argocd-notifications-secret created
secret/argocd-secret created
service/argocd-applicationset-controller created
service/argocd-dex-server created
service/argocd-metrics created
service/argocd-notifications-controller-metrics created
service/argocd-redis created
service/argocd-repo-server created
service/argocd-server created
service/argocd-server-metrics created
deployment.apps/argocd-applicationset-controller created
deployment.apps/argocd-dex-server created
deployment.apps/argocd-notifications-controller created
deployment.apps/argocd-redis created
deployment.apps/argocd-repo-server created
deployment.apps/argocd-server created
statefulset.apps/argocd-application-controller created
networkpolicy.networking.k8s.io/argocd-application-controller-network-policy created
networkpolicy.networking.k8s.io/argocd-applicationset-controller-network-policy created
networkpolicy.networking.k8s.io/argocd-dex-server-network-policy created
networkpolicy.networking.k8s.io/argocd-notifications-controller-network-policy created
networkpolicy.networking.k8s.io/argocd-redis-network-policy created
networkpolicy.networking.k8s.io/argocd-repo-server-network-policy created
networkpolicy.networking.k8s.io/argocd-server-network-policy created
[2025-08-17 12:01:44] Creating NodePort service for ArgoCD...
service/argocd-server-nodeport created
configmap/argocd-cmd-params-cm patched
[2025-08-17 12:01:46] Waiting for ArgoCD deployments to be ready on EC2 nodes...
deployment.apps/argocd-applicationset-controller condition met
deployment.apps/argocd-dex-server condition met
deployment.apps/argocd-notifications-controller condition met
deployment.apps/argocd-redis condition met
deployment.apps/argocd-repo-server condition met
deployment.apps/argocd-server condition met
[INFO] Checking health for argocd in namespace argocd
pod/argocd-server-5bc7747b8f-l5672 condition met
[INFO] argocd is healthy
secret/in-cluster created
secret/base-app-layer-repo created
secret/airflow-helm-repo created
secret/aws-eks-charts-repo created
secret/grafana-helm-repo created
secret/istio-helm-repo created
secret/kubeflow-helm-repo created
secret/bitnami-helm-repo created
secret/prometheus-helm-repo created
secret/hashicorp-helm-repo created
appproject.argoproj.io/aws-infrastructure created
appproject.argoproj.io/base-layer created
appproject.argoproj.io/ml-apps created
appproject.argoproj.io/monitoring-apps created
appproject.argoproj.io/orchestration-apps created
appproject.argoproj.io/workflow-apps created
[2025-08-17 12:02:19] ArgoCD deployed successfully!
[INFO] Access ArgoCD at: http://<node-ip>:30080 or https://<node-ip>:30443
[INFO] Get node IP with: kubectl get nodes -o wide
[INFO] Get admin password with: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
[2025-08-17 12:02:19] Core services deployment completed successfully
[STEP] Validating Deployment
[2025-08-17 12:02:19] === DEPLOYMENT STATUS ===
  argocd: deployed (healthy)
[2025-08-17 12:02:19] === CLUSTER STATUS ===
NAME                         STATUS   ROLES    AGE    VERSION               INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                                KERNEL-VERSION   CONTAINER-RUNTIME
ip-10-0-2-127.ec2.internal   Ready    <none>   140m   v1.33.1-eks-b9364f6   10.0.2.127    <none>        Bottlerocket OS 1.44.0 (aws-k8s-1.33)   6.12.37          containerd://2.0.5+bottlerocket
ip-10-0-4-12.ec2.internal    Ready    <none>   13h    v1.33.1-eks-b9364f6   10.0.4.12     <none>        Bottlerocket OS 1.44.0 (aws-k8s-1.33)   6.12.37          containerd://2.0.5+bottlerocket
ip-10-0-4-152.ec2.internal   Ready    <none>   13h    v1.33.1-eks-b9364f6   10.0.4.152    <none>        Bottlerocket OS 1.44.0 (aws-k8s-1.33)   6.12.37          containerd://2.0.5+bottlerocket
ip-10-0-4-220.ec2.internal   Ready    <none>   13h    v1.33.1-eks-b9364f6   10.0.4.220    <none>        Bottlerocket OS 1.44.0 (aws-k8s-1.33)   6.12.37          containerd://2.0.5+bottlerocket
[2025-08-17 12:02:20] === SERVICE ENDPOINTS ===
No resources found
=== DEPLOYMENT COMPLETE ===
ArgoCD Access:
  URL: kubectl port-forward svc/argocd-server -n argocd 8080:443
  Username: admin
  Password: Y4fLQtY6z8F4ncI9

Platform UI:
  URL: http://base-platform-dashboard-44


./automation/scripts/deploy-platform.sh shared
./automation/scripts/deploy-platform.sh orchestration
./automation/scripts/deploy-platform.sh apps

# Валидация платформы
./automation/scripts/validate-platform.sh
```

## 🏗️ Архитектура платформы

### Схема развертывания по волнам
```
┌─────────────────────────────────────────────────────────────────┐
│                     AWS EKS CLUSTERS                           │
├─────────────────────────────────────────────────────────────────┤
│  Platform Cluster          │        Base Cluster               │
│  ┌─────────────────────────┐│        ┌─────────────────────────┐ │
│  │ ВОЛНА 0: Core Services  ││        │ BASE Layer Modules     │ │
│  │ ├─ ArgoCD              ││        │ ├─ data-ingestion      │ │
│  │ ├─ Vault               ││        │ ├─ data-quality        │ │
│  │ ├─ Cert-Manager        ││        │ ├─ data-storage        │ │
│  │ └─ AWS LB Controller   ││        │ ├─ data-security       │ │
│  │                        ││        │ └─ ... (14 модулей)    │ │
│  │ ВОЛНА 1: Shared        ││        └─────────────────────────┘ │
│  │ ├─ Monitoring          ││                                    │
│  │ ├─ Logging             ││                                    │
│  │ └─ Service Mesh        ││                                    │
│  │                        ││                                    │
│  │ ВОЛНА 2: Orchestration ││                                    │
│  │ ├─ Airflow             ││                                    │
│  │ ├─ MLflow              ││                                    │
│  │ ├─ Kubeflow            ││                                    │
│  │ └─ Argo Workflows      ││                                    │
│  │                        ││                                    │
│  │ ВОЛНА 3: Applications  ││                                    │
│  │ ├─ Platform UI         ││                                    │
│  │ ├─ API Gateway         ││                                    │
│  │ └─ Data Services       ││                                    │
│  └─────────────────────────┘│                                    │
└─────────────────────────────────────────────────────────────────┘
```

### Поток данных
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Internet  │    │     ALB     │    │ Platform UI │    │   ArgoCD    │
│     User    │───▶│   Gateway   │───▶│  Dashboard  │───▶│   GitOps    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                           │                   │                   │
                           ▼                   ▼                   ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Vault     │    │   Airflow   │    │   MLflow    │    │    BASE     │
│ Auth/Secrets│◀───│  Workflows  │◀───│  ML Models  │◀───│   Modules   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                           │                   │                   │
                           ▼                   ▼                   ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Prometheus  │    │   Grafana   │    │     ELK     │    │    Istio    │
│  Metrics    │───▶│ Dashboards  │    │   Logging   │    │ Service Mesh│
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## 📁 Структура каталогов

```
platform-services-v2/
├── 🏗️  bootstrap/                    # Инфраструктура
│   ├── terraform/                   # IaC для AWS
│   ├── scripts/                     # Скрипты инициализации
│   └── configs/                     # Базовые конфигурации
│
├── 🔧 core-services/                # ВОЛНА 0: Основные сервисы
│   ├── argocd/                      # GitOps контроллер
│   ├── vault/                       # Управление секретами
│   ├── cert-manager/                # TLS сертификаты
│   └── aws-load-balancer-controller/
│
├── 🌐 shared-services/              # ВОЛНА 1: Общие сервисы
│   ├── monitoring/                  # Prometheus + Grafana
│   ├── logging/                     # ELK Stack
│   ├── service-mesh/                # Istio
│   ├── ingress/                     # Общие Ingress
│   └── storage/                     # Хранилище
│
├── ⚙️  orchestration-services/       # ВОЛНА 2: Оркестрация
│   ├── airflow/                     # Рабочие процессы
│   ├── mlflow/                      # ML жизненный цикл
│   ├── kubeflow/                    # ML пайплайны
│   └── argo-workflows/              # CI/CD процессы
│
├── 📱 application-services/         # ВОЛНА 3: Приложения
│   ├── platform-ui/                 # Панель управления
│   ├── api-gateway/                 # API шлюз
│   └── data-services/               # Шлюз к BASE модулям
│
├── 🤖 automation/                   # Автоматизация
│   ├── scripts/                     # Скрипты развертывания
│   ├── gitops/                      # ArgoCD конфигурации
│   └── testing/                     # Автотесты
│
└── 🌍 environments/                 # Среды
    ├── overlays/                    # dev/staging/prod
    └── secrets/                     # Зашифрованные секреты
```

## 🔄 Управление зависимостями

### Матрица зависимостей
```
┌─────────────────┬─────────────────┬─────────────────┬─────────────────┐
│ ВОЛНА 0         │ ВОЛНА 1         │ ВОЛНА 2         │ ВОЛНА 3         │
│ Core Services   │ Shared Services │ Orchestration   │ Applications    │
├─────────────────┼─────────────────┼─────────────────┼─────────────────┤
│ ArgoCD          │ Monitoring      │ Airflow         │ Platform UI     │
│ │               │ │               │ │               │ │               │
│ ├─ Vault        │ ├─ Logging      │ ├─ MLflow       │ ├─ API Gateway  │
│ │               │ │  (depends on  │ │  (depends on  │ │  (depends on  │
│ ├─ Cert-Manager │ │   Vault)      │ │   Monitoring, │ │   Monitoring, │
│ │               │ │               │ │   Vault)      │ │   Airflow,    │
│ └─ AWS LB Ctrl  │ └─ Service Mesh │ │               │ │   Vault)      │
│   (no deps)     │   (depends on   │ ├─ Kubeflow     │ │               │
│                 │    Cert-Manager)│ │  (depends on  │ └─ Data Services│
│                 │                 │ │   Monitoring, │   (depends on   │
│                 │                 │ │   Vault,      │    Monitoring,  │
│                 │                 │ │   Service     │    Airflow,     │
│                 │                 │ │   Mesh)       │    Vault)       │
│                 │                 │ │               │                 │
│                 │                 │ └─ Argo Workflows│                │
│                 │                 │   (depends on  │                 │
│                 │                 │    Monitoring, │                 │
│                 │                 │    Vault)      │                 │
└─────────────────┴─────────────────┴─────────────────┴─────────────────┘
```

## ⚡ Команды развертывания

### Основные команды
```bash
# Полное развертывание
./automation/scripts/deploy-platform.sh

# Компонентное развертывание
./automation/scripts/deploy-platform.sh core          # Основные сервисы
./automation/scripts/deploy-platform.sh shared        # Общие сервисы  
./automation/scripts/deploy-platform.sh orchestration # Оркестрация
./automation/scripts/deploy-platform.sh apps          # Приложения

# Проверка состояния
./automation/scripts/validate-platform.sh
./automation/scripts/validate-platform.sh core        # Только основные
./automation/scripts/validate-platform.sh security    # Безопасность
```

### Переменные окружения
```bash
# Настройка среды
export ENVIRONMENT=dev                    # dev/staging/prod
export REGION=us-east-1                   # AWS регион
export AWS_PROFILE=your-profile           # AWS профиль

# Развертывание с переменными
ENVIRONMENT=staging ./automation/scripts/deploy-platform.sh
```

## 🔐 Безопасность и доступ

### Аутентификация через Vault
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    User     │───▶│ Platform UI │───▶│    Vault    │
│             │    │  (Login)    │    │ (userpass)  │
└─────────────┘    └─────────────┘    └─────────────┘
                           │                   │
                           ▼                   ▼
                   ┌─────────────┐    ┌─────────────┐
                   │  Dashboard  │    │  Services   │
                   │   Access    │───▶│   Access    │
                   └─────────────┘    └─────────────┘
```

### Роли и права доступа
- **admin**: Полный доступ ко всем сервисам
- **developer**: Доступ к развертыванию и мониторингу
- **data-scientist**: Доступ к ML сервисам и данным

## 📊 Мониторинг и логирование

### Стек мониторинга
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Prometheus  │───▶│   Grafana   │    │ AlertManager│
│  (Metrics)  │    │(Dashboards) │    │  (Alerts)   │
└─────────────┘    └─────────────┘    └─────────────┘
        │                   │                   │
        ▼                   ▼                   ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Services  │    │    Users    │    │   Webhooks  │
│  Metrics    │    │   Access    │    │   Slack/MS  │
└─────────────┘    └─────────────┘    └─────────────┘
```

### Логирование
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Pods      │───▶│  Logstash   │───▶│Elasticsearch│
│   Logs      │    │(Processing) │    │  (Storage)  │
└─────────────┘    └─────────────┘    └─────────────┘
                                              │
                                              ▼
                                     ┌─────────────┐
                                     │   Kibana    │
                                     │(Dashboards) │
                                     └─────────────┘
```

## 🌐 Доступ к сервисам

### Веб-интерфейсы
```bash
# Platform UI (внешний доступ)
http://[ALB-DNS-NAME]

# ArgoCD (port-forward)
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080

# Grafana (port-forward)
kubectl port-forward svc/grafana -n monitoring 3000:80
# http://localhost:3000

# Airflow (port-forward)
kubectl port-forward svc/airflow-webserver -n airflow 8081:8080
# http://localhost:8081
```

### CLI доступ
```bash
# kubectl контексты
kubectl config get-contexts

# ArgoCD CLI
argocd login localhost:8080
argocd app list

# Vault CLI
export VAULT_ADDR="http://localhost:8200"
vault auth -method=userpass username=admin
```

## 🔧 Устранение неполадок

### Основные команды диагностики
```bash
# Проверка подов
kubectl get pods --all-namespaces

# Проверка приложений ArgoCD
kubectl get applications -n argocd

# Логи сервисов
kubectl logs -f deployment/[service-name] -n [namespace]

# Проверка состояния узлов
kubectl get nodes -o wide

# Проверка событий
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

### Частые проблемы
1. **Приложения не синхронизируются**: Проверить статус ArgoCD
2. **Поды не запускаются**: Проверить ресурсы и образы
3. **Сеть не работает**: Проверить Istio и сетевые политики
4. **Мониторинг не собирает метрики**: Проверить ServiceMonitor

## 📈 Масштабирование

### Горизонтальное масштабирование
```yaml
# HPA пример
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: platform-ui-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: platform-ui-dashboard
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Вертикальное масштабирование
```yaml
# VPA пример
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: platform-ui-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: platform-ui-dashboard
  updatePolicy:
    updateMode: "Auto"
```

## 🔄 Обновления и откаты

### Обновление сервисов
```bash
# Обновление через ArgoCD
kubectl patch application [app-name] -n argocd \
  -p '{"spec":{"source":{"targetRevision":"new-version"}}}'

# Ручное обновление образа
kubectl set image deployment/[deployment] [container]=[new-image] -n [namespace]
```

### Откат изменений
```bash
# Откат развертывания
kubectl rollout undo deployment/[deployment] -n [namespace]

# Откат приложения ArgoCD
kubectl patch application [app-name] -n argocd \
  -p '{"spec":{"source":{"targetRevision":"previous-version"}}}'
```

## 📝 Конфигурация сред

### Переопределения для разных сред
```yaml
# environments/overlays/dev/platform-config.yaml
environment: dev
monitoring-enabled: true
vault-enabled: true
resources:
  requests:
    cpu: 100m
    memory: 256Mi

# environments/overlays/prod/platform-config.yaml  
environment: prod
monitoring-enabled: true
vault-enabled: true
resources:
  requests:
    cpu: 500m
    memory: 1Gi
```

## 🎯 Производительность

### Целевые показатели
- **Пропускная способность**: 100GB/час обработки данных
- **Доступность**: 99.9% uptime
- **Восстановление**: RTO 4 часа, RPO 15 минут
- **Масштабирование**: 2-20 реплик автоматически

### Мониторинг производительности
- CPU/Memory использование
- Пропускная способность сети
- Время отклика API
- Количество обработанных данных

---

## 🚀 Быстрые команды

```bash
# Развернуть всю платформу
./automation/scripts/deploy-platform.sh

# Проверить состояние
./automation/scripts/validate-platform.sh

# Очистить все
./destroy-all-applications.sh

# Получить доступ к UI
echo "Platform UI: http://$(kubectl get ingress platform-ui-ingress -n platform-ui -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
```