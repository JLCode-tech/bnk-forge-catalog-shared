# examples/basic.hcl
# Minimal standalone example for infra/aws/cne-irsa.
# In BNK-Forge most of these inputs are auto-wired from upstream modules.

terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

# Read existing EKS cluster + OIDC details (assumes infra/aws/eks already
# applied in this account)
data "aws_eks_cluster" "this" {
  name = "aws-syd-test-cluster"
}

data "tls_certificate" "oidc" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "aws_iam_openid_connect_provider" "this" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

module "cne_irsa" {
  source = "../"

  cluster_name             = data.aws_eks_cluster.this.name
  oidc_provider_arn        = data.aws_iam_openid_connect_provider.this.arn
  oidc_provider_url        = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  forge_kubeconfig_content = file("~/.kube/config")

  # Defaults are correct for a vanilla CNEInstance named "bnk-instance" in
  # the f5-operator namespace; override if your CNEInstance has a different name.
  # cne_controller_sa_name = "f5-cne-controller-default-f5-cne-controller-serviceaccount"
}

output "cne_role_arn" {
  value = module.cne_irsa.role_arn
}
