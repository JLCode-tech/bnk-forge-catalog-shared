# Bedrock Smart-LLM Backend

Three single-model Bedrock shim pods behind a BNK Gateway + HTTPRoute, with an `F5BigAnalyzer` CR that drives traffic weights based on Prometheus metrics. Designed for the **EKS + BNK Intelligent AI Load Balancing Demo** blueprint.

## What this deploys

| Resource | Qty | Purpose |
|---|---|---|
| Deployment (shim pod) | 3 | Each proxies exactly one Bedrock model via `bedrock:Converse`. Emits `vllm:*` Prometheus metrics. |
| Service + ServiceMonitor | 3 | One per backend. Metrics port 9100, chat port 8080. |
| ServiceAccount | 1 | Shared IRSA SA with the provided `bedrock_role_arn`. |
| ConfigMap (shim source) | 1 | `app.py` + `requirements.txt`. No custom image — pods pull `python:3.12-slim`, an init container pip-installs deps, the main container runs the ConfigMap-mounted `app.py`. |
| BNK Gateway | 1 | Binds `gateway_vip` on the external VLAN (via `bnk-gatewayclass`). |
| HTTPRoute | 1 | Three weighted backendRefs (starts 33/33/34). Analyzer mutates weights; Terraform ignores drift via `lifecycle.ignore_changes`. |
| F5BigAnalyzer | 1 | Path A — `builtin: LLMLoadMonitor` reading from the supplied Prometheus endpoint. |

## Prerequisites

- EKS cluster with the OIDC provider enabled (required for IRSA)
- BNK deployed: `bnk-gatewayclass` must exist, and an external VLAN must be programmed with an unused IP in its prefix
- `kube-prometheus-stack` (or a compatible Prometheus operator) — the ServiceMonitors this module creates carry the default `release: kube-prometheus-stack` label
- Bedrock **model access granted** in the AWS console for your region — Nova + Claude 3 Haiku availability varies (confirm Sydney / your region before deploying)
- IAM role with Bedrock access (see below)

## Creating the IRSA role (one-time)

The module takes `bedrock_role_arn` as input — you create the role once per cluster + AWS account. Phase 2 (forge auto-provisions this from an AWS Cloud Credential Template) is planned but not yet shipped.

### Terraform snippet

```hcl
data "aws_iam_openid_connect_provider" "eks" {
  url = "https://${local.cluster_oidc_issuer_url_without_scheme}"
}

resource "aws_iam_role" "bedrock_smartllm" {
  name = "bnk-bedrock-smartllm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        # StringEquals — NEVER StringLike + wildcard, that lets any SA assume the role.
        StringEquals = {
          "${local.oidc_provider}:sub" = "system:serviceaccount:default:bedrock-smartllm"
          "${local.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "bedrock_invoke" {
  role = aws_iam_role.bedrock_smartllm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:Converse",
        "bedrock:ConverseStream",
      ]
      # Note the ::  (double colon) — foundation models are AWS-owned, no account ID.
      Resource = [
        "arn:aws:bedrock:*::foundation-model/amazon.nova-micro-v1:0",
        "arn:aws:bedrock:*::foundation-model/amazon.nova-lite-v1:0",
        "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-haiku-20240307-v1:0",
      ]
    }]
  })
}

output "bedrock_role_arn" {
  value = aws_iam_role.bedrock_smartllm.arn
}
```

### eksctl one-liner (alternative)

```bash
eksctl create iamserviceaccount \
  --cluster <CLUSTER_NAME> --region <REGION> \
  --namespace default --name bedrock-smartllm \
  --role-name bnk-bedrock-smartllm \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonBedrockLimitedAccess \
  --approve --override-existing-serviceaccounts
```

> **Heads up**: the `AmazonBedrockLimitedAccess` managed policy is broader than the Terraform snippet above. Tighten in production.

## Common failure modes

| Symptom | Likely cause |
|---|---|
| Pods CrashLoop at init with `Could not find a version that satisfies the requirement …` | Pod can't reach `pypi.org`. Check egress / private-cluster DNS. |
| Bedrock calls return `AccessDeniedException` | IRSA trust policy uses `StringLike` with wildcard, or the `sub` claim doesn't match `system:serviceaccount:<namespace>:bedrock-smartllm`. |
| `ValidationException: The provided model identifier is invalid` | Model not available in `aws_region`. Pre-check model access in the Bedrock console. |
| Prometheus `/api/v1/targets` shows no `bedrock-*` jobs | ServiceMonitor's `release` label doesn't match the operator's `serviceMonitorSelector`. Override `prometheus_release_label`. |
| Gateway `Programmed: False` with "Addresses not assigned" | `gateway_vip` is outside the external VLAN prefix, or is already in use. |

## The architecture in one line

> Three backend Services, one HTTPRoute with three weighted `backendRefs`, an analyzer that weights them with Prometheus signals — something AWS's GenAI Gateway reference arch can't do because it puts model routing inside one LiteLLM pod.

## Frame the demo against Bedrock Intelligent Prompt Routing

Bedrock has a built-in prompt router (GA April 2025) that picks between two models in the same family. This module's value vs that:

- Cross-family routing (Nova + Claude together)
- Prometheus-signal-driven, not prompt-complexity-driven
- F5 data-plane telemetry (observability story)
- HTTPRoute-level policy / rate-limiting / mTLS — things Bedrock's built-in router does not touch

## Outputs

| Output | Purpose |
|---|---|
| `gateway_name`, `gateway_namespace`, `gateway_vip` | Consumed by `app/bedrock-smartllm-client` |
| `httproute_name` | Dashboard reads HTTPRoute weights from here for the "Traffic Distribution" tile |
| `analyzer_name` | Dashboard reads analyzer spec (Monitored Apps, Data Sources, Script Config, Models & Weights) from here |
| `model_service_names` | The three Service names backing the HTTPRoute |
