# ===================================================================
# Karpenter Node Provisioning Configuration
# ===================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
  }
}

# ===================================================================
# Karpenter IAM Roles and Policies
# ===================================================================

# Karpenter Node Instance Profile
resource "aws_iam_instance_profile" "karpenter_node_instance_profile" {
  name = "${var.cluster_name}-karpenter-node-instance-profile"
  role = aws_iam_role.karpenter_node_instance_role.name

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-karpenter-node-instance-profile"
    Type = "instance-profile"
  })
}

# Karpenter Node IAM Role
resource "aws_iam_role" "karpenter_node_instance_role" {
  name               = "${var.cluster_name}-karpenter-node-instance-role"
  assume_role_policy = data.aws_iam_policy_document.karpenter_node_assume_role_policy.json

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-karpenter-node-instance-role"
    Type = "iam-role"
  })
}

# Assume role policy for Karpenter nodes
data "aws_iam_policy_document" "karpenter_node_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Attach required policies to Karpenter node role
resource "aws_iam_role_policy_attachment" "karpenter_node_policy" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])

  policy_arn = each.value
  role       = aws_iam_role.karpenter_node_instance_role.name
}

# ===================================================================
# Karpenter Namespace
# ===================================================================

resource "kubernetes_namespace" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  metadata {
    name = "karpenter"
    
    labels = {
      "app.kubernetes.io/name" = "karpenter"
    }
  }
}

# ===================================================================
# Karpenter CRDs (Custom Resource Definitions)
# ===================================================================

resource "helm_release" "karpenter_crds" {
  count = var.enable_karpenter ? 1 : 0

  name       = "karpenter-crd"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter-crd"
  version    = var.karpenter_version
  namespace  = "kube-system"
  
  create_namespace = false
  
  depends_on = [
    kubernetes_namespace.karpenter
  ]
}

# ===================================================================
# Karpenter Helm Release
# ===================================================================

resource "helm_release" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_version
  namespace  = kubernetes_namespace.karpenter[0].metadata[0].name

  values = [
    yamlencode({
      # Karpenter controller configuration
      controller = {
        image = {
          repository = "public.ecr.aws/karpenter/karpenter"
          tag        = var.karpenter_version
          digest     = ""
        }
        
        resources = {
          requests = {
            cpu    = "1"
            memory = "1Gi"
          }
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }
      }
      
      # Service account configuration
      serviceAccount = {
        create = true
        name   = "karpenter"
        annotations = {
          "eks.amazonaws.com/role-arn" = var.karpenter_irsa_role_arn
        }
      }
      
      # Settings for Karpenter
      settings = {
        # AWS-specific settings
        aws = {
          clusterName             = var.cluster_name
          clusterEndpoint         = var.cluster_endpoint
          defaultInstanceProfile  = aws_iam_instance_profile.karpenter_node_instance_profile.name
          enablePodENI            = false
          enablePrefixDelegation  = false
          isolatedVPC             = false
          vmMemoryOverheadPercent = 0.075
          interruptionQueue       = "${var.cluster_name}-karpenter"
          nodeClassRef = {
            apiVersion = "karpenter.k8s.aws/v1beta1"
            kind       = "EC2NodeClass"
            name       = "default"
          }
        }
        
        # Feature gates
        featureGates = {
          spotToSpotConsolidation = true
        }
      }
      
      # Webhook configuration
      webhook = {
        enabled = true
        port    = 8443
      }
      
      # Log level
      logLevel = "info"
      
      # Batch settings
      batchMaxDuration = "10s"
      batchIdleDuration = "1s"
    })
  ]

  depends_on = [
    kubernetes_namespace.karpenter,
    helm_release.karpenter_crds
  ]
}

# ===================================================================
# Karpenter NodePool for Base Data Processing
# ===================================================================

resource "kubernetes_manifest" "karpenter_nodepool_data_processing" {
  count = var.enable_karpenter ? 1 : 0

  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    
    metadata = {
      name = "base-data-processing"
    }
    
    spec = {
      # Template for nodes
      template = {
        metadata = {
          labels = {
            "workload-type" = "data-processing"
            "node-type"     = "base-data"
            "cluster-name"  = var.cluster_name
          }
          
          annotations = {
            "karpenter.sh/cluster-name" = var.cluster_name
          }
        }
        
        spec = {
          # Node requirements
          requirements = [
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot", "on-demand"]
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = [
                "m7i.2xlarge", "m7i.4xlarge", "m7i.8xlarge", "m7i.16xlarge",
                "c7i.2xlarge", "c7i.4xlarge", "c7i.8xlarge", "c7i.16xlarge",
                "r7i.2xlarge", "r7i.4xlarge", "r7i.8xlarge", "r7i.16xlarge"
              ]
            }
          ]
          
          # Reference to NodeClass
          nodeClassRef = {
            apiVersion = "karpenter.k8s.aws/v1"
            kind       = "EC2NodeClass"
            name       = "base-data-processing"
          }
          
          # Taints to ensure proper workload placement
          taints = [
            {
              key    = "workload-type"
              value  = "data-processing"
              effect = "NoSchedule"
            }
          ]
          
          # Startup and shutdown taints
          startupTaints = [
            {
              key    = "karpenter.sh/unschedulable"
              value  = "true"
              effect = "NoSchedule"
            }
          ]
        }
      }
      
      # Disruption settings
      disruption = {
        consolidationPolicy = "WhenUnderutilized"
        consolidateAfter    = "15s"
        expireAfter         = "30m"
      }
      
      # Resource limits
      limits = {
        cpu    = "10000"
        memory = "10000Gi"
      }
      
      # Weight for scheduling priority
      weight = 10
    }
  }

  depends_on = [helm_release.karpenter]
}

# ===================================================================
# Karpenter EC2NodeClass for Base Data Processing
# ===================================================================

resource "kubernetes_manifest" "karpenter_nodeclass_data_processing" {
  count = var.enable_karpenter ? 1 : 0

  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    
    metadata = {
      name = "base-data-processing"
    }
    
    spec = {
      # Instance store configuration
      instanceStorePolicy = "NVME"
      
      # AMI configuration
      amiSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]
      
      # Subnet configuration
      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]
      
      # Security group configuration
      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]
      
      # IAM instance profile
      instanceProfile = aws_iam_instance_profile.karpenter_node_instance_profile.name
      
      # User data for node initialization
      userData = base64encode(
        templatefile("${path.module}/templates/userdata.sh.tpl", {
          cluster_name     = var.cluster_name
          cluster_endpoint = var.cluster_endpoint
          cluster_ca       = var.cluster_certificate_authority_data
        })
      )
      
      # Block device mappings
      blockDeviceMappings = [
        {
          deviceName = "/dev/xvda"
          ebs = {
            volumeSize          = 100
            volumeType          = "gp3"
            iops               = 3000
            throughput         = 125
            deleteOnTermination = true
            encrypted          = true
          }
        }
      ]
      
      # Instance metadata options
      metadataOptions = {
        httpEndpoint            = "enabled"
        httpProtocolIPv6        = "disabled"
        httpPutResponseHopLimit = 1
        httpTokens              = "required"
      }
      
      # Tags for instances
      tags = merge(var.common_tags, {
        "karpenter.sh/discovery" = var.cluster_name
        "WorkloadType"           = "data-processing"
        "NodePool"               = "base-data-processing"
        "ManagedBy"              = "karpenter"
      })
    }
  }

  depends_on = [helm_release.karpenter]
}