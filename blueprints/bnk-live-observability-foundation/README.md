# BNK Live Observability Foundation

A cloud-agnostic, post-BNK shared blueprint that deploys a minimal Loki + Fluent Bit log stack
for **real live telemetry** from BNK PoC workloads. This is the foundation that traffic-producing
blueprints write into — it is not a data generator and does not include LiteLLM, Bedrock, OpenAI,
or any AI provider credentials.

## What this blueprint deploys

```
namespace  ──►  loki  ──►  collector  ──►  readiness
```

| Step | Module | What it creates |
|---|---|---|
| 1 | `live-observability-namespace` | Kubernetes namespace (default: `llm-egress`) with BNK Forge labels |
| 2 | `live-observability-loki` | Single-replica Grafana Loki Deployment + ClusterIP Service (no Helm) |
| 3 | `live-observability-collector` | Fluent Bit DaemonSet with Lua label-promotion filter + Loki output |
| 4 | `live-observability-readiness` | Readiness gate: polls `kubectl get --raw /api/v1/namespaces/.../services/.../proxy/ready` |

## Defaults match Forge AI Gateway (PR #393)

| Parameter | Default | Forge AI Gateway setting |
|---|---|---|
| `observability_namespace` | `llm-egress` | `observability_namespace` |
| `loki_service_name` | `loki` | `loki_service_name` |
| `loki_port` | `3100` | `loki_port` |

**If you change any of these defaults you must update the matching Forge AI Gateway settings** in the project that uses this foundation, and vice-versa. The service name and port must match across both sides.

## Prerequisites

- A running Kubernetes cluster registered in Forge.
- BNK installed on the cluster (required if you intend to use Forge AI Gateway features that query Loki — otherwise the observability stack is standalone).
- No cloud credentials, no cloud-specific prerequisites.

## Inputs

| Name | Default | Description |
|---|---|---|
| `observability_namespace` | `llm-egress` | Namespace for all observability resources. |
| `loki_service_name` | `loki` | Kubernetes Service name for Loki. |
| `loki_port` | `3100` | Loki HTTP port. |
| `loki_retention_hours` | `24` | Retention window in hours. Use `168` for 7 days. |
| `enable_pod_log_collection` | `true` | Deploy Fluent Bit DaemonSet. Set `false` if already have a cluster log collector. |
| `poc_label` | `default` | Value for the `bnk-forge/poc` namespace label. |
| `readiness_timeout_seconds` | `120` | Seconds to wait for Loki /ready. |

## Outputs

| Source module | Output | Description |
|---|---|---|
| `live-observability-namespace` | `observability_namespace` | Namespace name |
| `live-observability-loki` | `loki_endpoint` | In-cluster Loki push URL |
| `live-observability-loki` | `loki_service_name` | Resolved service name |
| `live-observability-readiness` | `observability_ready` | Stack readiness gate |
| `live-observability-readiness` | `loki_proxy_url` | K8s API-server proxy path (diagnostics) |

## AI Gateway log contract

Producer blueprints that emit real logs into this foundation MUST write JSON-structured log lines
with the following fields. Only logs matching this schema will be promoted to Loki stream labels
and be queryable by Forge AI Gateway ranking and filter features.

### Loki stream selector

```logql
{job="llm-gateway"}
```

### Promoted stream labels (indexed, low-cardinality)

| Label | Values | Why a label |
|---|---|---|
| `job` | `llm-gateway` (fixed) | Top-level stream grouping |
| `model` | e.g. `gpt-4o`, `claude-3-5-sonnet` | Label-indexed model filtering and ranking |
| `status` | `2xx`, `4xx`, `5xx` | Label-indexed error rate queries |

### Full JSON field contract

```json
{
  "job":       "llm-gateway",
  "model":     "<model-name>",
  "status":    "<2xx|4xx|5xx>",
  "latency_ms": 342,
  "prompt_tk":  120,
  "comp_tk":    85,
  "total_tk":   205,
  "cached":     false,
  "cost":       0.0041,
  "userq":      "What is the capital of France?",
  "req_body":   "{...}",
  "resp_body":  "{...}"
}
```

`model` and `status` are promoted to Loki **stream labels** by the Fluent Bit Lua filter.
Queries on stream labels use the Loki index and are fast regardless of data volume. Do NOT
set `model` to a per-request unique value (e.g. a UUID) — that explodes label cardinality
and degrades Loki performance.

### Reference LogQL queries

```logql
# Error rate by model (5-minute window)
sum by (model) (rate({job="llm-gateway", status="5xx"}[5m]))

# P95 latency by model
quantile_over_time(0.95,
  {job="llm-gateway"} | json | unwrap latency_ms [10m]
) by (model)

# Token cost per model per hour
sum by (model) (
  sum_over_time({job="llm-gateway"} | json | unwrap cost [1h])
)

# Cache hit rate
sum(rate({job="llm-gateway"} | json | cached=`true` [5m]))
  /
sum(rate({job="llm-gateway"}[5m]))
```

## Storage note

Loki uses `emptyDir` storage — **log data does not survive pod restarts**. This is intentional
for PoC environments to keep the blueprint stateless and cluster-portable. For production or
longer-lived deployments, replace the `emptyDir` volume with a PersistentVolumeClaim backed by
an appropriate StorageClass and increase `loki_retention_hours` accordingly.

## How traffic-producing blueprints integrate

A traffic-producing blueprint (e.g. `bnk-ai-gateway-litellm-aws` in `bnk-forge-catalog-aws-eks`)
should:

1. List `bnk-live-observability-foundation` as a **prerequisite blueprint** in its `forge-blueprint.json`.
2. Accept `observability_namespace`, `loki_service_name`, and `loki_port` as inputs (pass-through from the foundation).
3. Configure its AI Gateway or proxy to emit logs in the JSON format above to stdout/stderr, where Fluent Bit picks them up automatically.
4. Optionally, configure the AI Gateway to push directly to Loki at
   `http://<loki_service_name>.<observability_namespace>.svc.cluster.local:<loki_port>/loki/api/v1/push`
   in addition to or instead of stdout.

## Maturity

`preview` — new blueprint (release/2.3). The module chain has been validated against the
`bnkforge.pack.json` schema. End-to-end cluster testing is the next step before `beta`.
