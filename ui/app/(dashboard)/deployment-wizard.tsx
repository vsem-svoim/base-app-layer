'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { DeploymentOptions, DeploymentOption } from './deployment-options';
import { 
  CheckCircle, 
  Circle, 
  Play, 
  Server, 
  Cloud, 
  Shield, 
  Database,
  Monitor,
  GitBranch,
  ArrowLeft
} from 'lucide-react';

interface DeploymentStep {
  id: string;
  title: string;
  description: string;
  icon: React.ComponentType<{ className?: string }>;
  status: 'pending' | 'running' | 'completed' | 'error';
}

export function DeploymentWizard() {
  const [currentPhase, setCurrentPhase] = useState<'options' | 'config' | 'deploy'>('options');
  const [selectedOption, setSelectedOption] = useState<DeploymentOption | null>(null);
  const [isDeploying, setIsDeploying] = useState(false);
  const [config, setConfig] = useState({
    clusterName: 'old-f-prod',
    environment: 'production',
    domain: 'old-f.com',
    namespace: 'old-f-system',
    cloudProvider: '',
    region: ''
  });

  const [deploymentSteps, setDeploymentSteps] = useState<DeploymentStep[]>([
    {
      id: 'prerequisites',
      title: 'Prerequisites Check',
      description: 'Verifying Docker, Kubernetes, and Helm',
      icon: CheckCircle,
      status: 'pending'
    },
    {
      id: 'cluster-setup',
      title: 'Kubernetes Cluster',
      description: 'Setting up Kubernetes cluster',
      icon: Cloud,
      status: 'pending'
    },
    {
      id: 'vault-deployment',
      title: 'HashiCorp Vault',
      description: 'Deploying secrets management',
      icon: Shield,
      status: 'pending'
    },
    {
      id: 'database-setup',
      title: 'Database Services',
      description: 'Setting up PostgreSQL and Redis',
      icon: Database,
      status: 'pending'
    },
    {
      id: 'argocd-deployment',
      title: 'ArgoCD GitOps',
      description: 'Installing GitOps deployment',
      icon: GitBranch,
      status: 'pending'
    },
    {
      id: 'monitoring-stack',
      title: 'Monitoring Stack',
      description: 'Deploying Prometheus & Grafana',
      icon: Monitor,
      status: 'pending'
    },
    {
      id: 'finalization',
      title: 'Finalization',
      description: 'Configuring ingress and DNS',
      icon: Server,
      status: 'pending'
    }
  ]);

  const handleStartDeployment = async () => {
    setIsDeploying(true);
    
    try {
      // Start deployment
      const response = await fetch('/api/deploy', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          ...config,
          deploymentType: selectedOption?.id
        }),
      });
      
      if (!response.ok) {
        throw new Error('Failed to start deployment');
      }
      
      const { deploymentId } = await response.json();
      
      // Poll deployment status
      const pollInterval = setInterval(async () => {
        try {
          const statusResponse = await fetch(`/api/deploy?id=${deploymentId}`);
          const deployment = await statusResponse.json();
          
          // Update steps based on logs
          if (deployment.logs) {
            updateStepsFromLogs(deployment.logs);
          }
          
          if (deployment.status === 'completed' || deployment.status === 'error') {
            clearInterval(pollInterval);
            setIsDeploying(false);
          }
        } catch (error) {
          console.error('Error polling deployment status:', error);
        }
      }, 2000);
      
    } catch (error) {
      console.error('Deployment error:', error);
      setIsDeploying(false);
      // Reset steps to error state
      setDeploymentSteps(prev => 
        prev.map(step => ({ ...step, status: 'error' }))
      );
    }
  };
  
  const updateStepsFromLogs = (logs: any[]) => {
    // Simple log parsing to update step status
    const logText = logs.map(log => log.message).join('\n').toLowerCase();
    
    setDeploymentSteps(prev => prev.map(step => {
      if (step.status === 'pending') {
        // Check if step keywords appear in logs
        const stepKeywords = {
          'prerequisites': ['checking prerequisites', 'docker', 'kubectl', 'helm'],
          'cluster-setup': ['kubernetes', 'cluster', 'k8s'],
          'vault-deployment': ['vault', 'secrets'],
          'database-setup': ['postgresql', 'redis', 'database'],
          'argocd-deployment': ['argocd', 'gitops'],
          'monitoring-stack': ['prometheus', 'grafana', 'monitoring'],
          'finalization': ['ingress', 'dns', 'complete']
        };
        
        const keywords = stepKeywords[step.id as keyof typeof stepKeywords] || [];
        if (keywords.some(keyword => logText.includes(keyword))) {
          return { ...step, status: 'running' };
        }
      }
      return step;
    }));
  };

  const handleOptionSelect = (option: DeploymentOption) => {
    setSelectedOption(option);
    setCurrentPhase('config');
  };

  const handleBackToOptions = () => {
    setCurrentPhase('options');
    setSelectedOption(null);
  };

  if (currentPhase === 'options') {
    return <DeploymentOptions onOptionSelect={handleOptionSelect} />;
  }

  return (
    <div className="bg-white rounded-lg shadow-lg p-6 w-full max-w-md">
      <div className="flex items-center mb-4">
        <Button 
          variant="ghost" 
          size="sm" 
          onClick={handleBackToOptions}
          className="mr-2"
        >
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <h3 className="text-lg font-semibold text-gray-900">
          {selectedOption?.title} Setup
        </h3>
      </div>
      
      {!isDeploying ? (
        <div className="space-y-4">
          <div>
            <Label htmlFor="clusterName">Cluster Name</Label>
            <Input
              id="clusterName"
              value={config.clusterName}
              onChange={(e) => setConfig(prev => ({ ...prev, clusterName: e.target.value }))}
              placeholder="finportiq-prod"
            />
          </div>
          
          <div>
            <Label htmlFor="environment">Environment</Label>
            <select 
              id="environment"
              value={config.environment}
              onChange={(e) => setConfig(prev => ({ ...prev, environment: e.target.value }))}
              className="w-full p-2 border border-gray-300 rounded-md"
            >
              <option value="development">Development</option>
              <option value="staging">Staging</option>
              <option value="production">Production</option>
            </select>
          </div>
          
          {selectedOption?.id === 'cloud-managed' && (
            <>
              <div>
                <Label htmlFor="cloudProvider">Cloud Provider</Label>
                <select 
                  id="cloudProvider"
                  value={config.cloudProvider}
                  onChange={(e) => setConfig(prev => ({ ...prev, cloudProvider: e.target.value }))}
                  className="w-full p-2 border border-gray-300 rounded-md"
                >
                  <option value="">Select Provider</option>
                  <option value="gcp">Google Cloud Platform</option>
                  <option value="aws">Amazon Web Services</option>
                  <option value="azure">Microsoft Azure</option>
                </select>
              </div>
              <div>
                <Label htmlFor="region">Region</Label>
                <Input
                  id="region"
                  value={config.region}
                  onChange={(e) => setConfig(prev => ({ ...prev, region: e.target.value }))}
                  placeholder="us-central1-a"
                />
              </div>
            </>
          )}
          
          <div>
            <Label htmlFor="domain">Domain</Label>
            <Input
              id="domain"
              value={config.domain}
              onChange={(e) => setConfig(prev => ({ ...prev, domain: e.target.value }))}
              placeholder="finportiq.com"
            />
          </div>
          
          <Button 
            onClick={handleStartDeployment}
            className="w-full bg-blue-600 hover:bg-blue-700"
            size="lg"
          >
            <Play className="mr-2 h-4 w-4" />
            Start {selectedOption?.title} Deployment
          </Button>
        </div>
      ) : (
        <div className="space-y-3">
          {deploymentSteps.map((step) => {
            const Icon = step.icon;
            return (
              <div 
                key={step.id} 
                className="flex items-center space-x-3 p-3 rounded-lg bg-gray-50"
              >
                <div className="flex-shrink-0">
                  {step.status === 'completed' ? (
                    <CheckCircle className="h-5 w-5 text-green-500" />
                  ) : step.status === 'running' ? (
                    <div className="h-5 w-5 border-2 border-blue-600 border-t-transparent rounded-full animate-spin" />
                  ) : (
                    <Circle className="h-5 w-5 text-gray-400" />
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-gray-900">
                    {step.title}
                  </p>
                  <p className="text-xs text-gray-500">
                    {step.description}
                  </p>
                </div>
                <Icon className="h-4 w-4 text-gray-400" />
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}