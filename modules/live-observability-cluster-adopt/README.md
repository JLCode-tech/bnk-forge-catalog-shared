# live-observability-cluster-adopt

Cloud-agnostic cluster adoption step for the `bnk-live-observability-foundation` blueprint.

## What this module does

Accepts a plain-text kubeconfig for **any Kubernetes cluster** (EKS, AKS, GKE, ROKS, on-prem, bare-metal) and validates that the cluster API server is reachable from the Forge runner before downstream modules (namespace, loki, collector, readiness) proceed.

This is the first module in the `bnk-live-observability-foundation` blueprint when deployed via **Forge Blueprint Import** — the path where an imported blueprint creates a new Forge project rather than deploying into an existing registered cluster.

### What it does NOT do

This module does **not** auto-register the cluster in the Forge cluster database. Auto-registration requires either:

- An SSH-fetched kubeconfig (output contract: `cluster_name` + `remote_kubeconfig_path` + `remote_host`) — used by SSH-based adoption modules.
- A cloud-provider-specific register module (e.g. `eks-cluster-register`) — uses cloud APIs to derive the kubeconfig and register the cluster row.

For a directly-provided kubeconfig (this module's approach), **register the cluster manually** via:

> **Forge UI → Settings → Clusters → Add cluster**

Supply the same `cluster_name` you provided to this blueprint. Once registered, the **Forge AI Gateway Loki dashboard (PR #393)** will include this cluster in its cluster-selector and be able to query the Loki instance deployed by this blueprint.

## How kubeconfig flows to downstream modules

The `kubeconfig_content` blueprint input is wired directly to every module's `forge_kubeconfig_content` input in `forge-blueprint.json`. This works because Forge's imported-blueprint flow creates a new project without a registered cluster, so the normal Forge-injected `local.forge_kubeconfig` mechanism is not available. The direct wiring is explicit and reliable.

## Inputs

| Name | Required | Sensitive | Description |
|---|---|---|---|
| `cluster_name` | yes | no | Human-readable cluster name. Used for logging, labels, and manual registration guidance. |
| `kubeconfig_content` | yes | yes | Full plain-text kubeconfig. Written to `work/kubeconfig` at `0600`. Never emitted in plaintext outputs. |

## Outputs

| Output | Sensitive | Description |
|---|---|---|
| `cluster_name` | no | Pass-through of the input cluster name. |
| `cluster_api_server` | no | API server URL extracted from the kubeconfig (for diagnostics and registration). |
| `adopt_ready` | no | Gate — `true` once `kubectl cluster-info` succeeds. Downstream modules depend on this. |

## Manual cluster registration (required for PR #393 dashboard)

After the blueprint deploys successfully:

1. In Forge, go to **Settings → Clusters → Add cluster**.
2. Enter:
   - **Name**: same value as `cluster_name` input
   - **Kubeconfig**: same kubeconfig you provided
3. Save. The cluster row is created in the Forge DB.
4. Open the **Forge AI Gateway → Live Observability** page. The cluster will appear in the selector.
5. Set the Loki endpoint fields to match the blueprint defaults:
   - `observability_namespace`: `llm-egress`
   - `loki_service_name`: `loki`
   - `loki_port`: `3100`

## work/ directory

The module writes `work/kubeconfig` (0600) and `work/api_server.txt` at apply time. This directory is `.gitignore`d. The destroy provisioner removes it.

## Maturity

`alpha` — new module, part of the `bnk-live-observability-foundation` blueprint (release/2.3).
