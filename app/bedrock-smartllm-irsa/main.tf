###############################################################################
# app/bedrock-smartllm-irsa — IAM role for Bedrock access via IRSA
#
# Looks up the EKS cluster's OIDC issuer, binds a role to
# system:serviceaccount:<sa_namespace>:<sa_name>, and grants
# bedrock:InvokeModel / Converse on the configured foundation models.
#
# Paired with app/bedrock-smartllm-backend — its ServiceAccount (default
# namespace `default`, name `bedrock-smartllm`) picks up the role ARN
# from this module's output via the blueprint wiring.
###############################################################################

data "aws_eks_cluster" "target" {
  name = var.cluster_name
}

locals {
  # EKS OIDC issuer comes back as https://oidc.eks.<region>.amazonaws.com/id/<id>
  oidc_issuer_url  = data.aws_eks_cluster.target.identity[0].oidc[0].issuer
  oidc_provider_id = replace(local.oidc_issuer_url, "https://", "")
}

# The OIDC provider must already be registered in IAM (it is for EKS clusters
# with any existing IRSA workload). If your cluster has never used IRSA,
# create the provider once with:
#   eksctl utils associate-iam-oidc-provider --cluster <name> --approve
data "aws_iam_openid_connect_provider" "eks" {
  url = local.oidc_issuer_url
}

resource "aws_iam_role" "bedrock" {
  name        = var.role_name
  description = "IRSA for bnk-forge bedrock-smartllm-backend pods (${var.sa_namespace}/${var.sa_name})"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          # StringEquals — NEVER StringLike with a wildcard, that lets
          # any SA in the cluster assume the role.
          StringEquals = {
            "${local.oidc_provider_id}:sub" = "system:serviceaccount:${var.sa_namespace}:${var.sa_name}"
            "${local.oidc_provider_id}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "bedrock_invoke" {
  name = "bedrock-invoke"
  role = aws_iam_role.bedrock.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:Converse",
          "bedrock:ConverseStream",
        ]
        # Double colon `::` is intentional — foundation models are AWS-owned,
        # so the resource ARN has no account ID.
        Resource = [
          for id in var.model_ids :
          "arn:aws:bedrock:*::foundation-model/${id}"
        ]
      }
    ]
  })
}
