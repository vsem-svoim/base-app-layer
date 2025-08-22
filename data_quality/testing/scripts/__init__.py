"""
Data Quality Testing Scripts

This package contains comprehensive testing scripts for the data_quality module:
- capability_tester.py: Main capability testing framework
- kubernetes-integration-tester.py: Kubernetes deployment testing

The testing framework validates all data quality components including:
- 6 Quality agents (validator, assessor, enforcer, detector, monitor, reporter)  
- 5 ML models (completeness, accuracy, anomaly, quality-scoring, regulatory-compliance)
- 5 Workflows (comprehensive-validation, real-time-assessment, regulatory-compliance, anomaly-investigation, quality-reporting)
- 5 Orchestrators (quality-manager, validation-coordinator, compliance-manager, anomaly-coordinator, reporting-manager)
- 4 Configurations and 6 AI prompts
- Financial data quality specific tests
- Regulatory compliance validation tests
"""

__version__ = "1.0.0"
__author__ = "BASE Platform Data Quality Team"

from .capability_tester import CapabilityTester
from .kubernetes_integration_tester import KubernetesIntegrationTester

__all__ = ["CapabilityTester", "KubernetesIntegrationTester"]