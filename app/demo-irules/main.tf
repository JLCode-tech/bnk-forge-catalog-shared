# bnk-forge-modules/app/demo-irules/main.tf
# iRules + BNKNetPolicy for BNK Demo — Token Counting HSL + SmartLLM Routing
#
# TCL code ported from proven Lanner PoC:
# - Token counting: lanner-bnk-poc/app/use-cases/uc1-llmaas/routing/70-irule-token-counting.yaml
# - SmartLLM:       lanner-bnk-poc/app/use-cases/uc1-llmaas/routing/71-irule-smartllm.yaml
#
# Validated against F5 BNK 2.2 docs (2026-02-12):
# - iRules: https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/bnk-irule-in-gatewayapi.html
# - BNKNetPolicy: https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/bnk-bnkNetPolicy.html
#
# CRITICAL: Max ONE BNKNetPolicy per listener (docs rule).
# - standard-http: 1 policy with token counting iRule
# - smart-http: 1 policy with BOTH token counting + SmartLLM iRules (merged)

locals {
  common_labels = {
    "app.kubernetes.io/component"  = "irule"
    "app.kubernetes.io/part-of"    = "bnk-demo"
    "app.kubernetes.io/managed-by" = "opentofu"
  }
}

# =============================================================================
# iRule 1: TOKEN COUNTING + HSL LOGGING
# Proven TCL from Lanner PoC — extracts OpenAI usage tokens from JSON response
# and sends structured telemetry via HSL UDP to Fluent Bit → Loki
# =============================================================================

resource "kubernetes_manifest" "token_counting_irule" {
  depends_on = [var.gateway_ready]

  manifest = {
    apiVersion = "k8s.f5net.com/v1"
    kind       = "F5BigCneIrule"

    metadata = {
      name      = "genai-token-hsl-irule"
      namespace = var.gateway_namespace
      labels = merge(local.common_labels, {
        "app.kubernetes.io/name" = "genai-token-hsl-irule"
      })
    }

    spec = {
      iRule = <<-IRULE
        when RULE_INIT {
          log local0. "Initializing Token Counting iRule"
        }
        proc jpath { e path {d .} } {
          if { [catch {set v [call jpath2 $e $path $d]} err] } { return "" }
          return $v
        }
        proc jpath2 { e path {d .} } {
          set parray [split $path $d]
          set plen [llength $parray]
          set i 0
          for {} {$i < [expr {$plen }]} {incr i} {
            set p [lindex $parray $i]
            set t [JSON::type $e]
            set v [JSON::get $e]
            if { $t eq "array" } {
              set e [JSON::array get $v $p]
            } else {
              set e [JSON::object get $v $p]
            }
          }
          set t [JSON::type $e]
          set v [JSON::get $e $t]
          return $v
        }
        when HTTP_REQUEST {
          set host [HTTP::header host]
          set endpoint [HTTP::uri]
          set authorization [HTTP::header authorization]
          set virtual_server [IP::local_addr]
        }
        when JSON_RESPONSE {
          set root [JSON::root]
          if { [call jpath $root usage] ne "" } {
            set model [call jpath $root model]
            set prompt [call jpath $root usage.prompt_tokens]
            set completion [call jpath $root usage.completion_tokens]
            set total [call jpath $root usage.total_tokens]
            set timestamp [clock format [clock seconds] -format "%Y-%m-%dT%TZ" -gmt true]
            set status [HTTP::status]
            set ip_address [IP::client_addr]
            set jc [JSON::create]
            set jr [JSON::root $jc]
            set ele [JSON::set $jr object ""]
            set obj [JSON::get $jr object]
            JSON::object add $obj timestamp string $timestamp
            JSON::object add $obj authorization string $authorization
            JSON::object add $obj model string $model
            JSON::object add $obj endpoint string $endpoint
            JSON::object add $obj input_token string $prompt
            JSON::object add $obj output_token string $completion
            JSON::object add $obj total_token string $total
            JSON::object add $obj status string $status
            JSON::object add $obj ip_address string $ip_address
            JSON::object add $obj domain string $host
            JSON::object add $obj virtual_server string $virtual_server
            set js_msg [JSON::render $jc]
            # HSL to Fluent Bit UDP -> Loki
            set hsl [HSL::open -proto UDP -standalone ${var.fluentbit_hsl_endpoint}]
            HSL::send $hsl $js_msg
          }
        }
      IRULE
    }
  }
}

# =============================================================================
# iRule 2: SMARTLLM ROUTING (Optional — only if smart listener enabled)
# Proven TCL from Lanner PoC — sideband classifier, weighted complexity,
# model selection, per-user token quota enforcement
#
# Adapted for AWS: model names configurable, single pool (LiteLLM handles
# model routing), removed pool commands (both models go to same LiteLLM svc)
# =============================================================================

resource "kubernetes_manifest" "smartllm_routing_irule" {
  count      = var.enable_smart_listener ? 1 : 0
  depends_on = [var.gateway_ready]

  manifest = {
    apiVersion = "k8s.f5net.com/v1"
    kind       = "F5BigCneIrule"

    metadata = {
      name      = "genai-llm-route-irule"
      namespace = var.gateway_namespace
      labels = merge(local.common_labels, {
        "app.kubernetes.io/name" = "genai-llm-route-irule"
      })
    }

    spec = {
      iRule = <<-IRULE
        when RULE_INIT {
          set static::classifier_host "${var.classifier_host}"
          set static::classifier_port ${var.classifier_port}
          set static::complex_model "${var.complex_model_name}"
          set static::simple_model "${var.simple_model_name}"
          set static::complexity_threshold ${var.complexity_threshold}
          set static::timeout 120
          set static::lifetime 7200
          set static::token_limit ${var.token_quota_limit}
        }
        proc jpath { e path {d .} } {
          if { [catch {set v [call jpath2 $e $path $d]} err] } { return "" }
          return $v
        }
        proc jpath2 { e path {d .} } {
          set parray [split $path $d]
          set plen [llength $parray]
          set i 0
          for {} {$i < [expr {$plen }]} {incr i} {
            set p [lindex $parray $i]
            set t [JSON::type $e]
            set v [JSON::get $e]
            if { $t eq "array" } {
              set e [JSON::array get $v $p]
            } else {
              set e [JSON::object get $v $p]
            }
          }
          set t [JSON::type $e]
          set v [JSON::get $e $t]
          return $v
        }
        when HTTP_REQUEST {
          set authorization [HTTP::header authorization]
          if {[HTTP::header exists "Content-Length"]} {
            set content_length [HTTP::header "Content-Length"]
            if { $content_length < 131072 } { HTTP::collect $content_length } else { reject }
          }
          set total_count [table lookup -notouch -subtable "tokens_map_total" $authorization]
          if {$total_count ne "" && $total_count > $static::token_limit} {
            set ::quota_exceeded 1
          } else {
            set ::quota_exceeded 0
          }
        }
        when HTTP_REQUEST_DATA {
          set raw_payload [HTTP::payload]
          if {$::quota_exceeded eq "1"} {
            set llm_model $static::simple_model
            set model_tier "simple"
          } else {
            set prompt_content ""
            if {[string first "messages" $raw_payload] >= 0} {
              set prompt_content [findstr $raw_payload {"content":"} 11 {"}]
            } else {
              set prompt_content [findstr $raw_payload {"prompt":"} 10 {"}]
            }
            set classifier_payload [subst {{"prompt": "$prompt_content"}}]
            set len [string length $classifier_payload]
            set infer_hdr "POST /predict HTTP/1.1\r\nHost: $static::classifier_host\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: $len\r\n\r\n"
            set sb [connect -protocol TCP "$static::classifier_host:$static::classifier_port"]
            send $sb $infer_hdr$classifier_payload
            set bytes [recv -peek $sb resp]
            close $sb
            set task_type [findstr $resp {"task_type":"} 13 {"}]
            set creativity [findstr $resp {"creativity":} 13 {,}]
            set reasoning [findstr $resp {"reasoning":} 12 {,}]
            set constraint [findstr $resp {"constraint":} 13 {,}]
            set domain_knowledge [findstr $resp {"domain_knowledge":} 19 {,}]
            set contextual_knowledge [findstr $resp {"contextual_knowledge":} 23 {,}]
            set few_shots [findstr $resp {"few_shots":} 12 {}}]
            if {![string is double -strict $creativity]} { set creativity 0.0 }
            if {![string is double -strict $reasoning]} { set reasoning 0.0 }
            if {![string is double -strict $constraint]} { set constraint 0.0 }
            if {![string is double -strict $domain_knowledge]} { set domain_knowledge 0.0 }
            if {![string is double -strict $contextual_knowledge]} { set contextual_knowledge 0.0 }
            if {![string is double -strict $few_shots]} { set few_shots 0.0 }
            set weighted_complexity [expr {
              ($creativity * 0.35) +
              ($reasoning * 0.25) +
              ($constraint * 0.15) +
              ($domain_knowledge * 0.15) +
              ($contextual_knowledge * 0.05) +
              ($few_shots * 0.05)
            }]
            switch $task_type {
              "Code Generation" {
                set llm_model $static::complex_model
                set model_tier "complex"
              }
              "Summarization" {
                set llm_model $static::simple_model
                set model_tier "simple"
              }
              "Rewrite" {
                set llm_model $static::simple_model
                set model_tier "simple"
              }
              default {
                if {$weighted_complexity > $static::complexity_threshold} {
                  set llm_model $static::complex_model
                  set model_tier "complex"
                } else {
                  set llm_model $static::simple_model
                  set model_tier "simple"
                }
              }
            }
          }
          # Rewrite the model field in the JSON payload — LiteLLM routes based on model name
          set new_payload $raw_payload
          if {[regsub {"model"\s*:\s*"[^"]*"} $raw_payload [subst {"model":"$llm_model"}] new_payload] == 0} {
            set new_payload [string map [list "\{" [subst {{"model":"$llm_model",}]] $raw_payload]
          }
          HTTP::payload replace 0 [HTTP::payload length] $new_payload
          # No pool selection needed — both models go to same litellm-proxy backend via HTTPRoute
        }
        when HTTP_RESPONSE {
          HTTP::collect 65535
        }
        when HTTP_RESPONSE_DATA {
          set payload [HTTP::payload]
          set total_ctokens [findstr $payload {"total_tokens":} 15 "\x7d"]
          set total_ctokens [string trim $total_ctokens]
          if {![string is integer -strict $total_ctokens]} { return }
          set total_ntokens [expr {$total_ctokens}]
          set total_count [table lookup -notouch -subtable "tokens_map_total" $authorization]
          if {$total_count eq ""} { set total_count $total_ntokens } else { incr total_count $total_ntokens }
          table set -subtable "tokens_map_total" $authorization $total_count $static::timeout $static::lifetime
        }
      IRULE
    }
  }
}

# =============================================================================
# BNKNetPolicy 1: Token counting → standard-http listener ONLY
# =============================================================================

resource "kubernetes_manifest" "token_hsl_standard_netpolicy" {
  depends_on = [
    kubernetes_manifest.token_counting_irule,
    var.gateway_ready,
  ]

  manifest = {
    apiVersion = "gateway.k8s.f5net.com/v1alpha1"
    kind       = "BNKNetPolicy"

    metadata = {
      name      = "token-hsl-standard-netpolicy"
      namespace = var.gateway_namespace
      labels = merge(local.common_labels, {
        "app.kubernetes.io/name" = "token-hsl-standard-netpolicy"
      })
    }

    spec = {
      extensionRefs = [
        {
          group = "k8s.f5net.com"
          kind  = "F5BigCneIrule"
          name  = "genai-token-hsl-irule"
        }
      ]
      targetRefs = [
        {
          group       = "gateway.networking.k8s.io"
          kind        = "Gateway"
          name        = var.gateway_name
          sectionName = "standard-http"
        }
      ]
    }
  }
}

# =============================================================================
# BNKNetPolicy 2: BOTH iRules → smart-http listener (merged into single policy)
# CRITICAL: F5 docs say max 1 BNKNetPolicy per listener. extensionRefs supports
# up to 8 items, so we merge both iRules into one policy.
# =============================================================================

resource "kubernetes_manifest" "smart_combined_netpolicy" {
  count = var.enable_smart_listener ? 1 : 0
  depends_on = [
    kubernetes_manifest.token_counting_irule,
    kubernetes_manifest.smartllm_routing_irule,
    var.gateway_ready,
  ]

  manifest = {
    apiVersion = "gateway.k8s.f5net.com/v1alpha1"
    kind       = "BNKNetPolicy"

    metadata = {
      name      = "smart-combined-netpolicy"
      namespace = var.gateway_namespace
      labels = merge(local.common_labels, {
        "app.kubernetes.io/name" = "smart-combined-netpolicy"
      })
    }

    spec = {
      extensionRefs = [
        {
          group = "k8s.f5net.com"
          kind  = "F5BigCneIrule"
          name  = "genai-token-hsl-irule"
        },
        {
          group = "k8s.f5net.com"
          kind  = "F5BigCneIrule"
          name  = "genai-llm-route-irule"
        }
      ]
      targetRefs = [
        {
          group       = "gateway.networking.k8s.io"
          kind        = "Gateway"
          name        = var.gateway_name
          sectionName = "smart-http"
        }
      ]
    }
  }
}

# =============================================================================
# VERIFICATION
# =============================================================================

resource "null_resource" "verify_irules" {
  depends_on = [
    kubernetes_manifest.token_hsl_standard_netpolicy,
    kubernetes_manifest.smart_combined_netpolicy,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying iRules ==="
      kubectl get f5bigcneirules -n ${var.gateway_namespace} -l app.kubernetes.io/part-of=bnk-demo 2>/dev/null || echo "No iRules found (CRD may use different plural)"
      echo ""
      echo "=== Verifying BNKNetPolicies ==="
      kubectl get bnknetpolicies -n ${var.gateway_namespace} -l app.kubernetes.io/part-of=bnk-demo 2>/dev/null || echo "No policies found"
      echo ""
      echo "=== BNKNetPolicy Status ==="
      for policy in token-hsl-standard-netpolicy smart-combined-netpolicy; do
        echo "--- $policy ---"
        kubectl get bnknetpolicy $policy -n ${var.gateway_namespace} -o jsonpath='{.status}' 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "not found or no status"
      done
      echo ""
      echo "iRules verification complete"
    EOT
  }
}
