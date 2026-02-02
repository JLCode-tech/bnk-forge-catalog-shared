# F5 HSL Publisher Module

Creates F5BigLogHslpub custom resource for High-Speed Logging (HSL) publisher configuration with remote syslog servers.

## Features

- **Remote Logging**: Send logs to external syslog servers
- **Protocol Support**: TCP or UDP syslog
- **Load Balancing**: Distribute logs across multiple servers
- **High Performance**: HSL for minimal performance impact

## Usage

```hcl
module "syslog_publisher" {
  source = "bnk/f5bigloghslpub"

  cluster_name         = "prod-cluster"
  publisher_name       = "remote-syslog"
  publisher_namespace  = "default"

  flo_ready = module.flo.flo_ready

  syslog_servers = [
    "syslog1.example.com:514",
    "syslog2.example.com:514"
  ]

  protocol  = "tcp"
  port      = 514
  pool_name = "syslog-pool"
}
```

## Requirements

- FLO module deployed (provides F5BigLogHslpub CRD)
- Kubernetes cluster with F5 BNK 2.2 GA

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| cluster_name | string | yes | Name of the Kubernetes cluster |
| publisher_name | string | yes | Name for the HSL publisher resource |
| publisher_namespace | string | yes | Namespace for deployment |
| flo_ready | bool | yes | Dependency flag from FLO module |
| syslog_servers | list(string) | yes | Syslog server addresses |
| protocol | string | no | tcp or udp (default: tcp) |
| port | number | no | Default syslog port (default: 514) |
| pool_name | string | no | Server pool name |

## Outputs

| Name | Description |
|------|-------------|
| publisher_ready | Flag indicating publisher is ready |
| publisher_name | Name of the created publisher |
| publisher_namespace | Namespace where publisher is deployed |
| protocol | Configured protocol |
| server_count | Number of syslog servers |

## Syslog Server Format

- With port: `"syslog.example.com:514"`
- Without port: `"syslog.example.com"` (uses default port)
- IP address: `"10.0.1.100:514"`

## Dependencies

- **Required**: bnk/flo (provides CRDs)

## Notes

- HSL publishers can be referenced by BNKSecPolicy resources
- Multiple syslog servers provide redundancy
- TCP provides reliable delivery, UDP has lower overhead
- HSL is optimized for high-throughput logging
- Typical syslog ports: 514 (standard), 6514 (TLS)
