# Implementation Plan: BNK 2.2 GA Alignment

**Created**: 2026-02-04
**Status**: Ready for Implementation
**Target Branch**: `release/2.2`
**Related F5 Docs**: https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/overview.html

## Executive Summary

This plan aligns bnk-forge-modules and bnk-forge-v2 with F5 BIG-IP Next for Kubernetes 2.2 GA documentation. The primary gaps are:

1. Missing policy configuration modules (BNKSecPolicy, BNKNetPolicy) - were archived but needed
2. Missing IPAM integration module (F5BnkGateway)
3. Stack templates need cert-manager as explicit prerequisite before FLO
4. Need version-based branching strategy for F5 release alignment

## Key Finding

The modules `bnk/bnk-secpolicy` and `bnk/bnk-netpolicy` were archived on 2026-02-03 because they were considered "advanced CRD configs". However:
- Stack templates in bnk-forge-v2 reference these modules
- They are needed for complete 2.2 GA deployment per F5 docs
- They should be **restored and updated** to match actual F5 2.2 CRD schemas

**Important Distinction**:
- FLO installs the CRDs automatically
- These modules create **instances** of those CRDs (Custom Resources)
- This is the correct separation of concerns

---

## Branching Strategy

### Version-Based Branches

```
main (stable, production-ready)
├── release/2.2    ← Current work (BNK 2.2 GA)
├── release/2.3    ← Future (when F5 releases 2.3)
└── release/2.4    ← Future
```

### Branch Workflow

1. **Create release branch**: `git checkout -b release/2.2 main`
2. **Implement changes**: All 2.2 work happens on `release/2.2`
3. **Test thoroughly**: Validate with bnk-forge-v2 stack deployments
4. **Merge to main**: `git checkout main && git merge release/2.2`
5. **Tag release**: `git tag v2.2.0`

### Feature Branch Convention

For larger features within a release:
```
release/2.2
├── feature/release-2.2/bnk-secpolicy
├── feature/release-2.2/bnk-netpolicy
└── feature/release-2.2/bnk-gateway-ext
```

---

## Stage 1: Restore and Update Policy Modules

### Stage 1.1: Restore `bnk/bnk-secpolicy`

**Action**: Move from `archived/bnk/crds/bnk-secpolicy/` to `bnk/bnk-secpolicy/`

**Why**: Stack templates reference this module, F5 2.2 docs include BNKSecPolicy

#### Updated `variables.tf`

```hcl
variable "policy_name" {
  description = "Name for the BNKSecPolicy resource"
  type        = string
}

variable "namespace" {
  description = "Namespace for the BNKSecPolicy"
  type        = string
  default     = "default"
}

variable "target_kind" {
  description = "Kind of target resource (GatewayClass or Gateway)"
  type        = string
  validation {
    condition     = contains(["GatewayClass", "Gateway"], var.target_kind)
    error_message = "target_kind must be either 'GatewayClass' or 'Gateway'"
  }
}

variable "target_name" {
  description = "Name of the target GatewayClass or Gateway"
  type        = string
}

variable "target_namespace" {
  description = "Namespace of the target (required if target_kind is Gateway)"
  type        = string
  default     = ""
}

variable "firewall_policy_ref" {
  description = "Reference to F5BigFwPolicy resource"
  type = object({
    name      = string
    namespace = optional(string, "")
  })
  default = null
}

variable "ddos_policy_ref" {
  description = "Reference to F5BigDdosGlobal resource"
  type = object({
    name      = string
    namespace = optional(string, "")
  })
  default = null
}

variable "flo_ready" {
  description = "Dependency flag - FLO must be ready before applying policies"
  type        = bool
  default     = true
}
```

#### Updated `main.tf`

```hcl
resource "kubernetes_manifest" "bnk_secpolicy" {
  manifest = {
    apiVersion = "k8s.f5.com/v1"
    kind       = "BNKSecPolicy"
    metadata = {
      name      = var.policy_name
      namespace = var.namespace
    }
    spec = {
      targetRef = {
        group     = "gateway.networking.k8s.io"
        kind      = var.target_kind
        name      = var.target_name
        namespace = var.target_kind == "Gateway" ? (var.target_namespace != "" ? var.target_namespace : null) : null
      }
      firewallPolicy = var.firewall_policy_ref != null ? {
        name      = var.firewall_policy_ref.name
        namespace = var.firewall_policy_ref.namespace != "" ? var.firewall_policy_ref.namespace : var.namespace
      } : null
      ddosPolicy = var.ddos_policy_ref != null ? {
        name      = var.ddos_policy_ref.name
        namespace = var.ddos_policy_ref.namespace != "" ? var.ddos_policy_ref.namespace : var.namespace
      } : null
    }
  }
}
```

#### Updated `outputs.tf`

```hcl
output "policy_name" {
  description = "Name of the created BNKSecPolicy"
  value       = var.policy_name
}

output "policy_namespace" {
  description = "Namespace of the BNKSecPolicy"
  value       = var.namespace
}

output "policy_ready" {
  description = "Flag indicating policy was applied"
  value       = true
  depends_on  = [kubernetes_manifest.bnk_secpolicy]
}
```

#### Updated `versions.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23.0"
    }
  }
}
```

#### Updated `module.json`

```json
{
  "module": {
    "name": "BNK Security Policy",
    "path": "bnk/bnk-secpolicy",
    "version": "1.0.0",
    "layer": "bnk-policy",
    "category": "policy",
    "description": "Configures BNKSecPolicy CR to attach security policies (Firewall, DDoS) to GatewayClass or Gateway resources. Requires FLO to be deployed first.",
    "cloud_specific": false,
    "supported_platforms": ["any"]
  },
  "dependencies": {
    "required": [
      {
        "module": "bnk/flo",
        "reason": "FLO must be deployed to install BNKSecPolicy CRD and manage policies"
      }
    ],
    "optional": []
  },
  "inputs": {
    "required": [
      {
        "name": "policy_name",
        "type": "string",
        "description": "Name for the BNKSecPolicy resource",
        "source": "user",
        "example": "my-security-policy"
      },
      {
        "name": "target_kind",
        "type": "string",
        "description": "Kind of target resource",
        "source": "user",
        "example": "Gateway",
        "enum_values": [
          {"label": "GatewayClass", "value": "GatewayClass"},
          {"label": "Gateway", "value": "Gateway"}
        ]
      },
      {
        "name": "target_name",
        "type": "string",
        "description": "Name of the target GatewayClass or Gateway",
        "source": "user",
        "example": "bnk-gateway"
      },
      {
        "name": "flo_ready",
        "type": "boolean",
        "description": "Dependency flag ensuring FLO is ready",
        "source": "module",
        "from_module": "bnk/flo",
        "from_output": "flo_ready"
      }
    ],
    "optional": [
      {
        "name": "namespace",
        "type": "string",
        "description": "Namespace for the BNKSecPolicy",
        "default": "default",
        "source": "user"
      },
      {
        "name": "target_namespace",
        "type": "string",
        "description": "Namespace of the target (required if target_kind is Gateway)",
        "default": "",
        "source": "user"
      },
      {
        "name": "firewall_policy_ref",
        "type": "object",
        "description": "Reference to F5BigFwPolicy resource (name and optional namespace)",
        "default": null,
        "source": "user"
      },
      {
        "name": "ddos_policy_ref",
        "type": "object",
        "description": "Reference to F5BigDdosGlobal resource (name and optional namespace)",
        "default": null,
        "source": "user"
      }
    ]
  },
  "outputs": {
    "key_outputs": [
      {
        "name": "policy_name",
        "type": "string",
        "description": "Name of the created BNKSecPolicy",
        "used_by": [],
        "sensitive": false
      },
      {
        "name": "policy_ready",
        "type": "boolean",
        "description": "Flag indicating policy was applied",
        "used_by": [],
        "sensitive": false
      }
    ]
  },
  "providers": {
    "required": ["kubernetes"],
    "optional": []
  },
  "deployment": {
    "order": 85,
    "estimated_time": "1 minute",
    "requires_user_input": true,
    "sensitive_inputs": []
  }
}
```

#### Verification Steps

```bash
# 1. Move module from archive
mv archived/bnk/crds/bnk-secpolicy bnk/bnk-secpolicy

# 2. Update files with new content (above)

# 3. Validate
cd bnk/bnk-secpolicy
tofu init -backend=false
tofu validate

# 4. Validate module.json
jq empty module.json && echo "Valid JSON"
```

---

### Stage 1.2: Restore `bnk/bnk-netpolicy`

**Action**: Move from `archived/bnk/crds/bnk-netpolicy/` to `bnk/bnk-netpolicy/`

#### Updated `variables.tf`

```hcl
variable "policy_name" {
  description = "Name for the BNKNetPolicy resource"
  type        = string
}

variable "namespace" {
  description = "Namespace for the BNKNetPolicy"
  type        = string
  default     = "default"
}

variable "target_name" {
  description = "Name of the target Gateway"
  type        = string
}

variable "target_namespace" {
  description = "Namespace of the target Gateway"
  type        = string
}

variable "irule_refs" {
  description = "List of iRule references to attach"
  type = list(object({
    name      = string
    namespace = optional(string, "")
  }))
  default = []
}

variable "tcp_client_settings" {
  description = "TCP client-side settings"
  type = object({
    idle_timeout    = optional(number)
    nagle_algorithm = optional(bool)
  })
  default = null
}

variable "tcp_server_settings" {
  description = "TCP server-side settings"
  type = object({
    idle_timeout    = optional(number)
    nagle_algorithm = optional(bool)
  })
  default = null
}

variable "hsl_log_profile_ref" {
  description = "Reference to HSL log profile"
  type = object({
    name      = string
    namespace = optional(string, "")
  })
  default = null
}

variable "flo_ready" {
  description = "Dependency flag - FLO must be ready before applying policies"
  type        = bool
  default     = true
}
```

#### Updated `main.tf`

```hcl
locals {
  irule_references = [
    for irule in var.irule_refs : {
      name      = irule.name
      namespace = irule.namespace != "" ? irule.namespace : var.namespace
    }
  ]
}

resource "kubernetes_manifest" "bnk_netpolicy" {
  manifest = {
    apiVersion = "k8s.f5.com/v1"
    kind       = "BNKNetPolicy"
    metadata = {
      name      = var.policy_name
      namespace = var.namespace
    }
    spec = {
      targetRef = {
        group     = "gateway.networking.k8s.io"
        kind      = "Gateway"
        name      = var.target_name
        namespace = var.target_namespace
      }
      
      iRules = length(local.irule_references) > 0 ? local.irule_references : null
      
      tcpClientSettings = var.tcp_client_settings != null ? {
        idleTimeout    = var.tcp_client_settings.idle_timeout
        nagleAlgorithm = var.tcp_client_settings.nagle_algorithm
      } : null
      
      tcpServerSettings = var.tcp_server_settings != null ? {
        idleTimeout    = var.tcp_server_settings.idle_timeout
        nagleAlgorithm = var.tcp_server_settings.nagle_algorithm
      } : null
      
      hslLogProfile = var.hsl_log_profile_ref != null ? {
        name      = var.hsl_log_profile_ref.name
        namespace = var.hsl_log_profile_ref.namespace != "" ? var.hsl_log_profile_ref.namespace : var.namespace
      } : null
    }
  }
}
```

#### Updated `outputs.tf`

```hcl
output "policy_name" {
  description = "Name of the created BNKNetPolicy"
  value       = var.policy_name
}

output "policy_namespace" {
  description = "Namespace of the BNKNetPolicy"
  value       = var.namespace
}

output "policy_ready" {
  description = "Flag indicating policy was applied"
  value       = true
  depends_on  = [kubernetes_manifest.bnk_netpolicy]
}
```

#### Updated `module.json`

```json
{
  "module": {
    "name": "BNK Network Policy",
    "path": "bnk/bnk-netpolicy",
    "version": "1.0.0",
    "layer": "bnk-policy",
    "category": "policy",
    "description": "Configures BNKNetPolicy CR to attach network policies (iRules, TCP settings, HSL logging) to Gateway resources. Requires FLO to be deployed first.",
    "cloud_specific": false,
    "supported_platforms": ["any"]
  },
  "dependencies": {
    "required": [
      {
        "module": "bnk/flo",
        "reason": "FLO must be deployed to install BNKNetPolicy CRD and manage policies"
      }
    ],
    "optional": []
  },
  "inputs": {
    "required": [
      {
        "name": "policy_name",
        "type": "string",
        "description": "Name for the BNKNetPolicy resource",
        "source": "user",
        "example": "my-network-policy"
      },
      {
        "name": "target_name",
        "type": "string",
        "description": "Name of the target Gateway",
        "source": "user",
        "example": "bnk-gateway"
      },
      {
        "name": "target_namespace",
        "type": "string",
        "description": "Namespace of the target Gateway",
        "source": "user",
        "example": "app-ns"
      },
      {
        "name": "flo_ready",
        "type": "boolean",
        "description": "Dependency flag ensuring FLO is ready",
        "source": "module",
        "from_module": "bnk/flo",
        "from_output": "flo_ready"
      }
    ],
    "optional": [
      {
        "name": "namespace",
        "type": "string",
        "description": "Namespace for the BNKNetPolicy",
        "default": "default",
        "source": "user"
      },
      {
        "name": "irule_refs",
        "type": "list(object)",
        "description": "List of iRule references (name and optional namespace)",
        "default": [],
        "source": "user"
      },
      {
        "name": "tcp_client_settings",
        "type": "object",
        "description": "TCP client-side settings (idle_timeout, nagle_algorithm)",
        "default": null,
        "source": "user"
      },
      {
        "name": "tcp_server_settings",
        "type": "object",
        "description": "TCP server-side settings (idle_timeout, nagle_algorithm)",
        "default": null,
        "source": "user"
      },
      {
        "name": "hsl_log_profile_ref",
        "type": "object",
        "description": "Reference to HSL log profile (name and optional namespace)",
        "default": null,
        "source": "user"
      }
    ]
  },
  "outputs": {
    "key_outputs": [
      {
        "name": "policy_name",
        "type": "string",
        "description": "Name of the created BNKNetPolicy",
        "used_by": [],
        "sensitive": false
      },
      {
        "name": "policy_ready",
        "type": "boolean",
        "description": "Flag indicating policy was applied",
        "used_by": [],
        "sensitive": false
      }
    ]
  },
  "providers": {
    "required": ["kubernetes"],
    "optional": []
  },
  "deployment": {
    "order": 86,
    "estimated_time": "1 minute",
    "requires_user_input": true,
    "sensitive_inputs": []
  }
}
```

#### Verification Steps

```bash
# 1. Move module from archive
mv archived/bnk/crds/bnk-netpolicy bnk/bnk-netpolicy

# 2. Update files with new content

# 3. Validate
cd bnk/bnk-netpolicy
tofu init -backend=false
tofu validate

# 4. Validate module.json
jq empty module.json && echo "Valid JSON"
```

---

### Stage 1.3: Create `bnk/bnk-gateway-ext` (NEW)

**Action**: Create new module for F5BnkGateway IPAM integration

#### Create Directory Structure

```bash
mkdir -p bnk/bnk-gateway-ext
```

#### `variables.tf`

```hcl
variable "gateway_ext_name" {
  description = "Name for the F5BnkGateway resource"
  type        = string
}

variable "namespace" {
  description = "Namespace for the F5BnkGateway"
  type        = string
  default     = "default"
}

variable "ipv4_cidr_range" {
  description = "IPv4 CIDR range for IPAM allocation (e.g., 192.168.17.0/24)"
  type        = string
  default     = ""
}

variable "ipv6_cidr_range" {
  description = "IPv6 CIDR range for IPAM allocation"
  type        = string
  default     = ""
}

variable "default_network" {
  description = "Default network name for IP allocation"
  type        = string
  default     = "default"
}

variable "flo_ready" {
  description = "Dependency flag - FLO must be ready before applying"
  type        = bool
  default     = true
}
```

#### `main.tf`

```hcl
locals {
  has_ipv4 = var.ipv4_cidr_range != ""
  has_ipv6 = var.ipv6_cidr_range != ""
  has_any_network = local.has_ipv4 || local.has_ipv6
  
  networks = concat(
    local.has_ipv4 ? [{
      name = var.default_network
      cidr = var.ipv4_cidr_range
    }] : [],
    local.has_ipv6 ? [{
      name = "${var.default_network}-v6"
      cidr = var.ipv6_cidr_range
    }] : []
  )
}

resource "kubernetes_manifest" "f5_bnk_gateway" {
  count = local.has_any_network ? 1 : 0
  
  manifest = {
    apiVersion = "k8s.f5net.com/v1"
    kind       = "F5BnkGateway"
    metadata = {
      name      = var.gateway_ext_name
      namespace = var.namespace
    }
    spec = {
      networks = local.networks
    }
  }
}
```

#### `outputs.tf`

```hcl
output "gateway_ext_name" {
  description = "Name of the created F5BnkGateway"
  value       = var.gateway_ext_name
}

output "gateway_ext_namespace" {
  description = "Namespace of the F5BnkGateway"
  value       = var.namespace
}

output "ipv4_cidr_range" {
  description = "Configured IPv4 CIDR range"
  value       = var.ipv4_cidr_range
}

output "ipv6_cidr_range" {
  description = "Configured IPv6 CIDR range"
  value       = var.ipv6_cidr_range
}

output "gateway_ext_ready" {
  description = "Flag indicating F5BnkGateway was applied"
  value       = length(kubernetes_manifest.f5_bnk_gateway) > 0
}
```

#### `versions.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23.0"
    }
  }
}
```

#### `module.json`

```json
{
  "module": {
    "name": "BNK Gateway Extension (IPAM)",
    "path": "bnk/bnk-gateway-ext",
    "version": "1.0.0",
    "layer": "bnk-gateway",
    "category": "gateway",
    "description": "Configures F5BnkGateway CR for IPAM integration. Defines IP address ranges that the F5 IPAM Controller uses to allocate addresses to Gateways.",
    "cloud_specific": false,
    "supported_platforms": ["any"]
  },
  "dependencies": {
    "required": [
      {
        "module": "bnk/flo",
        "reason": "FLO must be deployed to install F5BnkGateway CRD and IPAM controller"
      }
    ],
    "optional": []
  },
  "inputs": {
    "required": [
      {
        "name": "gateway_ext_name",
        "type": "string",
        "description": "Name for the F5BnkGateway resource",
        "source": "user",
        "example": "my-bnkgateway"
      },
      {
        "name": "flo_ready",
        "type": "boolean",
        "description": "Dependency flag ensuring FLO is ready",
        "source": "module",
        "from_module": "bnk/flo",
        "from_output": "flo_ready"
      }
    ],
    "optional": [
      {
        "name": "namespace",
        "type": "string",
        "description": "Namespace for the F5BnkGateway",
        "default": "default",
        "source": "user"
      },
      {
        "name": "ipv4_cidr_range",
        "type": "string",
        "description": "IPv4 CIDR range for IPAM allocation (e.g., 192.168.17.0/24)",
        "default": "",
        "source": "user",
        "example": "192.168.17.0/24"
      },
      {
        "name": "ipv6_cidr_range",
        "type": "string",
        "description": "IPv6 CIDR range for IPAM allocation",
        "default": "",
        "source": "user"
      },
      {
        "name": "default_network",
        "type": "string",
        "description": "Default network name for IP allocation",
        "default": "default",
        "source": "user"
      }
    ]
  },
  "outputs": {
    "key_outputs": [
      {
        "name": "gateway_ext_name",
        "type": "string",
        "description": "Name of the created F5BnkGateway",
        "used_by": ["bnk/gateway"],
        "sensitive": false
      },
      {
        "name": "gateway_ext_ready",
        "type": "boolean",
        "description": "Flag indicating F5BnkGateway was applied",
        "used_by": ["bnk/gateway"],
        "sensitive": false
      }
    ]
  },
  "providers": {
    "required": ["kubernetes"],
    "optional": []
  },
  "deployment": {
    "order": 65,
    "estimated_time": "1 minute",
    "requires_user_input": true,
    "sensitive_inputs": []
  }
}
```

#### `README.md`

```markdown
# BNK Gateway Extension Module (F5BnkGateway)

Configures F5BnkGateway Custom Resource for IPAM integration with BNK Gateway API.

## Description

This module creates an F5BnkGateway CR that defines IP address ranges for the F5 IPAM Controller. When a Gateway references this F5BnkGateway via `infrastructure.parametersRef`, the IPAM controller automatically allocates IP addresses from the configured ranges.

## Prerequisites

- FLO must be deployed (`bnk/flo` module) with IPAM operator enabled

## Usage

module "bnk_gateway_ext" {
  source = "git::https://github.com/org/bnk-forge-modules.git//bnk/bnk-gateway-ext"

  gateway_ext_name = "app-bnkgateway"
  namespace        = "app-ns"
  ipv4_cidr_range  = "192.168.17.0/24"
  
  flo_ready = module.flo.flo_ready
}

Then reference in Gateway (via bnk/gateway module):

module "gateway" {
  source = "..."
  
  infrastructure_parameters_ref = {
    name = module.bnk_gateway_ext.gateway_ext_name
  }
}

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
| gateway_ext_name | Name for the F5BnkGateway | string | yes | - |
| namespace | Namespace for the resource | string | no | "default" |
| ipv4_cidr_range | IPv4 CIDR range for IPAM | string | no | "" |
| ipv6_cidr_range | IPv6 CIDR range for IPAM | string | no | "" |
| default_network | Network name for allocation | string | no | "default" |
| flo_ready | Dependency flag | bool | yes | - |

## Outputs

| Name | Description |
|------|-------------|
| gateway_ext_name | Name of created F5BnkGateway |
| gateway_ext_ready | Boolean indicating success |
```

#### Verification Steps

```bash
# 1. Create module directory
mkdir -p bnk/bnk-gateway-ext

# 2. Create all files (as above)

# 3. Validate
cd bnk/bnk-gateway-ext
tofu init -backend=false
tofu validate

# 4. Validate module.json
jq empty module.json && echo "Valid JSON"
```

---

## Stage 2: Update Existing Modules

### Stage 2.1: Update `bnk/gateway` for IPAM Support

**Files to modify**: `variables.tf`, `main.tf`, `module.json`

#### Add to `variables.tf`

```hcl
variable "infrastructure_parameters_ref" {
  description = "Reference to F5BnkGateway for IPAM integration"
  type = object({
    group = optional(string, "k8s.f5net.com")
    kind  = optional(string, "F5BnkGateway")
    name  = string
  })
  default = null
}

variable "gateway_addresses" {
  description = "Static IP addresses for Gateway (optional, used with IPAM)"
  type = list(object({
    type  = optional(string, "IPAddress")
    value = string
  }))
  default = []
}
```

#### Update `main.tf` (Gateway spec)

Add to the Gateway manifest spec:

```hcl
# In the manifest spec block:
addresses = length(var.gateway_addresses) > 0 ? var.gateway_addresses : null

infrastructure = var.infrastructure_parameters_ref != null ? {
  parametersRef = {
    group = var.infrastructure_parameters_ref.group
    kind  = var.infrastructure_parameters_ref.kind
    name  = var.infrastructure_parameters_ref.name
  }
} : null
```

#### Update `module.json` (add to optional inputs)

```json
{
  "name": "infrastructure_parameters_ref",
  "type": "object",
  "description": "Reference to F5BnkGateway for IPAM integration",
  "default": null,
  "source": "user"
},
{
  "name": "gateway_addresses",
  "type": "list(object)",
  "description": "Static IP addresses for Gateway",
  "default": [],
  "source": "user"
}
```

#### Verification

```bash
cd bnk/gateway
tofu init -backend=false
tofu validate
jq empty module.json
```

---

## Stage 3: Update Documentation

### Stage 3.1: Update `DEPENDENCY_GRAPH.md`

Add new section for Policy Layer:

```markdown
### BNK Policy Layer

#### bnk/bnk-secpolicy
- **Layer**: BNK Policy
- **Dependencies**: flo
- **Required Inputs**:
  - policy_name (user)
  - target_kind (user)
  - target_name (user)
  - flo_ready (from flo)
- **Key Outputs**: policy_name, policy_ready
- **Required For**: Optional attachment to Gateway/GatewayClass

#### bnk/bnk-netpolicy
- **Layer**: BNK Policy
- **Dependencies**: flo
- **Required Inputs**:
  - policy_name (user)
  - target_name (user)
  - target_namespace (user)
  - flo_ready (from flo)
- **Key Outputs**: policy_name, policy_ready
- **Required For**: Optional attachment to Gateway

#### bnk/bnk-gateway-ext
- **Layer**: BNK Gateway
- **Dependencies**: flo
- **Required Inputs**:
  - gateway_ext_name (user)
  - flo_ready (from flo)
- **Key Outputs**: gateway_ext_name, gateway_ext_ready
- **Required For**: Optional IPAM integration with bnk/gateway
```

### Stage 3.2: Update `archived/README.md`

Remove bnk-secpolicy and bnk-netpolicy from archived list (they're being restored).

---

## Stage 4: Add CI Validation

### Create `.github/workflows/validate-modules.yml`

```yaml
name: Validate Modules

on:
  push:
    branches: [main, 'release/**']
  pull_request:
    branches: [main, 'release/**']

jobs:
  validate:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Setup OpenTofu
        uses: opentofu/setup-opentofu@v1
        with:
          tofu_version: 1.6.0
      
      - name: Terraform Format Check
        run: tofu fmt -check -recursive
      
      - name: Validate module.json files
        run: |
          for f in $(find infra k8s bnk -name "module.json" 2>/dev/null); do
            echo "Validating $f..."
            jq empty "$f" || exit 1
          done
          echo "All module.json files are valid JSON"
      
      - name: Validate Terraform Modules
        run: |
          for dir in $(find infra k8s bnk -name "main.tf" -exec dirname {} \; 2>/dev/null); do
            echo "Validating $dir..."
            (cd "$dir" && tofu init -backend=false && tofu validate) || exit 1
          done
          echo "All modules validated successfully"
      
      - name: Check Required Files
        run: |
          ERRORS=0
          for dir in $(find infra k8s bnk -name "main.tf" -exec dirname {} \; 2>/dev/null); do
            for file in main.tf variables.tf outputs.tf versions.tf module.json README.md; do
              if [ ! -f "$dir/$file" ]; then
                echo "ERROR: Missing $dir/$file"
                ERRORS=$((ERRORS + 1))
              fi
            done
          done
          if [ $ERRORS -gt 0 ]; then
            echo "Found $ERRORS missing files"
            exit 1
          fi
          echo "All required files present"
```

---

## Stage 5: BNK-Forge-V2 Changes

### Stage 5.1: Update Stack Templates

**File**: `backend/data/stack_templates.json`

Update "F5 BNK Complete" stack:

```json
{
  "name": "F5 BNK Complete",
  "slug": "f5-bnk-complete",
  "description": "Full F5 BIG-IP Next for Kubernetes deployment with Gateway API (2.2 GA)",
  "modules": [
    {"path": "bnk/far-setup", "name": "FAR Setup", "required": true},
    {"path": "k8s/cert-manager", "name": "Cert Manager", "required": true},
    {"path": "bnk/flo", "name": "F5 Lifecycle Operator", "required": true},
    {"path": "bnk/bnk-gatewayclass", "name": "GatewayClass", "required": true},
    {"path": "bnk/bnk-gateway-ext", "name": "Gateway IPAM Config", "required": false},
    {"path": "bnk/gateway", "name": "Gateway", "required": true},
    {"path": "bnk/routes", "name": "HTTP Routes", "required": true},
    {"path": "bnk/bnk-secpolicy", "name": "Security Policy", "required": false},
    {"path": "bnk/bnk-netpolicy", "name": "Network Policy", "required": false}
  ],
  "version": "2.2.0"
}
```

Also update "BNK-Forge Quick Demo" to include cert-manager before flo.

### Stage 5.2: Resync and Test

```bash
# Trigger catalog sync
curl -X POST http://localhost:2650/api/v1/modules/sync

# Verify new modules appear
curl http://localhost:2650/api/v1/modules | jq '.[] | select(.path | contains("bnk-secpolicy"))'
```

---

## Implementation Checklist

| Stage | Task | Est. Time | Verification |
|-------|------|-----------|--------------|
| 1.1 | Restore bnk-secpolicy | 30 min | tofu validate |
| 1.2 | Restore bnk-netpolicy | 30 min | tofu validate |
| 1.3 | Create bnk-gateway-ext | 45 min | tofu validate |
| 2.1 | Update bnk/gateway | 20 min | tofu validate |
| 3.1 | Update DEPENDENCY_GRAPH.md | 15 min | grep check |
| 3.2 | Update archived/README.md | 5 min | visual |
| 4 | Add CI workflow | 15 min | workflow runs |
| 5.1 | Update stack_templates.json | 15 min | jq validate |
| 5.2 | Sync and test | 30 min | API + manual |

**Total: ~3.5 hours**

---

## Success Criteria

1. [ ] All restored/new modules pass `tofu validate`
2. [ ] All `module.json` files pass JSON validation
3. [ ] CI workflow passes on PR
4. [ ] Stack templates include cert-manager before flo
5. [ ] Catalog sync loads new modules
6. [ ] End-to-end "F5 BNK Complete" stack deploys successfully

---

## Notes on CRD API Versions

Based on F5 2.2 GA documentation:
- `k8s.f5.com/v1` - BNKSecPolicy, BNKNetPolicy
- `k8s.f5net.com/v1` - F5BnkGateway

These should be verified against actual CRDs installed by FLO 2.2 during testing.

---

## Relationship to Other Work

The other agent mentioned:
- **P1-7 BNK Stack Deployment** - This plan addresses the cert-manager blocker
- **P1-8 SPK → BNK Naming** - Can be done after this alignment work

This plan is **P0** because:
1. Stack templates reference non-existent modules (broken)
2. F5 2.2 GA alignment is required for production use
3. Other work is blocked until modules exist
