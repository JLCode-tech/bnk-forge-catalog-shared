# BNK Forge — Shared Cloud-Agnostic Modules

Canonical source for the cloud-agnostic Kubernetes primitives that every per-cloud BNK Forge catalog repo depends on. Per-cloud catalogs (`bnk-forge-catalog-aws-eks`, future `bnk-forge-catalog-azure-aks`, etc.) **vendor** these modules at a pinned `release/2.x` tag — they don't fork them.

This repo follows the [BNK Forge Catalog Repo Contract](./CATALOG_REPO_CONTRACT.md). All `bnk-forge-catalog-*` repos must.

## Modules

| Module path | Purpose |
| --- | --- |
| [`modules/bnk-prerequisites`](./modules/bnk-prerequisites) | Foundation module — creates BNK namespaces, FAR image pull secrets, downloads the BNK manifest, and parses component versions. Everything else in the BNK stack depends on it. |
| [`modules/cert-manager`](./modules/cert-manager) | Deploys Jetstack cert-manager with BNK-compatible defaults (CRDs, controller/webhook replica counts, OTEL telemetry cert flow). |
| [`modules/bnk-cert-issuer`](./modules/bnk-cert-issuer) | Creates the BNK-managed self-signed CA + CA-backed ClusterIssuer used by FLO and OTEL certificate flows. Pure-manifest module rendered by Forge's backend engine. |

These are the only modules that belong in this repo. Anything cloud-specific (FLO install with IAM, CNEInstance with chassis config, NAD with NIC drivers) lives in a per-cloud catalog repo.

## Repo model

This is a **long-lived repo** with **branches per BNK release**:

- `release/2.2` — BNK 2.2 content (current)
- `release/2.3`, `release/2.4`, `release/3.x` — as BNK ships them

`main` tracks the most recent release branch. Customers select which BNK version they consume by pointing Forge's Module Source — or a per-cloud catalog's vendor pin — at the matching branch or tag.

## How per-cloud catalogs consume these modules

Each per-cloud catalog repo carries a copy of these modules under its own `modules/` tree, applied via `scripts/vendor-refresh.sh` and pinned in `VENDORED.pin`. The vendor script:

- Clones this repo at a known ref
- Copies the three modules into the per-cloud repo's `modules/` directory
- Rewrites `module.path` and `dependencies[].module` in each pack JSON to the per-cloud naming (e.g. `modules/eks-cluster-install-cert-manager` for the AWS catalog)
- Records the resolved commit SHA in `VENDORED.pin`

Vendor refreshes are automatic — see [`.github/workflows/notify-downstream.yml`](./.github/workflows/notify-downstream.yml). When this repo pushes to a `release/*` branch, it fans out `bnk-forge-modules-released` dispatch events to each per-cloud catalog repo, which then runs their vendor-refresh workflow and opens a PR if drift is detected.

## Forge compatibility

This repo is intended to be added in Forge as both a **Module Source** and a **Blueprint Source** — Forge auto-links the dual role. Customers who want only the shared primitives (e.g. for an on-prem deployment that doesn't fit a per-cloud blueprint) can register this repo directly.

## Validation

Every PR runs `python3 scripts/validate_pack_manifests.py` via `.github/workflows/validate-catalog.yml`. The validator enforces the v2alpha1 `bnkforge.pack.json` schema against every module. To run locally:

```bash
python3 scripts/validate_pack_manifests.py
```

## Related repos

- [`JLCode-tech/bnk-forge-catalog-aws-eks`](https://github.com/JLCode-tech/bnk-forge-catalog-aws-eks) — AWS EKS catalog
- [`JLCode-tech/bnk-forge-modules`](https://github.com/JLCode-tech/bnk-forge-modules) — legacy/transitional repo; existing Forge installations may still point here. Content mirrors this repo for the shared primitives; per-cloud modules in the legacy repo will retire as customers migrate.
- [`jgruberf5/bnk-forge-ibm-roks-cluster`](https://github.com/jgruberf5/bnk-forge-ibm-roks-cluster) — IBM ROKS catalog (community-maintained reference).

## Contributing

Read [`CATALOG_REPO_CONTRACT.md`](./CATALOG_REPO_CONTRACT.md) before opening a PR. The contract defines layout, naming, schema, and validation requirements for every catalog repo in the `bnk-forge-catalog-*` family.
