# live-observability-namespace

Cloud-agnostic primitive: create and label the Kubernetes namespace for BNK live observability.

## What this module does

Creates a single Kubernetes namespace (default: `llm-egress`) with standard BNK Forge labels. This namespace hosts all components in the `bnk-live-observability-foundation` blueprint — the Loki log store and the Fluent Bit collector DaemonSet.

The default `llm-egress` matches the `observability_namespace` setting in the Forge AI Gateway configuration (Forge PR #393). Override only if your cluster already uses a different convention or you are running multiple parallel PoC environments.

The create is idempotent: it uses `kubectl create ... --dry-run=client -o yaml | kubectl apply -f -`, so re-applying against a cluster where the namespace already exists is safe.

## Inputs

| Name | Default | Description |
|---|---|---|
| `observability_namespace` | `llm-egress` | Namespace name. Must match the value you configure in Forge AI Gateway settings. |
| `poc_label` | `default` | Value for the `bnk-forge/poc` label — useful for grouping resources across PoC runs. |

## Outputs

| Output | Used by |
|---|---|
| `observability_namespace` | **Wired into** `live-observability-loki`, `live-observability-collector`, `live-observability-readiness` |
| `namespace_ready` | **Gate output** — downstream Loki module depends on this before creating any resources |

## Destroy behaviour

`kubectl delete namespace <name> --ignore-not-found`. Deleting the namespace cascades to all resources inside it (Loki Deployment, Fluent Bit DaemonSet, Services, ConfigMaps). The destroy provisioner runs with `on_failure = continue` so a missing cluster does not block cleanup.

## Maturity

`alpha` — new module, part of the `bnk-live-observability-foundation` blueprint (release/2.3).
