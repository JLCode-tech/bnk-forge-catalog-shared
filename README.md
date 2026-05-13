# bnk-forge-catalog-shared

**Upstream library** of the cloud-agnostic Kubernetes primitives that per-cloud BNK Forge catalog repos vendor from. Not a deployment catalog.

> `main` is a **landing page**. The real content lives on the `release/X.Y` branches. Pick the branch matching the BNK release you're targeting.

## Are you in the right place?

| Goal | Where to go |
|---|---|
| Deploy BNK on **AWS EKS** via Forge | [`bnk-forge-catalog-aws-eks`](https://github.com/JLCode-tech/bnk-forge-catalog-aws-eks) |
| Deploy BNK on **IBM ROKS** via Forge | [`jgruberf5/bnk-forge-ibm-roks-cluster`](https://github.com/jgruberf5/bnk-forge-ibm-roks-cluster) |
| Deploy BNK on **Azure / GCP / on-prem** | Planned per-cloud catalogs — not started yet |
| Existing Forge installation already pointing at `bnk-forge-modules` | [`bnk-forge-modules`](https://github.com/JLCode-tech/bnk-forge-modules) — keep using it; no migration needed |
| **You're a per-cloud catalog maintainer** and need to vendor from here | Stay on this page — keep reading |
| **You're adding a new shared cloud-agnostic primitive** | Stay on this page — keep reading |

## What this repo holds

Exactly **three** modules. Cloud-agnostic Kubernetes primitives. Anything that touches a cloud API, cloud-specific IAM, or cloud-specific networking goes in a per-cloud catalog, not here.

- `bnk-prerequisites` — namespaces, FAR pull secrets, BNK manifest download, version parsing
- `cert-manager` — Jetstack Helm install with BNK-tuned defaults
- `bnk-cert-issuer` — BNK-managed self-signed CA + ClusterIssuer + OTEL certs (pure manifest)

Full module details live on `release/2.2` — see [the release-branch README](https://github.com/JLCode-tech/bnk-forge-catalog-shared/blob/release/2.2/README.md) and [`CATALOG_REPO_CONTRACT.md`](https://github.com/JLCode-tech/bnk-forge-catalog-shared/blob/release/2.2/CATALOG_REPO_CONTRACT.md).

## Release branches

| Branch | F5 BNK version | Status |
|---|---|---|
| [`release/2.2`](https://github.com/JLCode-tech/bnk-forge-catalog-shared/tree/release/2.2) | BNK 2.2 GA | Active |
| `release/2.3` | BNK 2.3 (when GA) | Not yet open |

Past releases are kept on their `release/X.Y` branches indefinitely.

## How per-cloud catalogs consume this

Each per-cloud catalog carries vendored copies of these three modules under its own `modules/` directory, applied via its `scripts/vendor-refresh.sh` and pinned in `VENDORED.pin`. When this repo pushes to a `release/*` branch, [`.github/workflows/notify-downstream.yml`](https://github.com/JLCode-tech/bnk-forge-catalog-shared/blob/release/2.2/.github/workflows/notify-downstream.yml) fans out a `bnk-forge-modules-released` dispatch event to every downstream catalog, which then opens a refresh PR automatically.

See the [catalog repo contract](https://github.com/JLCode-tech/bnk-forge-catalog-shared/blob/release/2.2/CATALOG_REPO_CONTRACT.md) for the full vendoring discipline.

## Quick start for maintainers

```bash
git clone -b release/2.2 https://github.com/JLCode-tech/bnk-forge-catalog-shared.git
cd bnk-forge-catalog-shared
python3 scripts/validate_pack_manifests.py   # CI runs this on every PR
```

Read [`CATALOG_REPO_CONTRACT.md`](https://github.com/JLCode-tech/bnk-forge-catalog-shared/blob/release/2.2/CATALOG_REPO_CONTRACT.md) before opening a PR — it codifies layout, naming, schema, and validation requirements for every `bnk-forge-catalog-*` repo.

## Reference

- [F5 BIG-IP Next for Kubernetes](https://clouddocs.f5.com/bigip-next-for-kubernetes/)
- [BNK Forge Catalog Repo Contract](https://github.com/JLCode-tech/bnk-forge-catalog-shared/blob/release/2.2/CATALOG_REPO_CONTRACT.md)
