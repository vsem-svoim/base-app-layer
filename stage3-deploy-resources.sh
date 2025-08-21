#!/bin/bash

# ЭТАП 3: Развертывание ресурсов
# Инициализация платформы
# Версия: 1.0.0

set -euo pipefail

# Параметры
ENVIRONMENT="${1:-dev}"
CLOUD_PROVIDER="${2:-aws}"
REGION="${3:-us-east-1}"
CLUSTER_NAME=""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Логирование
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

show_help() {
    cat << EOF
ЭТАП 3: Развертывание ресурсов
Использование: $0 [ENVIRONMENT] [PROVIDER] [REGION]

Аргументы:
  ENVIRONMENT   Окружение (dev|staging|prod) [по умолчанию: dev]
  PROVIDER      Провайдер (aws|gcp|azure|onprem) [по умолчанию: aws]
  REGION        Регион [по умолчанию: us-east-1]

Примеры:
  $0 dev aws us-east-1
  $0 staging gcp us-central1
  $0 prod azure eastus

Опции:
  -h, --help    Показать справку
EOF
}

# Проверка аргументов
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

log "========================================="
log "Инициализация платформы ${PROJECT_NAME:-FinPortIQ}"
log "========================================="
log_info "Окружение: ${ENVIRONMENT}"
log_info "Провайдер: ${CLOUD_PROVIDER}"
log_info "Регион: ${REGION}"

# Проверка зависимостей
# Load platform configuration created by Stage 1
load_platform_config() {
    if [[ -f ".platform-config" ]]; then
        log "Загрузка конфигурации платформы..."
        source .platform-config
        CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
        log_info "Проект: $PROJECT_NAME"
        log_info "GitHub пользователь: $GITHUB_USER"
        log_info "Кластер: $CLUSTER_NAME"
        log_info "Окружение: $ENVIRONMENT"
        log_info "Repository URL: $REPOSITORY_URL"
    else
        log_error "Файл .platform-config не найден. Запустите Stage 1 сначала."
        exit 1
    fi
}

check_dependencies() {
    log "Проверка зависимостей..."

    deps=("terraform" "kubectl" "helm")

    case $CLOUD_PROVIDER in
        aws) deps+=("aws") ;;
        gcp) deps+=("gcloud") ;;
        azure) deps+=("az") ;;
    esac

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "$dep не установлен"
            exit 1
        fi
    done

    log "Все зависимости установлены"
}

# Load Stage 2 configuration
load_stage2_config() {
    if [[ -f ".stage1-output" ]]; then
        log "Загрузка конфигурации из Stage 2..."
        source .stage1-output
        log "✅ Stage 2 конфигурация загружена"
    else
        log_error "Файл .stage1-output не найден. Запустите Stage 2 сначала."
        exit 1
    fi
}

# Load AWS configuration saved by Stage 2
load_aws_config() {
    if [[ -f ".aws-config" ]] && [[ "$CLOUD_PROVIDER" == "aws" ]]; then
        log "Загрузка AWS конфигурации из Stage 2..."
        source .aws-config
        log "✅ AWS конфигурация загружена:"
        log "   AWS_PROFILE: ${AWS_PROFILE:-not set}"
        log "   AWS_DEFAULT_REGION: ${AWS_DEFAULT_REGION:-not set}"
        
        # Set AWS environment variables
        if [[ -n "${AWS_PROFILE:-}" ]]; then
            export AWS_PROFILE
        fi
        if [[ -n "${AWS_DEFAULT_REGION:-}" ]]; then
            export AWS_DEFAULT_REGION
        fi
    else
        # Fallback to standard SSO profile
        if [[ "$CLOUD_PROVIDER" == "aws" ]]; then
            log_warning "AWS config file not found, using default SSO profile..."
            export AWS_PROFILE="akovalenko-084129280818-AdministratorAccess"
            export AWS_DEFAULT_REGION="$REGION"
            log "✅ Using AWS profile: $AWS_PROFILE"
        fi
    fi
}

# Validate cloud provider configuration
validate_cloud_config() {
    log "Проверка конфигурации облачного провайдера..."

    case $CLOUD_PROVIDER in
        aws)
            if [[ -z "${AWS_PROFILE:-}" ]]; then
                log_error "AWS_PROFILE не установлен. Запустите Stage 2 сначала или установите профиль вручную."
                exit 1
            fi
            
            # Test AWS access
            if ! aws sts get-caller-identity &> /dev/null; then
                log_error "AWS доступ не настроен. Проверьте AWS_PROFILE: $AWS_PROFILE"
                log_error "Попробуйте: aws sso login --profile $AWS_PROFILE"
                exit 1
            fi
            
            log "✅ AWS доступ подтвержден с профилем: $AWS_PROFILE"
            ;;
        gcp)
            if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 &> /dev/null; then
                log_error "GCP не аутентифицирован. Выполните 'gcloud auth login'"
                exit 1
            fi
            project_id=$(gcloud config get-value project 2>/dev/null || echo "")
            if [[ -z "$project_id" ]]; then
                log_error "GCP проект не установлен. Выполните 'gcloud config set project PROJECT_ID'"
                exit 1
            fi
            log "✅ GCP проект подтвержден: $project_id"
            ;;
        azure)
            if ! az account show &> /dev/null; then
                log_error "Azure не аутентифицирован. Выполните 'az login'"
                exit 1
            fi
            log "✅ Azure доступ подтвержден"
            ;;
        onprem)
            log "✅ On-premises конфигурация"
            ;;
        *)
            log_error "Неподдерживаемый провайдер: $CLOUD_PROVIDER"
            exit 1
            ;;
    esac
}

# Создание облачного backend для Terraform
create_cloud_backend() {
    log "Создание облачного backend для Terraform..."

    case $CLOUD_PROVIDER in
        aws)
            create_aws_backend
            ;;
        gcp)
            create_gcp_backend
            ;;
        azure)
            create_azure_backend
            ;;
        onprem)
            log "On-premises: используется локальный backend"
            ;;
    esac
}

create_aws_backend() {
    log "Создание AWS S3 backend..."
    
    # Use project name from config if available, otherwise use default
    local project_name_lower
    if [[ -n "${PROJECT_NAME:-}" ]]; then
        project_name_lower=$(echo "${PROJECT_NAME}" | tr '[:upper:]' '[:lower:]')
    else
        project_name_lower="platform-services"
    fi
    
    bucket_name="${project_name_lower}-terraform-state-${REGION}"
    table_name="${project_name_lower}-terraform-locks"

    # Создание S3 bucket
    if ! aws s3 ls "s3://${bucket_name}" &> /dev/null; then
        aws s3 mb "s3://${bucket_name}" --region "${REGION}" || true
        aws s3api put-bucket-versioning \
            --bucket "${bucket_name}" \
            --versioning-configuration Status=Enabled || true
        aws s3api put-bucket-encryption \
            --bucket "${bucket_name}" \
            --server-side-encryption-configuration '{
                "Rules": [
                    {
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "AES256"
                        }
                    }
                ]
            }' || true
        log "S3 bucket создан: ${bucket_name}"
    else
        log "S3 bucket уже существует: ${bucket_name}"
    fi

    # Создание DynamoDB таблицы для блокировки
    if ! aws dynamodb describe-table --table-name "${table_name}" &> /dev/null; then
        aws dynamodb create-table \
            --table-name "${table_name}" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
            --region "${REGION}" || true
        log "DynamoDB таблица создана: ${table_name}"
    else
        log "DynamoDB таблица уже существует: ${table_name}"
    fi
}

create_gcp_backend() {
    log "Создание GCP Storage backend..."
    bucket_name="${PROJECT_NAME}-terraform-state"

    if ! gsutil ls "gs://${bucket_name}" &> /dev/null; then
        gsutil mb "gs://${bucket_name}" || log_warning "Bucket уже существует"
        gsutil versioning set on "gs://${bucket_name}" || true
        log "GCS bucket создан: ${bucket_name}"
    else
        log "GCS bucket уже существует: ${bucket_name}"
    fi
}

create_azure_backend() {
    log "Создание Azure Storage backend..."

    # Создание resource group
    az group create --name "${PROJECT_NAME}-terraform" --location "${REGION}" || log "Resource group уже существует"

    # Создание storage account (lowercase and truncated)
    local storage_account_name="${PROJECT_NAME,,}tfstate"
    storage_account_name=${storage_account_name:0:24}  # Azure storage account names must be <= 24 chars
    
    az storage account create \
        --resource-group "${PROJECT_NAME}-terraform" \
        --name "${storage_account_name}" \
        --sku Standard_LRS \
        --encryption-services blob || log "Storage account уже существует"

    # Создание контейнера
    az storage container create \
        --name tfstate \
        --account-name "${storage_account_name}" || log "Container уже существует"
}

# Инициализация Terraform
init_terraform() {
    log "Инициализация Terraform..."

    cd "terraform/environments/${ENVIRONMENT}"

    # Clean up any existing state that might be corrupted
    if [[ -f ".terraform.lock.hcl" ]]; then
        log "Очистка существующих lock файлов..."
        rm -f .terraform.lock.hcl
    fi

    terraform init -reconfigure
    terraform validate
    
    log "Создание плана развертывания..."
    terraform plan -out=plan.tfplan

    log "✅ Terraform план создан успешно"
    log ""
    log "Применить изменения? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log "Применение изменений..."
        terraform apply plan.tfplan
        log "✅ Infrastructure развернута успешно"
    else
        log "Применение пропущено. Вы можете применить изменения позже командой:"
        log "cd platform-services/terraform/environments/${ENVIRONMENT} && terraform apply plan.tfplan"
    fi

    cd - > /dev/null
}

# Настройка kubectl
setup_kubectl() {
    log "Настройка kubectl..."

    case $CLOUD_PROVIDER in
        aws)
            # Try to get cluster names from terraform output
            cd "terraform/environments/${ENVIRONMENT}"
            
            if terraform output base_cluster_info &> /dev/null; then
                base_cluster_name=$(terraform output -json base_cluster_info | jq -r '.cluster_name // empty' 2>/dev/null || echo "")
                if [[ -n "$base_cluster_name" ]]; then
                    aws eks update-kubeconfig \
                        --region "${REGION}" \
                        --name "$base_cluster_name" \
                        --alias base-layer || log_warning "Не удалось обновить kubeconfig для BASE кластера"
                    log "✅ kubectl настроен для BASE кластера: $base_cluster_name"
                fi
            fi
            
            if terraform output platform_cluster_info &> /dev/null; then
                platform_cluster_name=$(terraform output -json platform_cluster_info | jq -r '.cluster_name // empty' 2>/dev/null || echo "")
                if [[ -n "$platform_cluster_name" ]]; then
                    aws eks update-kubeconfig \
                        --region "${REGION}" \
                        --name "$platform_cluster_name" \
                        --alias .platform-services || log_warning "Не удалось обновить kubeconfig для Platform кластера"
                    log "✅ kubectl настроен для Platform кластера: $platform_cluster_name"
                fi
            fi
            
            cd - > /dev/null
            ;;
        gcp)
            gcloud container clusters get-credentials "${CLUSTER_NAME}" \
                --region "${REGION}" || log_warning "Не удалось обновить kubeconfig для GKE"
            ;;
        azure)
            az aks get-credentials \
                --resource-group "${PROJECT_NAME}-terraform" \
                --name "${CLUSTER_NAME}" || log_warning "Не удалось обновить kubeconfig для AKS"
            ;;
        onprem)
            log "On-premises: убедитесь, что kubectl настроен для подключения к кластеру"
            ;;
    esac

    # Проверка подключения
    if kubectl cluster-info &> /dev/null; then
        log "✅ kubectl настроен успешно"
        kubectl get nodes
    else
        log_warning "kubectl не может подключиться к кластеру"
    fi
}

# Установка ArgoCD
install_argocd() {
    log "Установка ArgoCD..."

    # Создание namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

    # Установка ArgoCD через Helm
    helm repo add argo https://argoproj.github.io/argo-helm || true
    helm repo update

    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --version "8.3.0" \
        --set server.service.type=LoadBalancer \
        --set server.extraArgs="{--insecure}" \
        --set controller.replicas=1 \
        --set server.replicas=1 \
        --set repoServer.replicas=1 \
        --set applicationSet.replicas=1 \
        --set redis.enabled=true \
        --wait

    log "ArgoCD установлен"

    # Получение пароля админа
    admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" | base64 -d)

    log "ArgoCD Admin пароль: $admin_password"

    # Ожидание готовности сервиса
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

    # Получение URL сервиса
    service_ip=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    if [[ "$service_ip" != "pending" && -n "$service_ip" ]]; then
        log "ArgoCD URL: http://${service_ip}"
    else
        log "ArgoCD URL: используйте port-forward - kubectl port-forward svc/argocd-server -n argocd 8080:443"
    fi
}

# Установка мониторинга
install_monitoring() {
    log "Установка мониторинга..."

    # Создание namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

    # Установка Prometheus через Helm
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
    helm repo update

    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --version "76.3.0" \
        --set prometheus.service.type=LoadBalancer \
        --set grafana.service.type=LoadBalancer \
        --set prometheus.prometheusSpec.replicas=1 \
        --set alertmanager.alertmanagerSpec.replicas=1 \
        --set grafana.replicas=1 \
        --set prometheus.prometheusSpec.retention=15d \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
        --set prometheus.prometheusSpec.image.tag=v2.50.1 \
        --set grafana.image.tag=10.4.0 \
        --wait

    log "Мониторинг установлен"

    # Получение пароля Grafana
    grafana_password=$(kubectl get secret --namespace monitoring prometheus-grafana \
        -o jsonpath="{.data.admin-password}" | base64 -d)

    log "Grafana Admin пароль: $grafana_password"
}

# Развертывание платформы
deploy_platform() {
    log "Развертывание платформы через ArgoCD..."

    # Check if argocd directory exists
    if [[ -d "argocd/bootstrap" ]]; then
        # Применение ArgoCD приложений
        kubectl apply -f argocd/bootstrap/ -R || log_warning "Не все ArgoCD приложения применены"
    else
        log_warning "ArgoCD bootstrap директория не найдена, пропускаем развертывание платформы"
    fi

    # Ожидание синхронизации ArgoCD
    log "Ожидание синхронизации ArgoCD приложений..."
    sleep 30

    log "Платформа развернута"
}

# Основная функция
main() {
    # Load platform configuration from Stage 1
    load_platform_config
    
    # Load Stage 2 configuration
    load_stage2_config
    
    # Load provider-specific configuration
    case $CLOUD_PROVIDER in
        aws) load_aws_config ;;
    esac
    
    check_dependencies
    validate_cloud_config
    create_cloud_backend
    init_terraform
    setup_kubectl
    install_argocd
    install_monitoring
    deploy_platform
    
    log ""
    log "========================================="
    log "ПЛАТФОРМА УСПЕШНО РАЗВЕРНУТА!"
    log "========================================="
    log ""
    log "Доступ к компонентам:"
    log "======================"
    log "• ArgoCD: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    log "• Grafana: kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80"
    log "• Prometheus: kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090"
    log ""
    log "Полезные команды:"
    log "=================="
    log "• Статус кластера: kubectl get nodes"
    log "• Статус подов: kubectl get pods -A"
    log "• ArgoCD приложения: kubectl get applications -n argocd"
    log ""
    log "AWS информация:"
    log "================"
    log "• AWS Profile: ${AWS_PROFILE:-not set}"
    log "• AWS Region: ${AWS_DEFAULT_REGION:-$REGION}"
    log ""
    log "Развертывание завершено!"
}

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi