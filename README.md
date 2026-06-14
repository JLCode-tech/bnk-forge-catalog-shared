# bnk-forge-catalog-shared

**Upstream library** of the cloud-agnostic Kubernetes primitives that every per-cloud BNK Forge catalog vendors from. Not a deployment catalog.

> If you're an end user trying to deploy BNK on AWS, IBM, Azure, GCP, or on-prem — **you don't register this repo in Forge directly**. Pick a per-cloud catalog (`bnk-forge-catalog-aws-eks`, `bnk-forge-catalog-ibm-roks` from jgruberf5, etc.); it already carries vendored copies of these primitives.

## Who consumes this repo

| Consumer | How |
|---|---|
| **Per-cloud catalog repos** (`bnk-forge-catalog-aws-eks`, future Azure / GCP / on-prem) | Vendor these modules via `scripts/vendor-refresh.sh` at a pinned tag, then rename them on the way in (e.g. `cert-manager` → `eks-cluster-install-cert-manager`). |
| **Catalog maintainers** | Author or update the modules here. Changes propagate to per-cloud catalogs via `notify-downstream.yml` → vendor-refresh PRs. |
| **Direct Forge users** *(unusual)* | Only if you're on bare-metal Kubernetes with no per-cloud blueprint that fits, and you want just the shared primitives. Register as a Module Source pointing at `release/2.x`. |

## What's here

Cloud-agnostic Kubernetes primitives. Anything that touches a cloud API, cloud-specific IAM, or cloud-specific networking does **not** belong here.

| Module | What it does | When you'd use it |
|---|---|---|
| [`modules/bnk-prerequisites`](./modules/bnk-prerequisites) | Creates BNK namespaces, FAR image pull secrets, downloads the BNK manifest, parses component versions. | First step of every BNK install — everything else depends on it. |
| [`modules/cert-manager`](./modules/cert-manager) | Deploys Jetstack cert-manager with BNK-tuned defaults (CRDs, controller/webhook replica counts, OTEL cert pre-wiring). | After bnk-prerequisites, before FLO. FLO certs and OTEL flows need this. |
| [`modules/bnk-cert-issuer`](./modules/bnk-cert-issuer) | Creates the BNK-managed self-signed CA + CA-backed ClusterIssuer + OTEL server certs. Pure-manifest module — no Terraform code. | After cert-manager. Provides the issuer that FLO references. |
| [`modules/install-multus`](./modules/install-multus) | Installs Multus CNI (meta-CNI for multi-interface pods). Pure k8s logic; no cloud bits. | When BNK TMM needs the 3-interface model. Per-cloud catalogs chain a cloud-specific NAD-creation module after this. |
| [`modules/cneinstance-ready-gate`](./modules/cneinstance-ready-gate) | Honest readiness gate for a CNEInstance — polls the operator's `.status` (`F5TmmAvailable && CNEControllerAvailable`, with a `status.state` fallback), dumps pod diagnostics and fails closed on timeout. Pure k8s logic; no cloud bits. | After the per-cloud cneinstall step, to gate downstream work (License, traffic) on the operator actually reporting the instance functional. |
| [`modules/license-activation-gate`](./modules/license-activation-gate) | Server-side-applies the BNK `License` CR (connected mode, JWT inlined safely), then honestly gates on `.status.state == "Active"`; dumps pod diagnostics and fails closed on timeout. Ported from awsbnkctl phase23/phase25. | After the CNEInstance readiness gate. Closes the D-017 licensing-success gap so a deploy fails unless the operator actually activated the license. |

## Branches

`release/2.2`, `release/2.3` (when 2.3 ships), … one per BNK release. `main` tracks the most recent release branch. Per-cloud catalogs pin to a specific branch or tag.

## For maintainers: adding or changing a primitive

Before opening a PR:

- The module must be **cloud-agnostic**. No cloud APIs, no cloud-specific auth, no cloud-specific networking. If it has any of those, it goes in a per-cloud catalog instead.
- Follow [`CATALOG_REPO_CONTRACT.md`](./CATALOG_REPO_CONTRACT.md) for layout, `bnkforge.pack.json` schema, and naming.
- Run `python3 scripts/validate_pack_manifests.py` locally — CI also runs it.

When this repo pushes to `release/*`, `.github/workflows/notify-downstream.yml` fans out a `bnk-forge-modules-released` `repository_dispatch` event to every per-cloud catalog repo. Each downstream's `vendor-refresh.yml` workflow re-runs and opens a refresh PR if its vendored copies have drifted.

## Related repos

| Repo | Role |
|---|---|
| [`bnk-forge-modules`](https://github.com/JLCode-tech/bnk-forge-modules) | Legacy / transitional source. Existing Forge installations still point here. Will gradually shed content as per-cloud catalogs absorb it. |
| [`bnk-forge-catalog-aws-eks`](https://github.com/JLCode-tech/bnk-forge-catalog-aws-eks) | AWS EKS deployment catalog. Vendors from here. |
| [`jgruberf5/bnk-forge-ibm-roks-cluster`](https://github.com/jgruberf5/bnk-forge-ibm-roks-cluster) | IBM ROKS deployment catalog (community-maintained). Does not vendor from here — has its own full stack. |
