# BNK Cert Issuer

Creates Forge-managed self-signed CA and ClusterIssuer resources for BNK cert-manager flows.

## Description

This module is a Python-runtime manifest module. The actual manifests are rendered by the backend engine at `backend/modules/k8s/bnk_cert_issuer.py`. This pack entry exists so the module catalog sync discovers and registers the module in the library.

## Dependencies

- `k8s/cert-manager` — CRDs must exist before ClusterIssuer/Certificate resources
- `k8s/bnk-prerequisites` — BNK namespaces must exist

## Outputs

- `cluster_issuer_name` — CA-backed ClusterIssuer consumed by BNK components
- `ca_secret_name` — Secret containing the generated CA keypair
- `cert_issuer_ready` — Boolean gate output
