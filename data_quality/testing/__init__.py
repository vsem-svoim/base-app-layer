"""
Data Quality Testing Module
===========================

Comprehensive testing framework for the data_quality BASE layer module.

This module provides:
- Capability testing for all 6 quality agents
- Model performance validation for 5 ML models
- Workflow execution testing for 5 quality workflows
- Orchestrator coordination testing for 5 orchestrators
- Configuration validation and integration testing
- Performance benchmarking and load testing
- Financial industry compliance testing
- Regulatory framework validation testing
"""

__version__ = "2.5.0"
__author__ = "BASE Layer Platform Team"
__email__ = "platform@company.com"

from .scripts.capability_tester import QualityCapabilityTester
from .scripts.kubernetes_integration_tester import QualityK8sIntegrationTester

__all__ = [
    "QualityCapabilityTester",
    "QualityK8sIntegrationTester",
]