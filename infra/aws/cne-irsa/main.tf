# infra/aws/cne-irsa/main.tf
#
# IRSA wiring for the F5 CNE controller — gives its ServiceAccount the AWS
# permissions to call ec2:AssignPrivateIpAddresses and friends, so it can
# attach BNK Gateway VIPs and F5SPKVlan selfips as secondary IPs on the
# dedicated SR-IOV / host-device ENIs.
#
# Required when bnk/cneinstance.tmm_data_plane_mode = "kernel" (the default
# as of 2026-04-23). Without this:
#   - F5SPKVlan CRs status Programmed=True but selfips never appear on AWS
#     ENIs as secondary IPs
#   - BNK Gateway VIPs never become reachable from same-VPC clients (AWS VPC
#     routing has no entry mapping the VIP to the dedicated ENI's MAC)
#
# What this module does:
#   1. Creates the IAM policy `<cluster>-allow-ec2-vip` with the four EC2
#      actions per F5 Doc 3 page 30
#   2. Creates the IAM role `<cluster>-cne-controller-vip` with a trust policy
#      bound to the cluster's IAM OIDC provider and the CNE controller's SA
#   3. Attaches the policy (plus any extra managed policies the user wants)
#   4. Annotates the CNE controller's SA with `eks.amazonaws.com/role-arn`,
#      waiting up to wait_for_sa_timeout_seconds for FLO to create it
#   5. Rollout-restarts the CNE controller deployment so the IRSA mutating
#      webhook injects credentials into a fresh pod

# =============================================================================
# DATA — clean OIDC URL (without https://)
# =============================================================================

locals {
  oidc_host_path        = replace(var.oidc_provider_url, "https://", "")
  effective_role_name   = var.role_name != "" ? var.role_name : "${var.cluster_name}-cne-controller-vip"
  effective_policy_name = var.policy_name != "" ? var.policy_name : "${var.cluster_name}-allow-ec2-vip"

  common_tags = merge(var.tags, {
    "module"  = "infra/aws/cne-irsa"
    "cluster" = var.cluster_name
  })
}

# =============================================================================
# IAM POLICY — allow-ec2-vip (Doc 3 page 30)
# =============================================================================

resource "aws_iam_policy" "allow_ec2_vip" {
  name        = local.effective_policy_name
  description = "Allow F5 CNE controller to attach selfips/VIPs as secondary IPs on dedicated SR-IOV ENIs (BNK kernel-mode TMM)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

# =============================================================================
# IAM ROLE — IRSA trust to the CNE controller SA
# =============================================================================

resource "aws_iam_role" "cne_controller" {
  name        = local.effective_role_name
  description = "IRSA role for F5 CNE controller — assumed by SA ${var.cne_controller_namespace}/${var.cne_controller_sa_name} on cluster ${var.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = var.oidc_provider_arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_host_path}:aud" = "sts.amazonaws.com"
            "${local.oidc_host_path}:sub" = "system:serviceaccount:${var.cne_controller_namespace}:${var.cne_controller_sa_name}"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    "k8s-namespace"      = var.cne_controller_namespace
    "k8s-serviceaccount" = var.cne_controller_sa_name
  })
}

resource "aws_iam_role_policy_attachment" "allow_ec2_vip" {
  role       = aws_iam_role.cne_controller.name
  policy_arn = aws_iam_policy.allow_ec2_vip.arn
}

resource "aws_iam_role_policy_attachment" "extra" {
  for_each   = toset(var.extra_managed_policy_arns)
  role       = aws_iam_role.cne_controller.name
  policy_arn = each.value
}

# =============================================================================
# KUBECONFIG (forge-injected for the kubectl annotate step)
# =============================================================================
# Uses the same pattern as bnk/cneinstance — local.forge_kubeconfig is
# injected by BNK-Forge via bnk_forge_providers.tf at runtime; falls back to
# var.forge_kubeconfig_content for standalone use.

resource "local_file" "kubeconfig" {
  filename        = "${path.module}/work/kubeconfig"
  file_permission = "0600"
  content         = try(local.forge_kubeconfig, var.forge_kubeconfig_content)
}

# =============================================================================
# ANNOTATE SERVICEACCOUNT + RESTART CONTROLLER
# =============================================================================
# The SA is created by FLO once the CNEInstance CR is reconciled. Pass the
# cneinstance module's `instance_ready` output through `var.cneinstance_ready`
# so this step's depends_on tree gates correctly. The kubectl loop also
# tolerates the SA not being there yet (waits up to var.wait_for_sa_timeout_seconds).
#
# After annotation, the EKS pod-identity-webhook injects the AWS_ROLE_ARN +
# AWS_WEB_IDENTITY_TOKEN_FILE env vars on the NEXT pod admission — so we
# must restart the deployment for IRSA to take effect.

locals {
  kubectl = "kubectl --kubeconfig ${local_file.kubeconfig.filename}"
}

resource "null_resource" "annotate_and_restart" {
  triggers = {
    role_arn        = aws_iam_role.cne_controller.arn
    sa              = "${var.cne_controller_namespace}/${var.cne_controller_sa_name}"
    deployment      = "${var.cne_controller_namespace}/${var.cne_controller_deployment_name}"
    cneinstance_ok  = tostring(var.cneinstance_ready)
    kubeconfig_file = local_file.kubeconfig.filename
  }

  depends_on = [
    aws_iam_role_policy_attachment.allow_ec2_vip,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      KUBECTL="${local.kubectl}"
      NS="${var.cne_controller_namespace}"
      SA="${var.cne_controller_sa_name}"
      ROLE_ARN="${aws_iam_role.cne_controller.arn}"
      DEPLOY="${var.cne_controller_deployment_name}"
      TIMEOUT=${var.wait_for_sa_timeout_seconds}

      echo "=== Waiting for ServiceAccount $NS/$SA (max $${TIMEOUT}s) ==="
      ELAPSED=0
      INTERVAL=5
      while [ $ELAPSED -lt $TIMEOUT ]; do
        if $KUBECTL -n "$NS" get sa "$SA" >/dev/null 2>&1; then
          echo "ServiceAccount found after $${ELAPSED}s"
          break
        fi
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
      done

      if ! $KUBECTL -n "$NS" get sa "$SA" >/dev/null 2>&1; then
        echo "ERROR: ServiceAccount $NS/$SA never appeared after $${TIMEOUT}s"
        echo "Is the CNEInstance CR applied and FLO running? Check:"
        echo "  $KUBECTL -n $NS get cneinstance"
        echo "  $KUBECTL -n $NS get pods -l app=flo"
        exit 1
      fi

      echo "=== Annotating $NS/$SA with eks.amazonaws.com/role-arn=$ROLE_ARN ==="
      $KUBECTL -n "$NS" annotate sa "$SA" \
        "eks.amazonaws.com/role-arn=$ROLE_ARN" \
        --overwrite

      if $KUBECTL -n "$NS" get deploy "$DEPLOY" >/dev/null 2>&1; then
        echo "=== Rollout-restarting deploy/$DEPLOY so IRSA env vars are injected ==="
        $KUBECTL -n "$NS" rollout restart "deploy/$DEPLOY"
        $KUBECTL -n "$NS" rollout status "deploy/$DEPLOY" --timeout=300s || \
          echo "WARNING: rollout did not finish within 300s — check pod status manually"
      else
        echo "INFO: deploy/$DEPLOY not found yet — IRSA will take effect on next controller pod creation"
      fi

      echo "=== cne-irsa wiring complete ==="
    EOT
  }

  # Destroy: best-effort un-annotate so a re-deploy without this module
  # doesn't leave the SA pointing at a deleted IAM role
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      kubectl --kubeconfig ${self.triggers.kubeconfig_file} \
        -n ${split("/", self.triggers.sa)[0]} \
        annotate sa ${split("/", self.triggers.sa)[1]} \
        eks.amazonaws.com/role-arn- 2>/dev/null || true
    EOT
  }
}
