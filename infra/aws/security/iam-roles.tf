# infrastructure-modules/foundation/security/iam-roles.tf
# All IAM roles needed for current and future modules

# =============================================================================
# EKS CLUSTER SERVICE ROLE
# =============================================================================

resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-eks-cluster-role"
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# =============================================================================
# ENHANCED NODE GROUP ROLE (for all node groups)
# =============================================================================

resource "aws_iam_role" "nodegroup" {
  name = "${var.project_name}-nodegroup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-nodegroup-role"
  })
}

# Standard EKS node group policies
resource "aws_iam_role_policy_attachment" "nodegroup_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])

  policy_arn = each.value
  role       = aws_iam_role.nodegroup.name
}

# Enhanced ENI management policy for high-performance nodes
resource "aws_iam_role_policy" "nodegroup_enhanced_permissions" {
  name = "${var.project_name}-nodegroup-enhanced-policy"
  role = aws_iam_role.nodegroup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:AttachNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DetachNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:CreateTags",
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# JUMPHOST IAM ROLE (full EKS access for cluster admin operations)
# =============================================================================

resource "aws_iam_role" "jumphost_role" {
  name = "${var.project_name}-jumphost-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-jumphost-role"
  })
}

# Full EKS access policy for jumphost (cluster admin capabilities)
resource "aws_iam_role_policy" "jumphost_full_access" {
  name = "${var.project_name}-jumphost-full-access"
  role = aws_iam_role.jumphost_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:*",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeNatGateways",
          "ec2:DescribeRouteTables",
          "ec2:DescribeImages",
          "ec2:DescribeNetworkInterfaces",
          "iam:ListRoles",
          "iam:PassRole",
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })
}

# SSM access for jumphost
resource "aws_iam_role_policy_attachment" "jumphost_ssm_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.jumphost_role.name
}

# Create instance profile for jumphost
resource "aws_iam_instance_profile" "jumphost_profile" {
  name = "${var.project_name}-jumphost-profile"
  role = aws_iam_role.jumphost_role.name

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-jumphost-profile"
  })
}

# =============================================================================
# AUTOMATED OIDC PROVIDER FOR SERVICE ACCOUNT ROLES (IRSA)
# =============================================================================

# Data source for EKS cluster (when it exists)
data "aws_eks_cluster" "cluster" {
  count = var.create_oidc_provider ? 1 : 0
  name  = var.cluster_name
}

# Data source for TLS certificate to get OIDC thumbprint (automated)
data "tls_certificate" "eks_oidc" {
  count = var.create_oidc_provider ? 1 : 0
  url   = data.aws_eks_cluster.cluster[0].identity[0].oidc[0].issuer
}

# IAM OIDC provider for the EKS cluster (fully automated)
resource "aws_iam_openid_connect_provider" "eks" {
  count = var.create_oidc_provider ? 1 : 0

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc[0].certificates[0].sha1_fingerprint]
  url             = data.aws_eks_cluster.cluster[0].identity[0].oidc[0].issuer

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-eks-oidc-provider"
  })
}

# =============================================================================
# EBS CSI DRIVER IAM ROLE
# =============================================================================

resource "aws_iam_role" "ebs_csi_driver" {
  count = var.create_oidc_provider ? 1 : 0
  name  = "${var.project_name}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks[0].arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-ebs-csi-driver-role"
  })
}

# Attach AWS managed policy for EBS CSI driver
resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  count      = var.create_oidc_provider ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver[0].name
}

# =============================================================================
# EFS CSI DRIVER IAM ROLE
# =============================================================================

resource "aws_iam_role" "efs_csi_driver" {
  count = var.create_oidc_provider ? 1 : 0
  name  = "${var.project_name}-efs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks[0].arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:sub" = "system:serviceaccount:kube-system:efs-csi-controller-sa"
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-efs-csi-driver-role"
  })
}

# Attach AWS managed policy for EFS CSI driver
resource "aws_iam_role_policy_attachment" "efs_csi_driver_policy" {
  count      = var.create_oidc_provider ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  role       = aws_iam_role.efs_csi_driver[0].name
}

# =============================================================================
# ENI ATTACHMENT MANAGER IAM ROLE (for high-performance nodes)
# =============================================================================

resource "aws_iam_role" "eni_attachment_manager" {
  count = var.create_oidc_provider ? 1 : 0
  name  = "${var.project_name}-eni-attachment-manager-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks[0].arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:sub" = "system:serviceaccount:kube-system:eni-attachment-manager"
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-eni-attachment-manager-role"
  })
}

# ENI attachment manager policy
resource "aws_iam_role_policy" "eni_attachment_manager_policy" {
  count = var.create_oidc_provider ? 1 : 0
  name  = "${var.project_name}-eni-attachment-manager-policy"
  role  = aws_iam_role.eni_attachment_manager[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:AttachNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DetachNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:CreateTags"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# BEDROCK IRSA ROLE — LiteLLM AI Proxy
# =============================================================================
# Grants LiteLLM pods bedrock:InvokeModel via IRSA so they don't need
# to use the node instance profile. Scoped to the litellm-proxy SA.

resource "aws_iam_role" "bedrock_litellm" {
  count = var.create_oidc_provider && var.enable_bedrock_irsa ? 1 : 0
  name  = "${var.project_name}-bedrock-litellm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks[0].arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:sub" = "system:serviceaccount:${var.litellm_namespace}:${var.litellm_service_account}"
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-bedrock-litellm-role"
  })
}

resource "aws_iam_role_policy" "bedrock_litellm_invoke" {
  count = var.create_oidc_provider && var.enable_bedrock_irsa ? 1 : 0
  name  = "${var.project_name}-bedrock-invoke-policy"
  role  = aws_iam_role.bedrock_litellm[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:ListFoundationModels",
          "bedrock:GetFoundationModel"
        ]
        Resource = "arn:aws:bedrock:*:*:foundation-model/*"
      }
    ]
  })
}

# =============================================================================
# FUTURE F5 BNK SERVICE ACCOUNT ROLES (placeholder structure)
# =============================================================================

# F5 BNK service account role (for future F5 module)
resource "aws_iam_role" "f5_bnk_service_account" {
  count = var.create_oidc_provider && var.enable_f5_bnk_roles ? 1 : 0
  name  = "${var.project_name}-f5-bnk-sa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks[0].arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:sub" = "system:serviceaccount:f5-system:f5-bnk-controller"
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-f5-bnk-sa-role"
  })
}

# F5 BNK custom policy (placeholder for future F5 module requirements)
resource "aws_iam_role_policy" "f5_bnk_custom_policy" {
  count = var.create_oidc_provider && var.enable_f5_bnk_roles ? 1 : 0
  name  = "${var.project_name}-f5-bnk-custom-policy"
  role  = aws_iam_role.f5_bnk_service_account[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeListeners"
        ]
        Resource = "*"
      }
    ]
  })
}