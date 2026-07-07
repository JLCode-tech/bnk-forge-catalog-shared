# bnk-forge-catalog-shared

**Shared cloud-agnostic BNK Forge catalog** for Kubernetes primitives and post-BNK
blueprints that apply across AWS, Azure, GCP, IBM, on-prem, and other Kubernetes
targets.

> If you're an end user trying to create cloud infrastructure or install BNK on
> AWS, IBM, Azure, GCP, or on-prem — start with the matching per-cloud catalog
> (`bnk-forge-catalog-aws-eks`, `bnk-forge-catalog-ibm-roks` from jgruberf5,
> etc.). Use this repo directly for shared Kubernetes-only primitives or
> post-BNK blueprints that are intentionally cloud-agnostic.

## Who consumes this repo

| Consumer | How |
|---|---|
| **Per-cloud catalog repos** (`bnk-forge-catalog-aws-eks`, future Azure / GCP / on-prem) | Vendor these modules via `scripts/vendor-refresh.sh` at a pinned tag, then rename them on the way in (e.g. `cert-manager` → `eks-cluster-install-cert-manager`). |
| **Catalog maintainers** | Author or update shared modules and shared post-BNK blueprints here. Module changes propagate to per-cloud catalogs via `notify-downstream.yml` → vendor-refresh PRs. |
| **Direct Forge users** | Register this repo when you want shared Kubernetes-only modules or cloud-agnostic post-BNK blueprints. Provider-specific cluster creation, BNK installation, and cloud-service demos still belong in per-cloud catalogs. |

## What's here

Cloud-agnostic Kubernetes content. Anything that touches a cloud API,
cloud-specific IAM, cloud-specific networking, or a provider-specific service
(for example AWS Bedrock or Azure OpenAI) does **not** belong here.

## Modules

| Module | What it does | When you'd use it |
|---|---|---|
| [`modules/bnk-prerequisites`](./modules/bnk-prerequisites) | Creates BNK namespaces, FAR image pull secrets, downloads the BNK manifest, parses component versions. | First step of every BNK install — everything else depends on it. |
| [`modules/cert-manager`](./modules/cert-manager) | Deploys Jetstack cert-manager with BNK-tuned defaults (CRDs, controller/webhook replica counts, OTEL cert pre-wiring). | After bnk-prerequisites, before FLO. FLO certs and OTEL flows need this. |
| [`modules/bnk-cert-issuer`](./modules/bnk-cert-issuer) | Creates the BNK-managed self-signed CA + CA-backed ClusterIssuer + OTEL server certs. Pure-manifest module — no Terraform code. | After cert-manager. Provides the issuer that FLO references. |
| [`modules/install-multus`](./modules/install-multus) | Installs Multus CNI (meta-CNI for multi-interface pods). Pure k8s logic; no cloud bits. | When BNK TMM needs the 3-interface model. Per-cloud catalogs chain a cloud-specific NAD-creation module after this. |
| [`modules/live-observability-namespace`](./modules/live-observability-namespace) | Creates and labels the Kubernetes namespace for live observability components (default: `llm-egress`). | First step of the `bnk-live-observability-foundation` blueprint. |
| [`modules/live-observability-loki`](./modules/live-observability-loki) | Deploys single-replica Grafana Loki as plain Kubernetes manifests. No Helm. Service name/port match Forge AI Gateway defaults (`loki:3100`). | After live-observability-namespace. Receives logs from the collector; queried by Forge AI Gateway. |
| [`modules/live-observability-collector`](./modules/live-observability-collector) | Deploys Fluent Bit DaemonSet that tails live pod logs, parses JSON, promotes `model`/`status`/`job` as Loki stream labels, and forwards to Loki. Real log collection — not a generator. | After live-observability-loki. Activated by `enable_pod_log_collection=true` (default). |
| [`modules/live-observability-readiness`](./modules/live-observability-readiness) | Polls Loki `/ready` via the Kubernetes API-server service proxy path. Gate output used by traffic-producing blueprints. | Final step of the `bnk-live-observability-foundation` blueprint. |

## Blueprints

Shared blueprints in this repo are deployable only when they are cloud-agnostic
and useful across Kubernetes targets. They should assume any required cluster or
BNK platform prerequisites already exist unless the blueprint explicitly creates
Kubernetes-only resources.

| Blueprint | What it does | Module chain | When you'd use it |
|---|---|---|---|
| [`blueprints/bnk-live-observability-foundation`](./blueprints/bnk-live-observability-foundation) | Deploys a reusable Loki + Fluent Bit foundation for live BNK PoC telemetry. Defaults match Forge AI Gateway observability settings (`llm-egress/loki:3100`). No synthetic data, no AI provider credentials. | namespace → loki → collector → readiness | After BNK is installed, before deploying traffic-producing PoCs that need shared live observability. |

Provider-specific blueprints stay in their provider catalog. For example, an
AWS Bedrock + LiteLLM traffic demo belongs in `bnk-forge-catalog-aws-eks`; an
Azure OpenAI traffic demo belongs in an Azure catalog.

## Branches

`release/2.2`, `release/2.3` (when 2.3 ships), … one per BNK release. `main` tracks the most recent release branch. Per-cloud catalogs pin to a specific branch or tag.

## For maintainers: adding or changing shared content

Before opening a PR:

- Modules and blueprints must be **cloud-agnostic**. No cloud APIs, no
  cloud-specific auth, no cloud-specific networking, and no provider-specific
  managed services. If it has any of those, it goes in a per-cloud catalog
  instead.
- Follow [`CATALOG_REPO_CONTRACT.md`](./CATALOG_REPO_CONTRACT.md) for layout, `bnkforge.pack.json` schema, and naming.
- Run `python3 scripts/validate_pack_manifests.py` locally — CI also runs it.

When this repo pushes to `release/*`, `.github/workflows/notify-downstream.yml` fans out a `bnk-forge-modules-released` `repository_dispatch` event to every per-cloud catalog repo. Each downstream's `vendor-refresh.yml` workflow re-runs and opens a refresh PR if its vendored copies have drifted.

## Related repos

| Repo | Role |
|---|---|
| [`bnk-forge-modules`](https://github.com/JLCode-tech/bnk-forge-modules) | Legacy / transitional source. Existing Forge installations still point here. Will gradually shed content as per-cloud catalogs absorb it. |
| [`bnk-forge-catalog-aws-eks`](https://github.com/JLCode-tech/bnk-forge-catalog-aws-eks) | AWS EKS deployment catalog. Vendors from here. |
| [`jgruberf5/bnk-forge-ibm-roks-cluster`](https://github.com/jgruberf5/bnk-forge-ibm-roks-cluster) | IBM ROKS deployment catalog (community-maintained). Does not vendor from here — has its own full stack. |
