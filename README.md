# FinPortIQ Infrastructure Bootstrap Deployment

A professional web interface for deploying FinPortIQ's enterprise financial analytics infrastructure with automated Kubernetes, ArgoCD, Vault, and monitoring stack setup.

## Features

### Multi-Path Deployment Options

#### 1. Cloud Managed (GCP/AWS/Azure)
- **Complexity**: Low (15-30 minutes)
- **Features**:
  - Automated K8s cluster provisioning
  - Managed databases and storage
  - Auto-scaling and load balancing
  - Cloud-native monitoring
  - SSL certificates via Let's Encrypt
  - DNS management
- **Requirements**:
  - Cloud provider account (GCP/AWS/Azure)
  - Cloud CLI tools installed
  - Billing account with sufficient credits
  - Domain name for ingress

#### 2. On-Premises Infrastructure  
- **Complexity**: High (1-2 hours)
- **Features**:
  - Complete data sovereignty
  - Custom network configuration
  - Integration with existing systems
  - No cloud vendor lock-in
  - Custom security policies
  - Cost predictability
- **Requirements**:
  - Kubernetes cluster (existing or new)
  - Storage provisioner configured
  - Load balancer or ingress controller
  - DNS records management
  - SSL certificate management
  - Monitoring infrastructure

#### 3. Hybrid Cloud Setup
- **Complexity**: High (2-4 hours)  
- **Features**:
  - Data residency compliance
  - Burst to cloud for scaling
  - Multi-region deployment
  - Disaster recovery setup
  - Cross-cloud networking
  - Unified monitoring
- **Requirements**:
  - Both cloud and on-premises access
  - VPN or dedicated connection
  - Multi-cluster management tools
  - Advanced networking knowledge
  - Security policy coordination

## Deployment Flow

1. **Select Deployment Strategy**: Choose between Cloud Managed, On-Premises, or Hybrid
2. **Configure Settings**: Set cluster name, environment, domain, and provider-specific settings
3. **Real-time Monitoring**: Track deployment progress with live step updates
4. **Automated Provisioning**: Complete infrastructure setup with minimal manual intervention

## Components Deployed

- **Kubernetes & ArgoCD**: Enterprise-grade container orchestration with GitOps
- **HashiCorp Vault**: Enterprise secrets management with dynamic credentials
- **Monitoring Stack**: Complete observability with Prometheus, Grafana, and tracing
- **Database Services**: PostgreSQL and Redis with high availability
- **Networking**: Ingress controllers, load balancers, and SSL termination

## Getting Started

### Prerequisites

```bash
# Install Node.js dependencies
npm install

# Set up environment variables
cp .env.example .env.local
```

### Environment Variables

```env
# Database (optional for UI only)
DATABASE_URL=postgresql://...

# Authentication (optional)
AUTH_SECRET=your-secret-key

# Deployment Scripts Path
DEPLOYMENT_SCRIPTS_PATH=../shared-services
```

### Running the Application

```bash
# Development mode
npm run dev

# Production build
npm run build
npm start
```

### Accessing the Interface

1. Navigate to `http://localhost:3000`
2. Select your deployment strategy
3. Configure infrastructure settings
4. Monitor deployment progress in real-time

## API Endpoints

- `POST /api/deploy` - Start infrastructure deployment
- `GET /api/deploy?id={deploymentId}` - Get deployment status and logs

## Integration with Existing Scripts

The interface integrates with existing deployment scripts in `../shared-services/`:

- `deploy-finportiq-cloud.sh` - Cloud managed deployments
- `deploy-finportiq-onprem.sh` - On-premises deployments  
- `deploy-finportiq-hybrid.sh` - Hybrid cloud deployments
- `deploy-finportiq-automated.sh` - Default deployment script

## Architecture

Built with:
- **Next.js 14** - React framework with App Router
- **TypeScript** - Type-safe development
- **Tailwind CSS** - Utility-first styling
- **shadcn/ui** - Professional UI components
- **Lucide React** - Professional icon system

## Security

- No credentials stored in the interface
- Deployment scripts handle authentication
- Real-time log streaming without persistence
- Environment-based configuration isolation

## Support

For deployment issues or questions:
1. Check deployment logs in the interface
2. Review script output in `../shared-services/`
3. Verify prerequisites are met for chosen deployment type