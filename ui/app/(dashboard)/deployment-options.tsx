'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { 
  Cloud, 
  Server, 
  ArrowRight,
  Check,
  AlertTriangle,
  Info
} from 'lucide-react';

export interface DeploymentOption {
  id: string;
  title: string;
  description: string;
  icon: React.ComponentType<{ className?: string }>;
  features: string[];
  requirements: string[];
  complexity: 'Low' | 'Medium' | 'High';
  estimatedTime: string;
}

const deploymentOptions: DeploymentOption[] = [
  {
    id: 'cloud-managed',
    title: 'Cloud Deployment (GCP/AWS/Azure)',
    description: 'Deploy on managed cloud infrastructure with automatic scaling and high availability',
    icon: Cloud,
    features: [
      'Managed Kubernetes clusters',
      'Auto-scaling micro-services',
      'Multi-region deployments',
      'Automated backups & recovery',
      'Built-in monitoring dashboards',
      'Load balancing & SSL certificates'
    ],
    requirements: [
      'Cloud provider account (GCP/AWS/Azure)',
      'Cloud CLI tools installed',
      'Billing account with sufficient credits',
      'Domain name for ingress'
    ],
    complexity: 'Low',
    estimatedTime: '20-30 minutes'
  },
  {
    id: 'on-premises',
    title: 'On-Premises Deployment',
    description: 'Deploy on your existing infrastructure with complete data control and security',
    icon: Server,
    features: [
      'Complete data sovereignty',
      'Custom security policies',
      'Legacy system integration', 
      'No external dependencies',
      'Regulatory compliance control',
      'Fixed infrastructure costs'
    ],
    requirements: [
      'Kubernetes cluster (existing or new)',
      'Storage provisioner configured',
      'Load balancer or ingress controller',
      'DNS records management',
      'SSL certificate management',
      'Monitoring infrastructure'
    ],
    complexity: 'High',
    estimatedTime: '1-2 hours'
  },
  {
    id: 'hybrid-cloud',
    title: 'Hybrid Deployment',
    description: 'Combine on-premises control with cloud scalability for optimal flexibility',
    icon: Cloud,
    features: [
      'Data residency compliance',
      'Cloud burst capabilities',
      'Multi-region availability',
      'Disaster recovery automation',
      'Unified monitoring across environments',
      'Cost optimization strategies'
    ],
    requirements: [
      'Both cloud and on-premises access',
      'VPN or dedicated connection',
      'Multi-cluster management tools',
      'Advanced networking knowledge',
      'Security policy coordination'
    ],
    complexity: 'High',
    estimatedTime: '2-4 hours'
  }
];

interface DeploymentOptionsProps {
  onOptionSelect: (option: DeploymentOption) => void;
}

export function DeploymentOptions({ onOptionSelect }: DeploymentOptionsProps) {
  const [selectedOption, setSelectedOption] = useState<string | null>(null);

  const getComplexityColor = (complexity: string) => {
    switch (complexity) {
      case 'Low': return 'text-green-600 bg-green-100';
      case 'Medium': return 'text-yellow-600 bg-yellow-100';
      case 'High': return 'text-red-600 bg-red-100';
      default: return 'text-gray-600 bg-gray-100';
    }
  };

  const getComplexityIcon = (complexity: string) => {
    switch (complexity) {
      case 'Low': return Check;
      case 'Medium': return Info;
      case 'High': return AlertTriangle;
      default: return Info;
    }
  };

  return (
    <div className="max-w-6xl mx-auto px-4 py-8">
      <div className="text-center mb-8">
        <h2 className="text-3xl font-bold text-gray-900 mb-4">
          Choose Your Deployment Environment
        </h2>
        <p className="text-lg text-gray-600 max-w-3xl mx-auto">
          FinPortIQ adapts to your infrastructure needs. Whether you need cloud scalability, 
          on-premises control, or hybrid flexibility - our micro-orchestrated agents work 
          seamlessly across all environments.
        </p>
      </div>

      <div className="grid md:grid-cols-3 gap-6 mb-8">
        {deploymentOptions.map((option) => {
          const Icon = option.icon;
          const ComplexityIcon = getComplexityIcon(option.complexity);
          const isSelected = selectedOption === option.id;
          
          return (
            <Card 
              key={option.id}
              className={`p-6 cursor-pointer transition-all duration-200 hover:shadow-lg ${
                isSelected ? 'ring-2 ring-blue-500 shadow-lg' : ''
              }`}
              onClick={() => setSelectedOption(option.id)}
            >
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center">
                  <div className="p-2 bg-blue-100 rounded-lg mr-3">
                    <Icon className="h-6 w-6 text-blue-600" />
                  </div>
                  <div>
                    <h3 className="font-semibold text-gray-900 text-sm">
                      {option.title}
                    </h3>
                  </div>
                </div>
                <div className={`flex items-center px-2 py-1 rounded-full text-xs font-medium ${getComplexityColor(option.complexity)}`}>
                  <ComplexityIcon className="h-3 w-3 mr-1" />
                  {option.complexity}
                </div>
              </div>

              <p className="text-gray-600 text-sm mb-4">
                {option.description}
              </p>

              <div className="mb-4">
                <p className="font-medium text-gray-900 text-sm mb-2">Key Features:</p>
                <ul className="space-y-1">
                  {option.features.slice(0, 3).map((feature, index) => (
                    <li key={index} className="text-xs text-gray-600 flex items-center">
                      <Check className="h-3 w-3 text-green-500 mr-2 flex-shrink-0" />
                      {feature}
                    </li>
                  ))}
                  {option.features.length > 3 && (
                    <li className="text-xs text-gray-500">
                      +{option.features.length - 3} more features
                    </li>
                  )}
                </ul>
              </div>

              <div className="border-t pt-4">
                <div className="flex justify-between text-xs text-gray-500 mb-2">
                  <span>Estimated Time:</span>
                  <span className="font-medium">{option.estimatedTime}</span>
                </div>
                <div className="text-xs text-gray-500">
                  <span>Requirements: </span>
                  <span>{option.requirements.length} items</span>
                </div>
              </div>
            </Card>
          );
        })}
      </div>

      {selectedOption && (
        <div className="bg-orange-50 rounded-lg p-6 border border-orange-200">
          <div className="flex items-center justify-between">
            <div>
              <h4 className="font-semibold text-gray-900 mb-2">
                Ready to deploy with {deploymentOptions.find(o => o.id === selectedOption)?.title}?
              </h4>
              <p className="text-gray-600 text-sm">
                This will launch the deployment wizard with automated setup for your chosen environment. 
                Our micro-orchestrated agents will handle the infrastructure provisioning.
              </p>
            </div>
            <Button 
              onClick={() => {
                const option = deploymentOptions.find(o => o.id === selectedOption);
                if (option) onOptionSelect(option);
              }}
              className="bg-orange-500 hover:bg-orange-600 text-white"
              size="lg"
            >
              Start Deployment
              <ArrowRight className="ml-2 h-4 w-4" />
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}