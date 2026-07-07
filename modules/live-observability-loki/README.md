# live-observability-loki

Cloud-agnostic primitive: deploy a minimal Grafana Loki log store as plain Kubernetes manifests for BNK live observability.

## What this module does

Deploys a single-replica Grafana Loki instance into the observability namespace. Loki receives structured JSON log streams from the `live-observability-collector` module (Fluent Bit) and exposes an HTTP query API consumed by Forge AI Gateway's ranking and filter features.

**This is plain-manifest Kubernetes — no Helm, no external chart repos.** Image: `grafana/loki:2.9.10` (stable release). Storage: `emptyDir` (data does not survive pod restarts; this is the intended PoC behaviour). Retention: configurable, default 24 h.

### Service naming

The Service is named by the `loki_service_name` input (default: `loki`) and listens on `loki_port` (default: `3100`). These defaults match the Forge AI Gateway `observability_namespace` / `loki_service_name` / `loki_port` settings in PR #393. If you change these, also change the matching Forge AI Gateway settings.

### AI Gateway log contract

Forge AI Gateway pushes logs into Loki with the following LogQL stream selector and labels:

```
{job="llm-gateway", model="<model-name>", status="<2xx|4xx|5xx>"}
```

**Required JSON fields** in each log entry (the payload Forge pushes into the `message` field):

| Field | Type | Description |
|---|---|---|
| `model` | string | Model name (also a Loki label) |
| `status` | string | HTTP status class — `2xx`, `4xx`, `5xx` (also a Loki label) |
| `latency_ms` | number | End-to-end latency in milliseconds |
| `prompt_tk` | number | Input token count |
| `comp_tk` | number | Completion token count |
| `total_tk` | number | Total tokens |
| `cached` | bool | Whether the response was served from cache |
| `cost` | number | Estimated cost (currency unit set by gateway config) |
| `userq` | string | Sanitised user query (may be truncated) |
| `req_body` | string | Raw request body (redacted if sensitive fields present) |
| `resp_body` | string | Raw response body |

`model` and `status` are promoted to **Loki stream labels** in the Fluent Bit collector config. This enables label-indexed filtering and aggregation in LogQL (e.g. `{job="llm-gateway", model="gpt-4o"}`) without scanning all log lines.

**Producer requirement**: every traffic-producing blueprint that writes into this observability foundation MUST emit logs with at minimum `job="llm-gateway"`, `model`, and `status` as JSON top-level fields so the collector can promote them to Loki labels correctly.

## Inputs

| Name | Default | Description |
|---|---|---|
| `observability_namespace` | `llm-egress` | Namespace (auto-wired from `live-observability-namespace`). |
| `loki_service_name` | `loki` | Kubernetes Service name — must match Forge AI Gateway setting. |
| `loki_port` | `3100` | HTTP port — must match Forge AI Gateway setting. |
| `loki_retention_hours` | `24` | How many hours Loki retains chunks and index entries. Use `168` for a 7-day window. |

## Outputs

| Output | Used by |
|---|---|
| `loki_endpoint` | Documentation (full push URL). Downstream modules use `loki_service_name` + `loki_port` directly. |
| `loki_service_name` | `live-observability-collector` (Fluent Bit `Host`), `live-observability-readiness` (K8s proxy path) |
| `loki_port` | `live-observability-collector` (Fluent Bit `Port`), `live-observability-readiness` (K8s proxy path) |
| `loki_namespace` | `live-observability-collector` (constructs in-cluster DNS hostname) |
| `loki_ready` | **Gate output** — `live-observability-collector` depends on this |

## Destroy behaviour

Deletes Deployment, Service, and ConfigMap individually with `--ignore-not-found`. Because storage is `emptyDir`, all log data is already ephemeral — namespace deletion (from `live-observability-namespace` destroy) also removes everything.

## Maturity

`alpha` — new module, part of the `bnk-live-observability-foundation` blueprint (release/2.3).
