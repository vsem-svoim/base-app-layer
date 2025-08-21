# ===================================================================
# Crossplane Configuration Module
# ===================================================================

# ===================================================================
# Crossplane Installation via Helm
# ===================================================================
resource "helm_release" "crossplane" {
  count = var.enable_crossplane ? 1 : 0

  name       = "crossplane"
  repository = "https://charts.crossplane.io/stable"
  chart      = "crossplane"
  version    = var.crossplane_version
  namespace  = var.crossplane_namespace
  
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    metrics = {
      enabled = var.enable_metrics
    }
    
    resourcesCrossplane = var.crossplane_resources
    
    webhooks = {
      enabled = true
    }
    
    provider = {
      packages = var.provider_packages
    }
    
    configuration = {
      packages = var.configuration_packages
    }
  })]

  depends_on = [var.cluster_endpoint]
}

# ===================================================================
# Crossplane AWS Provider Configuration
# ===================================================================
resource "kubernetes_manifest" "aws_provider" {
  count = var.enable_crossplane && var.enable_aws_provider ? 1 : 0

  manifest = {
    apiVersion = "pkg.crossplane.io/v1"
    kind       = "Provider"
    metadata = {
      name      = "provider-aws"
      namespace = var.crossplane_namespace
    }
    spec = {
      package                = var.aws_provider_package
      revisionActivationPolicy = "Automatic"
      revisionHistoryLimit     = 5
    }
  }

  depends_on = [helm_release.crossplane]
}

# ===================================================================
# AWS Provider Configuration
# ===================================================================
resource "kubernetes_manifest" "aws_provider_config" {
  count = var.enable_crossplane && var.enable_aws_provider ? 1 : 0

  manifest = {
    apiVersion = "aws.crossplane.io/v1beta1"
    kind       = "ProviderConfig"
    metadata = {
      name = "default"
    }
    spec = {
      credentials = {
        source = var.aws_credentials_source
        secretRef = var.aws_credentials_source == "Secret" ? {
          namespace = var.crossplane_namespace
          name      = var.aws_credentials_secret
          key       = "creds"
        } : null
      }
    }
  }

  depends_on = [kubernetes_manifest.aws_provider]
}

# ===================================================================
# Crossplane CompositeResourceDefinitions (XRDs)
# ===================================================================
resource "kubernetes_manifest" "composition_s3_bucket" {
  count = var.enable_crossplane && var.enable_compositions ? 1 : 0

  manifest = {
    apiVersion = "apiextensions.crossplane.io/v1"
    kind       = "CompositeResourceDefinition"
    metadata = {
      name = "xbuckets.storage.platform.io"
    }
    spec = {
      group = "storage.platform.io"
      names = {
        kind     = "XBucket"
        listKind = "XBucketList"
        plural   = "xbuckets"
        singular = "xbucket"
      }
      versions = [{
        name    = "v1alpha1"
        served  = true
        referenceable = true
        schema = {
          openAPIV3Schema = {
            type = "object"
            properties = {
              spec = {
                type = "object"
                properties = {
                  parameters = {
                    type = "object"
                    properties = {
                      bucketName = {
                        type = "string"
                        description = "Name of the S3 bucket"
                      }
                      region = {
                        type = "string"
                        description = "AWS region for the bucket"
                        default = "us-east-1"
                      }
                      versioning = {
                        type = "boolean"
                        description = "Enable versioning"
                        default = false
                      }
                      encryption = {
                        type = "boolean"
                        description = "Enable encryption"
                        default = true
                      }
                    }
                    required = ["bucketName"]
                  }
                }
                required = ["parameters"]
              }
            }
          }
        }
      }]
    }
  }

  depends_on = [kubernetes_manifest.aws_provider_config]
}

# ===================================================================
# S3 Bucket Composition
# ===================================================================
resource "kubernetes_manifest" "composition_s3_bucket_impl" {
  count = var.enable_crossplane && var.enable_compositions ? 1 : 0

  manifest = {
    apiVersion = "apiextensions.crossplane.io/v1"
    kind       = "Composition"
    metadata = {
      name = "s3-bucket-composition"
      labels = {
        provider = "aws"
        service  = "s3"
      }
    }
    spec = {
      compositeTypeRef = {
        apiVersion = "storage.platform.io/v1alpha1"
        kind       = "XBucket"
      }
      resources = [{
        name = "bucket"
        base = {
          apiVersion = "s3.aws.crossplane.io/v1beta1"
          kind       = "Bucket"
          spec = {
            forProvider = {
              region = ""
              versioning = [{
                enabled = false
              }]
              serverSideEncryptionConfiguration = [{
                rule = [{
                  applyServerSideEncryptionByDefault = [{
                    sseAlgorithm = "AES256"
                  }]
                }]
              }]
            }
          }
        }
        patches = [
          {
            type = "FromCompositeFieldPath"
            fromFieldPath = "spec.parameters.bucketName"
            toFieldPath   = "metadata.name"
          },
          {
            type = "FromCompositeFieldPath"
            fromFieldPath = "spec.parameters.region"
            toFieldPath   = "spec.forProvider.region"
          },
          {
            type = "FromCompositeFieldPath"
            fromFieldPath = "spec.parameters.versioning"
            toFieldPath   = "spec.forProvider.versioning[0].enabled"
          }
        ]
      }]
    }
  }

  depends_on = [kubernetes_manifest.composition_s3_bucket]
}

# ===================================================================
# Crossplane IRSA Role
# ===================================================================
resource "aws_iam_role" "crossplane_role" {
  count = var.enable_crossplane && var.create_irsa_role ? 1 : 0

  name = "${var.cluster_name}-crossplane-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${var.oidc_issuer}:sub" = "system:serviceaccount:${var.crossplane_namespace}:crossplane"
            "${var.oidc_issuer}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-crossplane-role"
    Component   = "crossplane"
    ServiceType = "infrastructure"
  })
}

resource "aws_iam_role_policy_attachment" "crossplane_policy" {
  count = var.enable_crossplane && var.create_irsa_role ? 1 : 0

  role       = aws_iam_role.crossplane_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# ===================================================================
# Crossplane Service Account
# ===================================================================
resource "kubernetes_service_account" "crossplane" {
  count = var.enable_crossplane && var.create_irsa_role ? 1 : 0

  metadata {
    name      = "crossplane"
    namespace = var.crossplane_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.crossplane_role[0].arn
    }
  }

  depends_on = [helm_release.crossplane]
}