# F5 BIG-IP Firewall Policy Module

Creates F5BigFwPolicy custom resource for advanced firewall policies with ingress/egress rules, address lists, port lists, and configurable default actions.

## Features

- **Ingress/Egress Rules**: Define detailed L3/L4 firewall rules for both directions
- **Address Lists**: Reference F5BigCneAddresslist resources for IP-based filtering
- **Port Lists**: Reference F5BigCnePortlist resources for port-based filtering
- **Default Action**: Configure default action (accept, drop, reject) for unmatched traffic
- **Logging**: Enable per-rule and policy-level logging

## Usage

```hcl
module "firewall_policy" {
  source = "bnk/f5bigfwpolicy"

  cluster_name      = "prod-cluster"
  policy_name       = "app-firewall-policy"
  policy_namespace  = "default"
  default_action    = "drop"

  flo_ready = module.flo.flo_ready

  ingress_rules = [
    {
      name             = "allow-https"
      action           = "accept"
      protocol         = "tcp"
      dest_ports       = ["443"]
      source_addresses = ["0.0.0.0/0"]
      log              = true
    },
    {
      name             = "deny-ssh"
      action           = "drop"
      protocol         = "tcp"
      dest_ports       = ["22"]
      log              = true
    }
  ]

  egress_rules = [
    {
      name           = "allow-dns"
      action         = "accept"
      protocol       = "udp"
      dest_ports     = ["53"]
      log            = false
    }
  ]

  enable_logging = true
  description    = "Firewall policy for production application"
}
```

## Requirements

- FLO module deployed (provides F5BigFwPolicy CRD)
- Kubernetes cluster with F5 BNK 2.2 GA

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| cluster_name | string | yes | Name of the Kubernetes cluster |
| policy_name | string | yes | Name for the F5BigFwPolicy resource |
| policy_namespace | string | yes | Namespace for deployment |
| flo_ready | bool | yes | Dependency flag from FLO module |
| default_action | string | yes | Default action (accept, drop, reject) |
| ingress_rules | list | no | List of ingress firewall rules |
| egress_rules | list | no | List of egress firewall rules |
| enable_logging | bool | no | Enable firewall event logging (default: true) |
| description | string | no | Policy description |

## Outputs

| Name | Description |
|------|-------------|
| policy_ready | Flag indicating policy is ready |
| policy_name | Name of the created policy |
| policy_namespace | Namespace where policy is deployed |
| default_action | Configured default action |
| ingress_rule_count | Number of ingress rules |
| egress_rule_count | Number of egress rules |

## Rule Structure

Each rule supports:
- `name`: Rule identifier
- `action`: accept, drop, or reject
- `protocol`: tcp, udp, icmp, or any
- `source_addresses`: List of source CIDR ranges
- `source_ports`: List of source ports/ranges
- `dest_addresses`: List of destination CIDR ranges
- `dest_ports`: List of destination ports/ranges
- `address_list_refs`: References to F5BigCneAddresslist resources
- `port_list_refs`: References to F5BigCnePortlist resources
- `log`: Enable logging for this rule (default: true)

## Dependencies

- **Required**: bnk/flo (provides CRDs)
- **Optional**: bnk/f5bigcneaddresslist, bnk/f5bigcneportlist

## Notes

- Firewall policies can be referenced by BNKSecPolicy resources
- Rules are processed in order; first match wins
- Default action applies to unmatched traffic
- Logging can be configured per-rule and at policy level
