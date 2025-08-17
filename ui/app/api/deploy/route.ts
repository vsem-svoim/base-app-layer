import { NextRequest, NextResponse } from 'next/server';
import { spawn } from 'child_process';
import path from 'path';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { clusterName, environment, domain, namespace, deploymentType, cloudProvider, region } = body;

    // Validate input
    if (!clusterName || !environment || !domain || !namespace) {
      return NextResponse.json(
        { error: 'Missing required parameters' },
        { status: 400 }
      );
    }

    // Select appropriate deployment script based on type
    let scriptPath: string;
    let scriptArgs: string[] = [];
    
    switch (deploymentType) {
      case 'cloud-managed':
        scriptPath = path.join(process.cwd(), '..', 'shared-services', 'deploy-old-f-cloud.sh');
        scriptArgs = [cloudProvider, region];
        break;
      case 'on-premises':
        scriptPath = path.join(process.cwd(), '..', 'shared-services', 'deploy-old-f-onprem.sh');
        break;
      case 'hybrid-cloud':
        scriptPath = path.join(process.cwd(), '..', 'shared-services', 'deploy-old-f-hybrid.sh');
        scriptArgs = [cloudProvider, region];
        break;
      default:
        scriptPath = path.join(process.cwd(), '..', 'shared-services', 'deploy-old-f-automated.sh');
    }
    
    // Start deployment process
    const deploymentProcess = spawn('bash', [scriptPath, ...scriptArgs], {
      env: {
        ...process.env,
        CLUSTER_NAME: clusterName,
        ENVIRONMENT: environment,
        DOMAIN: domain,
        NAMESPACE: namespace,
      },
      cwd: path.join(process.cwd(), '..'),
    });

    // Stream deployment output
    const deploymentId = Date.now().toString();
    
    // Store deployment status (in production, use proper database)
    (global as any).deployments = (global as any).deployments || {};
    (global as any).deployments[deploymentId] = {
      status: 'running',
      logs: [],
      startTime: new Date(),
      config: { clusterName, environment, domain, namespace }
    };

    deploymentProcess.stdout.on('data', (data) => {
      const log = data.toString();
      (global as any).deployments[deploymentId].logs.push({
        timestamp: new Date(),
        type: 'stdout',
        message: log
      });
    });

    deploymentProcess.stderr.on('data', (data) => {
      const log = data.toString();
      (global as any).deployments[deploymentId].logs.push({
        timestamp: new Date(),
        type: 'stderr',
        message: log
      });
    });

    deploymentProcess.on('close', (code) => {
      (global as any).deployments[deploymentId].status = code === 0 ? 'completed' : 'error';
      (global as any).deployments[deploymentId].endTime = new Date();
      (global as any).deployments[deploymentId].exitCode = code;
    });

    return NextResponse.json({ 
      deploymentId,
      message: 'Deployment started successfully',
      status: 'running'
    });

  } catch (error) {
    console.error('Deployment error:', error);
    return NextResponse.json(
      { error: 'Failed to start deployment' },
      { status: 500 }
    );
  }
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const deploymentId = searchParams.get('id');

  if (!deploymentId) {
    return NextResponse.json(
      { error: 'Deployment ID required' },
      { status: 400 }
    );
  }

  (global as any).deployments = (global as any).deployments || {};
  const deployment = (global as any).deployments[deploymentId];

  if (!deployment) {
    return NextResponse.json(
      { error: 'Deployment not found' },
      { status: 404 }
    );
  }

  return NextResponse.json(deployment);
}