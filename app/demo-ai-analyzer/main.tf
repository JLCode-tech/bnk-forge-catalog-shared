# bnk-forge-modules/app/demo-ai-analyzer/main.tf
# AI Analyzer — F5BigAnalyzer CR, custom Bedrock-aware script, token counting iRule
#
# Architecture (adapted from NIM/DPU to AWS Bedrock):
#   Lanner (on-prem):  NIM GPU metrics → Prometheus → builtin LLMLoadMonitor
#   AWS (this module): LiteLLM Bedrock proxy metrics → Prometheus → custom script
#
# The custom script reads LiteLLM Prometheus metrics:
#   - litellm_request_total_latency_metric (request latency per model)
#   - litellm_requests_metric (request count per model/status)
#   - litellm_tokens (token counts per model)
# And adjusts HTTPRoute backend weights so BNK TMM distributes AI traffic
# to the least-loaded LiteLLM proxy replica.

# =============================================================================
# CUSTOM ANALYZER SCRIPT (ConfigMap)
# =============================================================================

resource "kubernetes_config_map_v1" "analyzer_script" {
  depends_on = [var.ai_proxy_ready]

  metadata {
    name      = "bedrock-analyzer-scripts"
    namespace = var.gateway_namespace
    labels = {
      "app"                          = "analyzer-scripts"
      "app.kubernetes.io/name"       = "bedrock-analyzer-scripts"
      "app.kubernetes.io/component"  = "ai-analyzer"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  data = {
    "bedrock-analyzer.py" = <<-PYTHON
#!/usr/bin/env python3
"""
F5 BNK Analyzer — Custom script for AWS Bedrock via LiteLLM proxy.

Adapted from the NIM/DPU builtin LLMLoadMonitor for cloud-native Bedrock:
- Queries Prometheus for LiteLLM proxy metrics (latency, errors, tokens)
- Calculates optimal traffic weights per pool member (LiteLLM replica)
- Returns weights via F5 JSON Schema Interface

Unlike NIM (GPU utilization metrics), Bedrock is serverless — we balance
based on proxy-level signals: request latency, error rates, and throughput.

JSON Schema Interface:
  stdin:  {"action": "init|run|cleanup", "pool_member_ips": [...], ...}
  stdout: {"status": "success|error", "weights": {"ip": weight}, "state": {...}}
  stderr: debug/logging only (NEVER print to stdout)
"""

import sys
import json
import urllib.request
import urllib.parse
from datetime import datetime, timezone


def log(msg):
    """Log to stderr only — stdout is reserved for JSON response."""
    print(f"[bedrock-analyzer] {msg}", file=sys.stderr)


def query_prometheus(endpoint, query, username=None, password=None):
    """Query Prometheus and return the result vector."""
    url = f"{endpoint}/api/v1/query?query={urllib.parse.quote(query)}"
    req = urllib.request.Request(url)

    if username and password:
        import base64
        credentials = base64.b64encode(f"{username}:{password}".encode()).decode()
        req.add_header("Authorization", f"Basic {credentials}")

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
            if data.get("status") == "success":
                return data.get("data", {}).get("result", [])
    except Exception as e:
        log(f"Prometheus query failed: {e}")
    return []


def get_latency_per_pod(endpoint, username=None, password=None):
    """Get average request latency per LiteLLM pod IP over last 5 minutes."""
    query = (
        'avg by (instance) ('
        '  rate(litellm_request_total_latency_metric_bucket{le="30"}[5m])'
        ')'
    )
    results = query_prometheus(endpoint, query, username, password)
    latencies = {}
    for r in results:
        instance = r.get("metric", {}).get("instance", "")
        # Extract IP from instance (format: "ip:port")
        ip = instance.split(":")[0] if ":" in instance else instance
        val = float(r.get("value", [0, 0])[1])
        if ip:
            latencies[ip] = val
    return latencies


def get_error_rate_per_pod(endpoint, username=None, password=None):
    """Get error rate per LiteLLM pod IP over last 5 minutes."""
    query = (
        'sum by (instance) ('
        '  rate(litellm_requests_metric{status_code=~"5.."}[5m])'
        ') / '
        'sum by (instance) ('
        '  rate(litellm_requests_metric[5m])'
        ')'
    )
    results = query_prometheus(endpoint, query, username, password)
    errors = {}
    for r in results:
        instance = r.get("metric", {}).get("instance", "")
        ip = instance.split(":")[0] if ":" in instance else instance
        val = float(r.get("value", [0, 0])[1])
        # NaN means no errors (0/0)
        if ip:
            errors[ip] = val if val == val else 0.0  # NaN check
    return errors


def calculate_weights(pool_member_ips, latencies, error_rates):
    """
    Calculate traffic weights based on latency and error rate.
    Lower latency + lower error rate = higher weight (more traffic).
    Weights sum to 100.
    """
    n = len(pool_member_ips)
    if n == 0:
        return {}

    # If no metrics yet, distribute equally
    if not latencies and not error_rates:
        equal_weight = 100 // n
        weights = {ip: equal_weight for ip in pool_member_ips}
        # Distribute remainder
        remainder = 100 - (equal_weight * n)
        for i, ip in enumerate(pool_member_ips):
            if i < remainder:
                weights[ip] += 1
        return weights

    # Score each member: lower score = better = more traffic
    scores = {}
    for ip in pool_member_ips:
        latency = latencies.get(ip, 0.5)  # default 0.5s if no data
        error_rate = error_rates.get(ip, 0.0)

        # Combined score: latency (70% weight) + error_rate penalty (30%)
        # Clamp latency to [0.01, 30] to avoid division issues
        latency = max(0.01, min(30.0, latency))
        score = (latency * 0.7) + (error_rate * 10.0 * 0.3)
        scores[ip] = max(0.01, score)

    # Invert scores (lower score = higher weight)
    inverse_scores = {ip: 1.0 / score for ip, score in scores.items()}
    total_inverse = sum(inverse_scores.values())

    # Normalize to sum to 100
    weights = {}
    for ip in pool_member_ips:
        raw = (inverse_scores.get(ip, 0) / total_inverse) * 100
        weights[ip] = max(1, int(round(raw)))  # minimum weight of 1

    # Adjust to ensure sum is exactly 100
    current_sum = sum(weights.values())
    if current_sum != 100:
        diff = 100 - current_sum
        # Add/subtract from the member with highest weight
        max_ip = max(weights, key=weights.get)
        weights[max_ip] += diff

    return weights


def handle_init():
    """Initialization — nothing needed for Bedrock."""
    return {
        "status": "success",
        "message": "Bedrock analyzer initialized",
        "state": {
            "last_run_timestamp": datetime.now(timezone.utc).isoformat()
        }
    }


def handle_cleanup():
    """Cleanup — nothing to clean up."""
    return {
        "status": "success",
        "message": "Bedrock analyzer cleaned up",
        "state": {
            "last_run_timestamp": datetime.now(timezone.utc).isoformat()
        }
    }


def handle_run(request):
    """Main execution — query Prometheus, calculate weights."""
    pool_member_ips = request.get("pool_member_ips", [])
    pod_ip_mapping = request.get("pod_ip_mapping", {})
    data_source = request.get("data_source", {})

    endpoint = data_source.get("endpoint", "")
    username = data_source.get("username")
    password = data_source.get("password")

    if not endpoint:
        return {
            "status": "error",
            "message": "No Prometheus endpoint configured in dataSources"
        }

    if not pool_member_ips:
        return {
            "status": "error",
            "message": "No pool member IPs provided"
        }

    # Handle both flat list and object-per-pool formats
    if isinstance(pool_member_ips, list):
        ips = pool_member_ips
    elif isinstance(pool_member_ips, dict):
        ips = []
        for pool_name, pool_info in pool_member_ips.items():
            ips.extend(pool_info.get("member_ips", []))
    else:
        ips = []

    log(f"Pool members: {ips}")
    log(f"Prometheus endpoint: {endpoint}")

    # Collect metrics
    latencies = get_latency_per_pod(endpoint, username, password)
    error_rates = get_error_rate_per_pod(endpoint, username, password)

    log(f"Latencies: {latencies}")
    log(f"Error rates: {error_rates}")

    # Calculate weights
    weights = calculate_weights(ips, latencies, error_rates)

    log(f"Calculated weights: {weights}")

    return {
        "status": "success",
        "message": f"Weights calculated for {len(ips)} pool members",
        "weights": weights,
        "state": {
            "last_run_timestamp": datetime.now(timezone.utc).isoformat(),
            "custom_plugin_state": {
                "latencies": json.dumps(latencies),
                "error_rates": json.dumps(error_rates)
            }
        }
    }


def main():
    """Entry point — read JSON from stdin, dispatch action, write JSON to stdout."""
    try:
        raw = sys.stdin.read()
        request = json.loads(raw)
    except Exception as e:
        log(f"Failed to parse input: {e}")
        json.dump({"status": "error", "message": f"Invalid input: {e}"}, sys.stdout)
        sys.exit(1)

    action = request.get("action", "")

    if action == "init":
        response = handle_init()
    elif action == "run":
        response = handle_run(request)
    elif action == "cleanup":
        response = handle_cleanup()
    else:
        response = {"status": "error", "message": f"Unknown action: {action}"}

    json.dump(response, sys.stdout)


if __name__ == "__main__":
    main()
    PYTHON
  }
}

# =============================================================================
# F5BigAnalyzer CR — AI Intelligent Load Balancing
# =============================================================================

resource "kubernetes_manifest" "analyzer" {
  depends_on = [kubernetes_config_map_v1.analyzer_script]

  manifest = {
    apiVersion = "k8s.f5net.com/v1alpha1"
    kind       = "F5BigAnalyzer"

    metadata = {
      name      = "demo-bedrock-analyzer"
      namespace = var.gateway_namespace
      labels = {
        "app.kubernetes.io/name"       = "demo-bedrock-analyzer"
        "app.kubernetes.io/component"  = "ai-analyzer"
        "app.kubernetes.io/part-of"    = "bnk-demo"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }

    spec = {
      name = "demo-bedrock-analyzer"

      # Monitor the AI HTTPRoute — Analyzer adjusts weights on this route's backendRefs
      applications = [
        {
          name      = "ai-chat-route"
          kind      = "HTTPRoute"
          group     = "gateway.networking.k8s.io"
          namespace = var.gateway_namespace
        }
      ]

      # Custom script — reads Prometheus metrics from LiteLLM proxy
      script = {
        type = "custom"
        custom = {
          configMapRef = {
            name = "bedrock-analyzer-scripts"
            key  = "bedrock-analyzer.py"
          }
          # Pass Bedrock-specific params to the script
          parameters = [
            {
              key   = "smart_model"
              value = var.bedrock_smart_model_id
            },
            {
              key   = "fast_model"
              value = var.bedrock_fast_model_id
            }
          ]
        }
      }

      # Prometheus data source — scrapes LiteLLM metrics
      dataSources = [
        {
          name     = "litellm-prometheus"
          endpoint = var.prometheus_endpoint
        }
      ]

      # Run every 1 minute (same as NIM demo)
      schedule = "${var.analyzer_schedule}"
    }
  }
}

# =============================================================================
# AI TOKEN COUNTING iRULE — BNK 2.2 Compatible
# =============================================================================
#
# Parses OpenAI-format JSON responses from LiteLLM and logs token usage as
# structured key=value syslog via TMM log local0. Fluent Bit collects TMM logs
# and forwards to Loki.
#
# BNK 2.2 webhook (f5validate.f5net.com) restrictions discovered via testing:
#   - proc/call: NOT supported (webhook does static analysis, can't resolve vars)
#   - JSON:: API: Only works in simple inline form, NOT inside procs
#   - HSL::open -standalone: NOT supported (webhook expects -pool)
#   - HSL::open -pool: Also rejected in practice
#   - ne/eq operators: NOT supported in expr context
#   - JSON_RESPONSE: IS supported (but JSON:: API inside procs fails)
#   - HTTP_RESPONSE + HTTP::collect + HTTP_RESPONSE_DATA: WORKS
#   - findstr: WORKS for JSON field extraction
#   - log local0.: WORKS
#
# Strategy: Use HTTP_RESPONSE_DATA with findstr to extract token counts from
# the response payload, then emit structured log via log local0. for Fluent Bit.

resource "kubernetes_manifest" "token_counting_irule" {
  count      = var.enable_token_irule ? 1 : 0
  depends_on = [var.ai_proxy_ready]

  manifest = {
    apiVersion = "k8s.f5net.com/v1"
    kind       = "F5BigCneIrule"

    metadata = {
      name      = "demo-ai-token-counter"
      namespace = var.gateway_namespace
      labels = {
        "app.kubernetes.io/name"       = "demo-ai-token-counter"
        "app.kubernetes.io/component"  = "ai-analyzer"
        "app.kubernetes.io/part-of"    = "bnk-demo"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }

    spec = {
      # BNK 2.2 webhook-compatible iRule: no procs, no JSON:: in procs,
      # no HSL::open, no ne/eq operators. Uses HTTP_RESPONSE_DATA + findstr.
      iRule = chomp(<<-EOT
when RULE_INIT {
  log local0. {BNK AI Token Counter v2.0 initialized (BNK 2.2 compatible)}
}
when HTTP_REQUEST {
  set host [HTTP::header host]
  set endpoint [HTTP::uri]
  set virtual_server [IP::local_addr]
  set ip_address [IP::client_addr]
}
when HTTP_RESPONSE {
  HTTP::collect [HTTP::header Content-Length]
}
when HTTP_RESPONSE_DATA {
  set payload [HTTP::payload]
  set status [HTTP::status]
  set timestamp [clock format [clock seconds] -format {%Y-%m-%dT%TZ} -gmt true]
  set total_tokens [findstr $payload {"total_tokens":} 15 ,]
  set prompt_tokens [findstr $payload {"prompt_tokens":} 16 ,]
  set completion_tokens [findstr $payload {"completion_tokens":} 20 ,]
  set model_val [findstr $payload {"model":"} 9 "\""]
  set total_tokens [string trim $total_tokens]
  set prompt_tokens [string trim $prompt_tokens]
  set completion_tokens [string trim $completion_tokens]
  set model_val [string trim $model_val]
  log local0. "AI_TOKEN_USAGE timestamp=$timestamp model=$model_val endpoint=$endpoint input_tokens=$prompt_tokens output_tokens=$completion_tokens total_tokens=$total_tokens status=$status client_ip=$ip_address domain=$host virtual_server=$virtual_server provider=aws-bedrock"
  HTTP::release
}
EOT
      )
    }
  }
}

# =============================================================================
# BNK NET POLICY — REMOVED
# =============================================================================
# The BNKNetPolicy for the smart-http listener is created by demo-irules module
# (smart-combined-netpolicy). F5 BNK enforces MAX 1 BNKNetPolicy per listener.
#
# If you want to attach the AI token counter iRule to the smart listener, add it
# to the demo-irules module's smart-combined-netpolicy extensionRefs instead.
#
# The token counting iRule CR (demo-ai-token-counter) is still created above —
# it just needs to be referenced from demo-irules' BNKNetPolicy to be active.

# =============================================================================
# VERIFICATION
# =============================================================================

resource "null_resource" "verify_analyzer" {
  depends_on = [
    kubernetes_manifest.analyzer,
    kubernetes_config_map_v1.analyzer_script,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying AI Analyzer ==="
      kubectl get f5biganalyzer -n ${var.gateway_namespace} 2>/dev/null || echo "F5BigAnalyzer CRD may not be registered (requires intelligentLB=true in CNEInstance)"
      kubectl get configmap bedrock-analyzer-scripts -n ${var.gateway_namespace} -o jsonpath='{.metadata.labels}' 2>/dev/null || echo "Analyzer script ConfigMap not found"
      echo "=== Checking for token counter iRule ==="
      kubectl get f5bigcneirule demo-ai-token-counter -n ${var.gateway_namespace} 2>/dev/null || echo "Token counter iRule not found"
      echo "NOTE: Token counter iRule must be added to demo-irules smart-combined-netpolicy to be active"
      echo "=== Checking for Analyzer pod ==="
      kubectl get pods -n f5-operator -l app.kubernetes.io/name=f5-analyzer 2>/dev/null || echo "Analyzer pod not running (requires intelligentLB=true in CNEInstance)"
      echo "AI Analyzer verification complete"
    EOT
  }
}
