#!/bin/bash

# User data script for Karpenter-managed nodes
# This script initializes the node and connects it to the EKS cluster

set -o xtrace

# Configure EKS bootstrap
/etc/eks/bootstrap.sh "${cluster_name}" \
  --apiserver-endpoint "${cluster_endpoint}" \
  --b64-cluster-ca "${cluster_ca}" \
  --container-runtime containerd \
  --kubelet-extra-args "--node-labels=karpenter.sh/provisioner-name=base-data-processing,workload-type=data-processing,managed-by=karpenter"

# Install SSM agent for systems management
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Configure Docker daemon for optimal performance
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF

# Restart containerd
systemctl restart containerd

# Configure kubelet log rotation
cat > /etc/logrotate.d/kubelet << EOF
/var/log/kubelet.log {
    daily
    rotate 5
    copytruncate
    missingok
    notifempty
    compress
    delaycompress
}
EOF

# Set up CloudWatch agent for enhanced monitoring
yum install -y amazon-cloudwatch-agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "diskio": {
        "measurement": [
          "io_time"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Signal that the node is ready
/opt/aws/bin/cfn-signal -e $? --stack ${cluster_name} --resource AutoScalingGroup --region $(curl -s http://169.254.169.254/latest/meta-data/placement/region) || echo "cfn-signal failed"

echo "Node initialization completed successfully"