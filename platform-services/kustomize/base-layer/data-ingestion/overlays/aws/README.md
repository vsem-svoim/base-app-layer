# AWS Интеграции для Data Ingestion

Опциональные интеграции с AWS сервисами для расширенной обработки данных.

## Доступные интеграции

### 1. AWS Bedrock (AI обработка)
**Файл:** `aws-bedrock-integration.yaml`
**Назначение:** Claude 3 Sonnet для интеллектуальной обработки данных

**Включение:**
```bash
kubectl patch configmap bedrock-integration-config -n base-data-ingestion -p '{"data":{"BEDROCK_ENABLED":"true"}}'
```

**Конфигурация:**
- Model ID: `anthropic.claude-3-sonnet-20240229-v1:0`
- Max tokens: 4096
- Temperature: 0.1

### 2. AWS SageMaker (ML модели)
**Файл:** `aws-sagemaker-integration.yaml`
**Назначение:** Развертывание и управление ML моделями

**Включение:**
```bash
kubectl patch configmap sagemaker-integration-config -n base-data-ingestion -p '{"data":{"SAGEMAKER_ENABLED":"true"}}'
```

**Конфигурация:**
- Instance type: `ml.t3.medium`
- Model registry: `data-ingestion-models`

### 3. AWS SageMaker HyperPod (Distributed Training)
**Файл:** `aws-hyperpod-integration.yaml`
**Назначение:** Масштабируемое обучение больших моделей

**Включение:**
```bash
kubectl patch configmap hyperpod-integration-config -n base-data-ingestion -p '{"data":{"HYPERPOD_ENABLED":"true"}}'
```

**Конфигурация:**
- Instance type: `ml.p4d.24xlarge`
- EFA networking: включен
- FSx Lustre: включен

## Требования к инфраструктуре

### Terraform/Crossplane ресурсы
- IAM роли с необходимыми правами
- VPC endpoints для AWS сервисов
- Security groups для ML трафика

### Необходимые права IAM
```json
{
  "bedrock:InvokeModel",
  "sagemaker:CreateEndpoint",
  "sagemaker:InvokeEndpoint",
  "sagemaker:CreateTrainingJob"
}
```

## Использование

Все интеграции **выключены по умолчанию** (`*_ENABLED: "false"`).

Включите только необходимые сервисы для вашего use case.

## Мониторинг

Каждая интеграция создает отдельные метки для мониторинга:
- `integration.type: bedrock`
- `integration.type: sagemaker` 
- `integration.type: hyperpod`