# Module Metadata Contract (v2alpha1)

This repository is the canonical source of truth for **official BNK-Forge modules**.

Each module must define `module.json` using the contract below.

## Contract goals

- Keep module **source kind** separate from runtime execution details.
- Keep **execution engine** separate from **deploy/render model**.
- Represent **Helm** as first-class deploy model metadata.
- Provide a predictable shape for BNK-Forge catalog sync.

## Generic contract (`module-metadata/v2alpha1`)

The generic contract is release-agnostic.

## Required top-level sections

```json
{
  "module": {
    "name": "string",
    "path": "string",
    "version": "string",
    "layer": "string",
    "category": "string",
    "description": "string",
    "cloud_specific": false,
    "supported_platforms": ["any"]
  },
  "source": {
    "kind": "string",
    "channel": "string"
  },
  "execution": {
    "engine": "string",
    "deploy_models": ["terraform", "helm", "kubernetes_manifest", "shell"]
  },
  "contract": {
    "metadata_version": "module-metadata/v2alpha1"
  },
  "dependencies": { "required": [], "optional": [] },
  "inputs": { "required": [], "optional": [] },
  "outputs": { "key_outputs": [] },
  "providers": { "required": [], "optional": [] },
  "deployment": {
    "order": 0,
    "estimated_time": "string",
    "requires_user_input": false,
    "sensitive_inputs": []
  }
}
```

## Field semantics

### `source`

- `kind`: module provenance/classification (example: `official`).
- `channel`: source channel/stream (example: `release/2.2`).

### `execution`

- `engine`: orchestration/runtime engine (example: `opentofu`).
- `deploy_models`: module behaviors rendered/executed by the engine.
  - Allowed values in this slice: `terraform`, `helm`, `kubernetes_manifest`, `shell`
  - `helm` is first-class and must be present where Helm is part of module execution.

### `contract`

- `metadata_version`: explicit schema contract version for sync consumers.

### Input source enum (`inputs.required[]` / `inputs.optional[]`)

- `user` — value is user-provided
- `module` — value comes from another module output
- `auto` — value auto-derived by runtime or module logic
- `project_secret` — value comes from secure project secret storage

`project_secret` is a first-class input source in this contract and is validated.

## Release-specific baseline assertions (`release/2.2`)

Release-specific expectations are declared in:

- `catalog/releases/release-2.2-official.json`

The release manifest defines:

- release channel/source-kind/execution-engine defaults for the baseline
- every official `bnk/` and `k8s/` module in scope
- explicit module state: `active`, `legacy`, or `deprecated`

No official module is allowed to silently fall back outside this manifest.

- `active`: must satisfy generic contract + match release assertions
- `legacy`: intentionally not yet migrated; must include `reason`
- `deprecated`: intentionally retired/replaced; must include `reason`

## Initial active migration scope (implemented in this slice)

The following modules are upgraded to this contract:

- `k8s/bnk-prerequisites`
- `k8s/cert-manager`
- `k8s/network-setup`
- `bnk/flo`
- `bnk/cneinstance`
- `bnk/bnk-gatewayclass`

## Validation

Run:

```bash
python3 scripts/validate_module_metadata.py
```

The validator checks:

- generic contract structure for active official modules
- input source enum validity (`user|module|auto|project_secret`)
- release manifest integrity and explicit module-state classification
- release-specific assertions for active modules (source/channel/engine/deploy-model alignment)
- completeness: all official `bnk/` and `k8s/` modules must appear in release manifest
