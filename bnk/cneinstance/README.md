# CNE Instance Configuration Module

Creates CneInstance custom resource for CNE (Container Networking and Execution) instance configuration with resource limits and instance settings.

## Features

- **Instance Configuration**: Define CNE instance type and settings
- **Resource Management**: Set CPU and memory limits
- **Scaling**: Configure replica count
- **Affinity**: Control pod placement

## Usage

```hcl
module "cne_instance" {
  source = "bnk/cneinstance"

  cluster_name       = "prod-cluster"
  instance_name      = "cne-instance-1"
  instance_namespace = "f5-spk"

  flo_ready = module.flo.flo_ready

  instance_config = {
    instance_type = "standard"
    replicas      = 3
  }

  resource_limits = {
    cpu_request    = "500m"
    cpu_limit      = "2000m"
    memory_request = "1Gi"
    memory_limit   = "4Gi"
  }
}
```

## Requirements

- FLO module deployed (provides CneInstance CRD)
- Kubernetes cluster with F5 BNK 2.2 GA

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| cluster_name | string | yes | Name of the Kubernetes cluster |
| instance_name | string | yes | Name for the CNE instance resource |
| instance_namespace | string | yes | Namespace for deployment |
| flo_ready | bool | yes | Dependency flag from FLO module |
| instance_config | object | yes | Instance configuration |
| resource_limits | object | no | Resource limits |

## Instance Config Structure

```hcl
instance_config = {
  instance_type = "standard"  # Instance type
  replicas      = 1           # Number of replicas
  affinity      = {}          # Pod affinity rules
}
```

## Resource Limits Structure

```hcl
resource_limits = {
  cpu_request    = "500m"   # CPU request
  cpu_limit      = "2000m"  # CPU limit
  memory_request = "1Gi"    # Memory request
  memory_limit   = "4Gi"    # Memory limit
}
```

## Outputs

| Name | Description |
|------|-------------|
| instance_ready | Flag indicating instance is ready |
| instance_name | Name of the created instance |
| instance_namespace | Namespace where instance is deployed |
| instance_type | Configured instance type |
| replicas | Number of replicas |

## Dependencies

- **Required**: bnk/flo (provides CRDs)

## Notes

- CNE instances provide container networking and execution
- Typically deployed in f5-spk namespace
- Resource limits should match workload requirements
- Replicas provide high availability
- Instance type determines capabilities and performance
