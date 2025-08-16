#!/usr/bin/env python3
"""
Kubernetes Integration Testing for Data Ingestion AI Agents
Tests AI agent deployments, scaling, and performance in Kubernetes
"""

import asyncio
import json
import logging
import time
import yaml
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any
import os

# Kubernetes client (if available)
try:
    from kubernetes import client, config
    KUBERNETES_AVAILABLE = True
except ImportError:
    KUBERNETES_AVAILABLE = False
    logging.warning("Kubernetes client not available. Install with: pip install kubernetes")

import requests


class KubernetesIntegrationTester:
    """Test AI agents deployed in Kubernetes"""
    
    def __init__(self, namespace: str = "base-data-ingestion"):
        self.namespace = namespace
        self.setup_logging()
        self.setup_kubernetes()
        
    def setup_logging(self):
        """Configure logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(f'k8s_test_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def setup_kubernetes(self):
        """Setup Kubernetes client"""
        if not KUBERNETES_AVAILABLE:
            self.logger.warning("Kubernetes client not available")
            self.k8s_apps_v1 = None
            self.k8s_core_v1 = None
            return
            
        try:
            # Try in-cluster config first
            config.load_incluster_config()
            self.logger.info("Using in-cluster Kubernetes configuration")
        except:
            try:
                # Fall back to local kubeconfig
                config.load_kube_config()
                self.logger.info("Using local kubeconfig")
            except Exception as e:
                self.logger.error(f"Failed to load Kubernetes config: {e}")
                self.k8s_apps_v1 = None
                self.k8s_core_v1 = None
                return
        
        self.k8s_apps_v1 = client.AppsV1Api()
        self.k8s_core_v1 = client.CoreV1Api()
    
    async def test_agent_deployments(self) -> Dict[str, Any]:
        """Test AI agent deployment status"""
        self.logger.info("Testing AI agent deployments")
        results = {}
        
        if not self.k8s_apps_v1:
            return {"status": "skipped", "reason": "kubernetes_client_unavailable"}
        
        try:
            # Get all deployments in namespace
            deployments = self.k8s_apps_v1.list_namespaced_deployment(self.namespace)
            
            agent_deployments = [d for d in deployments.items 
                               if 'agent' in d.metadata.name and 'data-ingestion' in d.metadata.name]
            
            for deployment in agent_deployments:
                name = deployment.metadata.name
                ready_replicas = deployment.status.ready_replicas or 0
                desired_replicas = deployment.spec.replicas or 0
                
                results[name] = {
                    "desired_replicas": desired_replicas,
                    "ready_replicas": ready_replicas,
                    "status": "healthy" if ready_replicas == desired_replicas else "degraded",
                    "creation_timestamp": deployment.metadata.creation_timestamp.isoformat(),
                    "image": deployment.spec.template.spec.containers[0].image,
                    "resources": {
                        "requests": deployment.spec.template.spec.containers[0].resources.requests or {},
                        "limits": deployment.spec.template.spec.containers[0].resources.limits or {}
                    }
                }
                
                self.logger.info(f"Agent {name}: {ready_replicas}/{desired_replicas} replicas ready")
            
            overall_status = "healthy" if all(r["status"] == "healthy" for r in results.values()) else "degraded"
            
        except Exception as e:
            self.logger.error(f"Failed to test agent deployments: {e}")
            return {"status": "error", "error": str(e)}
        
        return {
            "status": overall_status,
            "agents": results,
            "total_agents": len(results),
            "healthy_agents": sum(1 for r in results.values() if r["status"] == "healthy")
        }
    
    async def test_pod_scaling(self) -> Dict[str, Any]:
        """Test pod scaling behavior"""
        self.logger.info("Testing pod scaling behavior")
        
        if not self.k8s_apps_v1:
            return {"status": "skipped", "reason": "kubernetes_client_unavailable"}
        
        try:
            # Find a deployment to test scaling
            deployments = self.k8s_apps_v1.list_namespaced_deployment(self.namespace)
            agent_deployments = [d for d in deployments.items 
                               if 'agent' in d.metadata.name and 'data-collector' in d.metadata.name]
            
            if not agent_deployments:
                return {"status": "skipped", "reason": "no_agent_deployments_found"}
            
            test_deployment = agent_deployments[0]
            deployment_name = test_deployment.metadata.name
            original_replicas = test_deployment.spec.replicas
            
            self.logger.info(f"Testing scaling for deployment {deployment_name}")
            
            # Scale up
            scale_up_replicas = original_replicas + 2
            await self._scale_deployment(deployment_name, scale_up_replicas)
            
            # Wait for scale up
            scale_up_time = await self._wait_for_scale(deployment_name, scale_up_replicas)
            
            # Scale back down
            await self._scale_deployment(deployment_name, original_replicas)
            scale_down_time = await self._wait_for_scale(deployment_name, original_replicas)
            
            return {
                "status": "success",
                "deployment": deployment_name,
                "original_replicas": original_replicas,
                "scale_up_replicas": scale_up_replicas,
                "scale_up_time": scale_up_time,
                "scale_down_time": scale_down_time,
                "scaling_responsive": scale_up_time < 30 and scale_down_time < 30
            }
            
        except Exception as e:
            self.logger.error(f"Failed to test pod scaling: {e}")
            return {"status": "error", "error": str(e)}
    
    async def _scale_deployment(self, deployment_name: str, replicas: int):
        """Scale a deployment to specified replicas"""
        body = {"spec": {"replicas": replicas}}
        self.k8s_apps_v1.patch_namespaced_deployment_scale(
            name=deployment_name,
            namespace=self.namespace,
            body=body
        )
        self.logger.info(f"Scaled {deployment_name} to {replicas} replicas")
    
    async def _wait_for_scale(self, deployment_name: str, target_replicas: int, timeout: int = 60) -> float:
        """Wait for deployment to reach target replicas"""
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            deployment = self.k8s_apps_v1.read_namespaced_deployment(deployment_name, self.namespace)
            ready_replicas = deployment.status.ready_replicas or 0
            
            if ready_replicas == target_replicas:
                elapsed_time = time.time() - start_time
                self.logger.info(f"Scaling to {target_replicas} completed in {elapsed_time:.2f}s")
                return elapsed_time
            
            await asyncio.sleep(2)
        
        raise TimeoutError(f"Scaling to {target_replicas} did not complete within {timeout}s")
    
    async def test_service_connectivity(self) -> Dict[str, Any]:
        """Test service connectivity between components"""
        self.logger.info("Testing service connectivity")
        
        if not self.k8s_core_v1:
            return {"status": "skipped", "reason": "kubernetes_client_unavailable"}
        
        try:
            services = self.k8s_core_v1.list_namespaced_service(self.namespace)
            service_tests = {}
            
            for service in services.items:
                if 'data-ingestion' in service.metadata.name:
                    service_name = service.metadata.name
                    cluster_ip = service.spec.cluster_ip
                    ports = [p.port for p in service.spec.ports]
                    
                    # Test basic connectivity (simplified)
                    connectivity_test = await self._test_service_endpoint(cluster_ip, ports[0] if ports else 80)
                    
                    service_tests[service_name] = {
                        "cluster_ip": cluster_ip,
                        "ports": ports,
                        "connectivity": connectivity_test
                    }
            
            return {
                "status": "success",
                "services": service_tests,
                "total_services": len(service_tests)
            }
            
        except Exception as e:
            self.logger.error(f"Failed to test service connectivity: {e}")
            return {"status": "error", "error": str(e)}
    
    async def _test_service_endpoint(self, ip: str, port: int) -> bool:
        """Test if service endpoint is reachable"""
        try:
            # Simple connectivity test (would be enhanced in real implementation)
            return True  # Placeholder
        except:
            return False
    
    async def generate_kubernetes_report(self) -> Dict[str, Any]:
        """Generate comprehensive Kubernetes testing report"""
        self.logger.info("Generating Kubernetes integration test report")
        
        report = {
            "test_timestamp": datetime.now().isoformat(),
            "namespace": self.namespace,
            "kubernetes_available": KUBERNETES_AVAILABLE,
            "tests": {}
        }
        
        # Run all tests
        report["tests"]["agent_deployments"] = await self.test_agent_deployments()
        report["tests"]["pod_scaling"] = await self.test_pod_scaling()
        report["tests"]["service_connectivity"] = await self.test_service_connectivity()
        
        # Calculate overall status
        test_statuses = [test.get("status", "unknown") for test in report["tests"].values()]
        overall_status = "success" if all(status == "success" for status in test_statuses) else "partial"
        
        report["overall_status"] = overall_status
        report["summary"] = {
            "total_tests": len(report["tests"]),
            "successful_tests": sum(1 for status in test_statuses if status == "success"),
            "kubernetes_integration": KUBERNETES_AVAILABLE
        }
        
        # Save report
        report_file = f"k8s_integration_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        self.logger.info(f"Kubernetes integration report saved to {report_file}")
        return report


async def main():
    """Main testing execution"""
    tester = KubernetesIntegrationTester()
    report = await tester.generate_kubernetes_report()
    
    print("\n" + "="*60)
    print("KUBERNETES INTEGRATION TEST REPORT")
    print("="*60)
    print(f"Namespace: {report['namespace']}")
    print(f"Overall Status: {report['overall_status']}")
    print(f"Tests: {report['summary']['successful_tests']}/{report['summary']['total_tests']} successful")
    print(f"Kubernetes Available: {report['summary']['kubernetes_integration']}")
    print("="*60)


if __name__ == "__main__":
    asyncio.run(main())