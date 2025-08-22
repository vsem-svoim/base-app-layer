# Data Quality Component Testing Framework

## Overview

This comprehensive testing framework validates all data quality components within the BASE platform, ensuring enterprise-grade reliability, performance, and compliance for financial data processing.

## Architecture

The testing framework follows the same patterns as the `data_ingestion` module but is specifically designed for data quality validation:

### Components Tested

#### 🤖 6 Quality Agents
- **Data Validator**: Schema validation, business rules, financial data integrity
- **Quality Assessor**: Multi-dimensional quality scoring and assessment  
- **Rule Enforcer**: Policy enforcement, automatic correction, compliance
- **Anomaly Detector**: Real-time anomaly detection, financial patterns
- **Compliance Monitor**: Continuous regulatory compliance monitoring
- **Quality Reporter**: Automated reporting, dashboards, notifications

#### 🧠 5 ML Models
- **Completeness Prediction Model**: Forecasting data availability and gaps
- **Accuracy Assessment Model**: Predicting and measuring data accuracy
- **Anomaly Detection Model**: ML-powered anomaly identification
- **Quality Scoring Model**: Comprehensive quality assessment
- **Regulatory Compliance Model**: Automated compliance validation

#### 🔄 5 Workflows
- **Comprehensive Validation Workflow**: End-to-end data validation
- **Real-time Assessment Workflow**: Streaming quality assessment
- **Regulatory Compliance Workflow**: Compliance verification processes
- **Anomaly Investigation Workflow**: Automated anomaly analysis
- **Quality Reporting Workflow**: Automated report generation

#### 🎯 5 Orchestrators
- **Quality Manager**: Overall quality process coordination
- **Validation Coordinator**: Validation pipeline orchestration
- **Compliance Manager**: Regulatory compliance coordination
- **Anomaly Coordinator**: Anomaly detection and response
- **Reporting Manager**: Report generation and distribution

#### ⚙️ Configuration & Prompts
- **4 Configuration Templates**: Quality thresholds, compliance frameworks, validation rules, monitoring settings
- **6 AI Prompts**: Quality assessment, anomaly analysis, compliance guidance, validation decisions, reporting intelligence, remediation guidance

## Testing Framework Structure

```
data_quality/testing/
├── scripts/
│   ├── __init__.py                           # Package initialization
│   ├── capability_tester.py                  # Main capability testing
│   └── kubernetes-integration-tester.py      # K8s integration testing
├── config/
│   └── testing-config.yaml                   # Comprehensive test configuration
├── k8s-manifests/
│   ├── testing-configmap.yaml                # Kubernetes configuration
│   ├── testing-cronjob.yaml                  # Automated testing schedule
│   └── testing-dashboard-deployment.yaml     # Testing dashboard
├── web-ui/
│   └── app.py                                # Streamlit testing dashboard
├── requirements.txt                          # Python dependencies
└── quality-testing-README.md                # This documentation
```

## Quick Start

### 1. Install Dependencies

```bash
cd data_quality/testing
pip install -r requirements.txt
```

### 2. Run Capability Tests

```bash
python scripts/capability_tester.py
```

### 3. Run Kubernetes Integration Tests

```bash
python scripts/kubernetes-integration-tester.py
```

### 4. Launch Testing Dashboard

```bash
streamlit run web-ui/app.py --server.port 8080
```

### 5. Deploy in Kubernetes

```bash
# Deploy testing ConfigMap
kubectl apply -f k8s-manifests/testing-configmap.yaml

# Deploy testing dashboard
kubectl apply -f k8s-manifests/testing-dashboard-deployment.yaml

# Deploy automated testing CronJob
kubectl apply -f k8s-manifests/testing-cronjob.yaml
```

## Testing Capabilities

### Comprehensive Agent Testing

Tests all 6 quality agents for:
- **Performance**: Throughput, latency, resource utilization
- **Accuracy**: Validation accuracy, quality assessment precision
- **Financial Specialization**: Market data validation, regulatory compliance
- **Scalability**: Load handling, auto-scaling behavior

```python
# Example agent testing
async def test_data_validator():
    """Test data validator capabilities"""
    results = await tester.test_agent_capabilities()
    assert results['data_validator']['validation_accuracy'] > '99%'
```

### ML Model Validation

Validates ML models for:
- **Prediction Accuracy**: Model performance metrics
- **Inference Speed**: Response time benchmarks  
- **Resource Efficiency**: Memory and CPU usage
- **Financial Domain**: Market data specialization

```python
# Example model testing
async def test_anomaly_detection_model():
    """Test anomaly detection model"""
    model_results = await tester.test_ml_models()
    assert model_results['anomaly_detection_model']['f1_score'] > 0.87
```

### Workflow Execution Testing

Tests end-to-end workflows:
- **Comprehensive Validation**: Large-scale data validation
- **Real-time Assessment**: Streaming quality assessment
- **Regulatory Compliance**: Compliance validation workflows
- **Performance Under Load**: High-volume processing

### Financial Data Quality Testing

Specialized tests for financial data:
- **Market Data Validation**: Price, volume, trade validation
- **Regulatory Compliance**: SOX, FINRA, GDPR compliance
- **Risk Data Quality**: Basel III requirements
- **Audit Trail Generation**: Complete audit logging

## Configuration

### Test Configuration (testing-config.yaml)

```yaml
# Agent testing parameters
agent_tests:
  data_validator:
    test_types:
      - validation_rules_processing
      - schema_validation
      - financial_data_validation
    performance_targets:
      throughput: "50k_records/second"
      accuracy: ">99%"

# ML model testing
ml_model_tests:
  completeness_prediction_model:
    performance_metrics:
      prediction_accuracy: ">94%"
      inference_time: "<50ms"

# Compliance testing
compliance_tests:
  regulatory_compliance:
    frameworks:
      - sox_compliance
      - gdpr_compliance
      - finra_compliance
```

## Performance Benchmarks

### Throughput Targets
- **Data Validation**: 50k+ records/second
- **Quality Assessment**: 25k+ assessments/second  
- **Anomaly Detection**: 92k+ detections/second
- **Compliance Monitoring**: 25k+ checks/second

### Latency Requirements
- **Real-time Assessment**: <200ms end-to-end
- **Anomaly Detection**: <300ms detection time
- **Quality Scoring**: <100ms calculation time
- **Compliance Check**: <1s verification time

### Accuracy Standards
- **Data Validation**: >99% accuracy
- **Quality Assessment**: >96% accuracy
- **Anomaly Detection**: >91% recall, >93% precision
- **Compliance Monitoring**: 100% compliance coverage

## Compliance Testing

### Regulatory Frameworks
- **SOX Compliance**: Financial reporting, internal controls
- **GDPR Compliance**: Privacy protection, consent management
- **FINRA Compliance**: Trading surveillance, market data validation
- **Basel III**: Risk data aggregation and reporting
- **PCI DSS**: Payment data security

### Compliance Validation
```bash
# Run compliance-specific tests
python scripts/capability_tester.py --test-type compliance

# Validate specific framework
python scripts/capability_tester.py --compliance-framework SOX
```

## Kubernetes Integration

### Automated Testing

The framework includes automated daily testing via CronJob:

```yaml
apiVersion: batch/v1
kind: CronJob
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM UTC
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: quality-testing
            image: base-platform/data-quality-testing:latest
            command: ["/testing/scripts/run-comprehensive-tests.sh"]
```

### Monitoring Integration

- **Prometheus Metrics**: Performance and health metrics
- **Grafana Dashboards**: Visual monitoring and alerting  
- **Alert Manager**: Automated alerting on test failures
- **Slack Integration**: Real-time notifications

## Testing Dashboard

### Web Interface Features

1. **Quality Metrics Overview**: Real-time quality scores
2. **Agent Status Dashboard**: Health and performance monitoring
3. **ML Model Performance**: Accuracy and latency metrics
4. **Compliance Status**: Regulatory compliance tracking
5. **Performance Analytics**: Throughput and latency analysis
6. **Financial Data Quality**: Market data specific metrics
7. **Live Testing Interface**: On-demand test execution

### Dashboard Access

```bash
# Local development
streamlit run web-ui/app.py --server.port 8080

# Kubernetes deployment
kubectl port-forward svc/base-data-quality-testing-dashboard 8080:80
```

Access at: `http://localhost:8080`

## Financial Industry Specialization

### Market Data Testing
- **Price Validation**: Tick data accuracy and consistency
- **Volume Verification**: Trading volume validation
- **Market Hours**: Trading session compliance
- **Corporate Actions**: Dividend, split adjustments

### Regulatory Data Testing
- **Trade Reporting**: MiFID II, Dodd-Frank compliance
- **Risk Reporting**: Basel III data quality requirements
- **Audit Requirements**: SOX internal controls testing
- **Privacy Compliance**: GDPR data protection validation

### Example Financial Test
```python
async def test_market_data_quality():
    """Test market data quality validation"""
    test_data = {
        "symbol": "AAPL",
        "price": 150.25,
        "volume": 1000000,
        "timestamp": "2024-01-15T09:30:00Z"
    }
    
    validation_result = await validator.validate_market_data(test_data)
    assert validation_result.is_valid
    assert validation_result.quality_score > 0.99
```

## Troubleshooting

### Common Issues

1. **Test Failures**: Check agent health and connectivity
2. **Performance Issues**: Verify resource allocation
3. **Compliance Failures**: Validate configuration templates
4. **Dashboard Issues**: Check Streamlit dependencies

### Debug Mode

```bash
# Enable debug logging
export LOG_LEVEL=DEBUG
python scripts/capability_tester.py

# Detailed K8s integration testing
python scripts/kubernetes-integration-tester.py --verbose
```

### Health Checks

```bash
# Check agent health
kubectl get pods -n base-data-quality
kubectl logs -f deployment/base-data-quality-agent-data-validator

# Check testing health
kubectl describe cronjob base-data-quality-testing-cronjob
kubectl logs job/base-data-quality-testing-<job-id>
```

## Advanced Usage

### Custom Test Scenarios

```python
# Define custom test scenario
custom_scenario = {
    "name": "high_frequency_trading_validation",
    "parameters": {
        "trade_rate": "100k_trades/second",
        "latency_target": "<1ms",
        "accuracy_requirement": ">99.99%"
    },
    "validation_points": [
        "trade_validation_speed",
        "market_impact_analysis",
        "regulatory_compliance_check"
    ]
}

# Execute custom scenario
result = await tester.execute_custom_scenario(custom_scenario)
```

### Performance Profiling

```bash
# Memory profiling
python -m memory_profiler scripts/capability_tester.py

# CPU profiling  
python -m cProfile -o profile_output scripts/capability_tester.py

# Line-by-line profiling
kernprof -l -v scripts/capability_tester.py
```

### Load Testing

```python
# High-volume load test
load_test_config = {
    "concurrent_users": 1000,
    "requests_per_second": 5000,
    "duration": "30min",
    "test_data_size": "10GB"
}

results = await tester.run_load_test(load_test_config)
```

## Integration with CI/CD

### GitHub Actions

```yaml
name: Data Quality Testing
on:
  push:
    paths:
      - 'data_quality/**'
  schedule:
    - cron: '0 2 * * *'

jobs:
  quality-testing:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
      - name: Install dependencies
        run: |
          cd data_quality/testing
          pip install -r requirements.txt
      - name: Run capability tests
        run: python data_quality/testing/scripts/capability_tester.py
      - name: Upload test results
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: data_quality/testing/results/
```

## Support and Documentation

### Additional Resources
- **Architecture Documentation**: `/docs/data-quality-architecture.md`
- **API Reference**: `/docs/api/data-quality-api.md`
- **Compliance Guide**: `/docs/compliance/regulatory-requirements.md`
- **Performance Tuning**: `/docs/performance/optimization-guide.md`

### Getting Help
- **Issues**: Create GitHub issues for bugs or feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Documentation**: Check `/docs` for detailed guides
- **Support**: Contact the BASE Platform team

## Contributing

### Development Setup
```bash
# Clone repository
git clone <repository-url>
cd base-app-layer/data_quality/testing

# Create virtual environment
python -m venv venv
source venv/bin/activate  # or `venv\Scripts\activate` on Windows

# Install development dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Run tests
python -m pytest tests/
```

### Code Standards
- Follow PEP 8 style guidelines
- Add comprehensive docstrings
- Include type hints
- Write unit tests for new features
- Update documentation for changes

---

## License

This testing framework is part of the BASE Platform and is subject to the same licensing terms as the main platform.

**Data Quality Testing Framework v1.0.0**  
*Enterprise-grade testing for financial data quality validation*