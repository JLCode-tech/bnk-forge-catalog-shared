# live-observability-collector

Cloud-agnostic primitive: deploy a Fluent Bit DaemonSet that collects live pod logs, parses JSON records, promotes Loki labels, and forwards to the Loki push API.

## What this module does

Deploys [Fluent Bit](https://fluentbit.io/) as a DaemonSet that runs on every node in the cluster. Fluent Bit tails all container logs from `/var/log/containers/*.log`, enriches them with Kubernetes pod/namespace metadata, and forwards records to the Loki instance deployed by `live-observability-loki`.

**This is real live log collection — not a data generator.** Loki will only contain data if actual workloads in the cluster emit JSON-structured logs that match the producer contract below.

## Label promotion: how model/status become Loki stream labels

Fluent Bit uses a Lua filter to inspect each JSON log record and extract `job`, `model`, and `status` fields. The Loki output plugin then promotes those three fields to **Loki stream labels**:

```
{job="llm-gateway", model="gpt-4o", status="2xx"}
```

Stream labels are indexed by Loki — queries on them are fast regardless of volume. Without label promotion, every query would require scanning all log lines.

### Caveat: label cardinality

Loki performs best when label values have **low cardinality** (a small, bounded set of values). `model` and `status` satisfy this for AI Gateway use cases:

- `model`: typically 5–20 distinct values across a PoC (`gpt-4o`, `claude-3-5-sonnet`, `mistral-7b`, etc.)
- `status`: 3 values — `2xx`, `4xx`, `5xx`
- `job`: 1 value — `llm-gateway`

If producers set `model` to a value that changes per-request (e.g. a unique request ID), label cardinality explodes and Loki performance degrades. Enforce the contract at the producer level.

## Producer contract

Every traffic-producing blueprint that writes into this observability foundation **MUST** emit log lines in this exact JSON shape (one JSON object per log line):

```json
{
  "job": "llm-gateway",
  "model": "<model-name>",
  "status": "<2xx|4xx|5xx>",
  "latency_ms": 342,
  "prompt_tk": 120,
  "comp_tk": 85,
  "total_tk": 205,
  "cached": false,
  "cost": 0.0041,
  "userq": "What is the capital of France?",
  "req_body": "{...}",
  "resp_body": "{...}"
}
```

**Minimum required fields** for label promotion: `job`, `model`, `status`.

The remaining fields (`latency_ms`, `prompt_tk`, `comp_tk`, `total_tk`, `cached`, `cost`, `userq`, `req_body`, `resp_body`) are stored in the log body for query/aggregation but are not promoted to stream labels.

## LogQL reference queries

```logql
# All AI Gateway requests
{job="llm-gateway"}

# Requests to a specific model
{job="llm-gateway", model="gpt-4o"}

# 5xx errors with latency
{job="llm-gateway", status="5xx"} | json | line_format "{{.latency_ms}}ms"
```

## Inputs

| Name | Default | Description |
|---|---|---|
| `observability_namespace` | `llm-egress` | Namespace (auto-wired from `live-observability-namespace`). |
| `loki_service_name` | `loki` | Loki Service name — used as Fluent Bit Loki output `Host` component (auto-wired from `live-observability-loki`). |
| `loki_port` | `3100` | Loki HTTP port — used as Fluent Bit Loki output `Port` (auto-wired from `live-observability-loki`). |
| `enable_pod_log_collection` | `true` | Set false to skip DaemonSet deployment. |
| `fluent_bit_version` | `3.1.9` | Fluent Bit image tag. |

## Outputs

| Output | Used by |
|---|---|
| `collector_installed` | Diagnostics |
| `collector_ready` | **Gate output** — `live-observability-readiness` depends on this |

## RBAC

Creates a `ClusterRole` named `fluent-bit-bnk-obs` with read/list/watch on `pods` and `namespaces`. This is the minimum required for Fluent Bit's Kubernetes filter enrichment. The `ClusterRoleBinding` binds to the `fluent-bit` ServiceAccount in the observability namespace.

## Destroy behaviour

Deletes the Fluent Bit DaemonSet and ConfigMap with `--ignore-not-found`. The ClusterRole and ClusterRoleBinding are also removed via RBAC YAML delete. Namespace deletion (from `live-observability-namespace` destroy) removes any remaining namespace-scoped resources.

## Maturity

`alpha` — new module, part of the `bnk-live-observability-foundation` blueprint (release/2.3).
