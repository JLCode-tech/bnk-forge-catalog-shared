# Bedrock Smart-LLM IRSA

Creates the IAM role the `app/bedrock-smartllm-backend` pods assume via IRSA to call Amazon Bedrock. Pairs with that module so the whole Smart-LLM demo deploys from one blueprint without a manual AWS Console step.

## What it creates

| Resource | Purpose |
|---|---|
| `aws_iam_role.bedrock` | Role trusted by the EKS cluster's OIDC provider, scoped to **one** Kubernetes ServiceAccount (`<sa_namespace>/<sa_name>`). Trust policy uses `StringEquals` on the `sub` claim — **never** `StringLike` with a wildcard, that would allow any SA in the cluster to assume the role. |
| `aws_iam_role_policy.bedrock_invoke` | Inline policy: `bedrock:InvokeModel`, `InvokeModelWithResponseStream`, `Converse`, `ConverseStream` on the three foundation-model ARNs (by default Nova Micro, Nova Lite, Claude 3 Haiku). |
| (data) `aws_eks_cluster` | Lookup for the cluster's OIDC issuer URL. |
| (data) `aws_iam_openid_connect_provider` | Lookup of the already-registered OIDC provider. |

## Prerequisites

- **AWS credentials** available to forge's OpenTofu engine with permission to create/tag IAM roles and inline policies.
- **EKS cluster** already exists and its OIDC provider is registered in IAM. Any cluster that has previously hosted an IRSA workload has this. For a brand-new cluster that never used IRSA, register the provider once:
  ```bash
  eksctl utils associate-iam-oidc-provider \
    --cluster <cluster_name> --region <region> --approve
  ```
  Then run this module.
- **Bedrock model access granted** in the AWS console for the target region. Nova + Claude 3 Haiku availability varies per region; check before deploying.

## How the ARN wires into the backend

In the `eks-bnk-smartllm-demo` blueprint this module produces `role_arn`, which the backend module consumes as `bedrock_role_arn`. If you're composing a custom blueprint or deploying modules individually, set:

```
app/bedrock-smartllm-backend:
  bedrock_role_arn = <this module's role_arn output>
```

## Inputs

| Name | Type | Default | Required |
|---|---|---|---|
| `cluster_name` | string | — | ✅ |
| `aws_region` | string | `ap-southeast-2` |  |
| `role_name` | string | `bnk-bedrock-smartllm` |  |
| `sa_namespace` | string | `default` |  |
| `sa_name` | string | `bedrock-smartllm` |  |
| `model_ids` | list(string) | 3 default models |  |
| `tags` | map(string) | `{}` |  |

Keep `sa_namespace` + `sa_name` aligned with the backend module's values. The backend module currently uses `default/bedrock-smartllm` — if you override one, override the matching input in the other.

## Outputs

| Name | Purpose |
|---|---|
| `role_arn` | The ARN. Feeds `bedrock_role_arn` on the backend module. |
| `role_name` | Role name (for operations / IAM CLI poking). |
| `oidc_provider_arn` | Debug / audit: the OIDC provider the role trusts. |
| `sa_namespace` / `sa_name` | Namespace and SA the trust policy binds to. |

## Common failure modes

| Symptom | Likely cause |
|---|---|
| `InvalidParameterException: No OpenIDConnect provider found` | Cluster's OIDC provider not registered in IAM. Run `eksctl utils associate-iam-oidc-provider` once. |
| `EntityAlreadyExists: Role with name bnk-bedrock-smartllm already exists` | You already created the role manually. Either delete it, import it into Terraform state, or override `role_name`. |
| Backend pods get `AccessDeniedException` from Bedrock calls | The trust policy's `:sub` claim doesn't match the SA. Check `sa_namespace`/`sa_name` on both modules are identical. |
| `ValidationException: The provided model identifier is invalid` | Model not available in the target region, or model-access not granted. Check Bedrock console → Model access. |

## Narrower permissions?

The default `model_ids` list is a reasonable demo set. For production:
- Narrow to the exact models you use
- Consider service control policies at the org/account level
- Use inference profiles (`us.`-prefixed) if you need cross-region routing — note that needs a 3-ARN policy (profile + regional FM + global `arn:aws:bedrock:::foundation-model/<id>`), which this module doesn't set up today
