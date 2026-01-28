# F5 AI Load Balancing Analyzer Module (Early Access)

Creates F5BigAnalyzer custom resource for AI Load Balancing with LLM workload optimization and intelligent routing algorithms.

## Features

- **LLM Workload Optimization**: Specialized load balancing for AI/LLM workloads
- **Token-Aware Routing**: Route based on token usage and capacity
- **Multiple Algorithms**: Choose from token-aware, latency-optimized, cost-optimized
- **Streaming Support**: Optimized for streaming LLM responses
- **Metrics Export**: Prometheus-compatible metrics endpoint

## Usage

```hcl
module "llm_analyzer" {
  source = "bnk/f5biganalyzer"

  cluster_name        = "ai-cluster"
  analyzer_name       = "llm-analyzer"
  analyzer_namespace  = "default"

  flo_ready = module.flo.flo_ready

  llm_workload_config = {
    model_type        = "gpt"
    max_tokens        = 4096
    context_window    = 8192
    streaming_enabled = true
    batch_size        = 1
  }

  routing_algorithm = "token-aware"
  enable_metrics    = true
  metrics_port      = 9090
}
```

## Requirements

- FLO module deployed (provides F5BigAnalyzer CRD)
- Kubernetes cluster with F5 BNK 2.2 GA
- Early Access features enabled

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| cluster_name | string | yes | Name of the Kubernetes cluster |
| analyzer_name | string | yes | Name for the analyzer resource |
| analyzer_namespace | string | yes | Namespace for deployment |
| flo_ready | bool | yes | Dependency flag from FLO module |
| llm_workload_config | object | yes | LLM workload configuration |
| routing_algorithm | string | no | Routing algorithm (default: token-aware) |
| enable_metrics | bool | no | Enable metrics (default: true) |
| metrics_port | number | no | Metrics port (default: 9090) |

## LLM Workload Config

```hcl
llm_workload_config = {
  model_type        = "gpt"     # gpt, claude, llama, mistral, palm, other
  max_tokens        = 4096      # Maximum token limit per request
  context_window    = 8192      # Model context window size
  streaming_enabled = true      # Enable streaming responses
  batch_size        = 1         # Request batching size
}
```

## Routing Algorithms

- **token-aware**: Route based on token usage and backend capacity
- **latency-optimized**: Minimize response latency
- **cost-optimized**: Balance cost and performance
- **round-robin**: Simple round-robin distribution

## Supported Model Types

- **gpt**: OpenAI GPT models
- **claude**: Anthropic Claude models
- **llama**: Meta LLaMA models
- **mistral**: Mistral AI models
- **palm**: Google PaLM models
- **other**: Generic LLM workloads

## Outputs

| Name | Description |
|------|-------------|
| analyzer_ready | Flag indicating analyzer is ready |
| analyzer_name | Name of the created analyzer |
| analyzer_namespace | Namespace where analyzer is deployed |
| metrics_endpoint | Prometheus metrics endpoint URL |
| routing_algorithm | Configured routing algorithm |
| model_type | Configured LLM model type |

## Metrics

When enabled, exports Prometheus metrics on `/metrics`:
- Token usage per backend
- Request latency distribution
- Queue depth and wait times
- Model-specific performance metrics

## Dependencies

- **Required**: bnk/flo (provides CRDs)
- **Optional**: bnk/gateway (Gateway resources to optimize)

## Notes

- **EARLY ACCESS**: This feature is in Early Access (EA) stage
- Optimized for LLM/AI workload characteristics
- Token-aware routing considers both prompt and completion tokens
- Streaming support minimizes TTFB (Time To First Byte)
- Metrics integration for observability
- Deploy order: 95 (after gateways and routes)

## Use Cases

- LLM inference clusters
- Multi-model AI deployments
- OpenAI/Anthropic proxy services
- Self-hosted LLM APIs
- AI agent platforms
