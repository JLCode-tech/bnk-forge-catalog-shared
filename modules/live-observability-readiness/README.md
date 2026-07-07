# live-observability-readiness

Cloud-agnostic gate: verify the Loki service is reachable and healthy before marking the BNK live observability stack as available.

## What this module does

Polls Loki's `/ready` endpoint via the **Kubernetes API-server service proxy path**:

```
kubectl get --raw \
  /api/v1/namespaces/<namespace>/services/http:<service>:<port>/proxy/ready
```

Using the API-server proxy means the readiness check works in **private clusters and air-gapped environments** — the Forge runner only needs network access to the Kubernetes API server (which it already has for kubeconfig). No external Loki URL is required.

The probe retries every 5 seconds until Loki returns a `ready` response body or the `readiness_timeout_seconds` limit is hit. Timeout causes the apply to fail, preventing downstream blueprints from starting log emission against a non-functional stack.

## When does Loki become ready?

After `live-observability-loki` applies the Deployment, Loki typically takes 15–30 seconds to:
1. Start the container and mount the ConfigMap.
2. Initialise BoltDB-Shipper storage indexes.
3. Pass its own internal readiness check (exposed on the pod's `/ready` HTTP path).

The default `readiness_timeout_seconds = 120` is conservative and sufficient for cold-start clusters. Reduce it if your cluster has fast image pulls.

## Inputs

| Name | Default | Description |
|---|---|---|
| `observability_namespace` | `llm-egress` | Namespace (auto-wired from `live-observability-namespace`). |
| `loki_service_name` | `loki` | Loki service name (auto-wired from `live-observability-loki`). |
| `loki_port` | `3100` | Loki HTTP port. |
| `readiness_timeout_seconds` | `120` | Polling timeout in seconds. |

## Outputs

| Output | Description |
|---|---|
| `observability_ready` | **Gate output** — `true` when Loki passed /ready. Traffic-producing blueprints depend on this. |
| `loki_proxy_url` | The K8s API-server proxy path used — handy for manual `kubectl get --raw` checks. |

## Destroy behaviour

No-op — this module creates no persistent Kubernetes resources. Destroy removes only the kubeconfig file from the Forge runner's working directory.

## Maturity

`alpha` — new module, part of the `bnk-live-observability-foundation` blueprint (release/2.3).
