# bnk-forge-modules/app/demo-irules/main.tf
# Demo iRules, HSL Publisher, and BNKNetPolicy attachments

# =============================================================================
# HSL PUBLISHER — Sends logs to Fluent Bit UDP
# =============================================================================

resource "kubernetes_manifest" "hsl_publisher" {
  depends_on = [var.gateway_ready]

  manifest = {
    apiVersion = "k8s.f5.com/v1"
    kind       = "F5BigLogHslpub"

    metadata = {
      name      = "demo-hsl-publisher"
      namespace = var.gateway_namespace
      labels = {
        "app.kubernetes.io/name"       = "demo-hsl-publisher"
        "app.kubernetes.io/component"  = "observability"
        "app.kubernetes.io/part-of"    = "bnk-demo"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }

    spec = {
      syslog = {
        format       = "rfc5424"
        protocol     = "udp"
        distribution = "adaptive"
      }
      pool = {
        members = [
          {
            address = "fluentbit-hsl-udp.${var.observability_namespace}.svc.cluster.local"
            port    = var.fluentbit_hsl_port
          }
        ]
      }
    }
  }
}

# =============================================================================
# REQUEST LOGGER iRULE — Logs every request/response via HSL
# =============================================================================

resource "kubernetes_manifest" "request_logger_irule" {
  depends_on = [var.gateway_ready]

  manifest = {
    apiVersion = "k8s.f5net.com/v1"
    kind       = "F5BigCneIrule"

    metadata = {
      name      = "demo-request-logger"
      namespace = var.gateway_namespace
      labels = {
        "app.kubernetes.io/name"       = "demo-request-logger"
        "app.kubernetes.io/component"  = "observability"
        "app.kubernetes.io/part-of"    = "bnk-demo"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }

    spec = {
      iRule = <<-IRULE
        when RULE_INIT {
          log local0. "Initializing BNK Demo Request Logger iRule"
        }

        when HTTP_REQUEST {
          set ::req_start [clock clicks -milliseconds]
          set ::req_method [HTTP::method]
          set ::req_path [HTTP::uri]
          set ::req_host [HTTP::header host]
          set ::req_user_agent [HTTP::header user-agent]
          set ::client_ip [IP::client_addr]
          set ::virtual_server [IP::local_addr]
        }

        when HTTP_RESPONSE {
          set elapsed [expr {[clock clicks -milliseconds] - $::req_start}]
          set status [HTTP::status]

          # Build JSON log message
          set log_msg [format {{"timestamp":"%s","method":"%s","path":"%s","status":"%s","client_ip":"%s","response_time_ms":"%s","user_agent":"%s","host":"%s","virtual_server":"%s"}} \
            [clock format [clock seconds] -format "%Y-%m-%dT%TZ" -gmt true] \
            $::req_method \
            $::req_path \
            $status \
            $::client_ip \
            $elapsed \
            $::req_user_agent \
            $::req_host \
            $::virtual_server]

          # Send via HSL to Fluent Bit
          set hsl [HSL::open -proto UDP -standalone fluentbit-hsl-udp.${var.observability_namespace}.svc.cluster.local:${var.fluentbit_hsl_port}]
          HSL::send $hsl $log_msg
        }
      IRULE
    }
  }
}

# =============================================================================
# BNK NET POLICY — Attach iRule to HTTP listener
# =============================================================================

resource "kubernetes_manifest" "netpolicy_http" {
  depends_on = [
    kubernetes_manifest.request_logger_irule,
    kubernetes_manifest.hsl_publisher,
  ]

  manifest = {
    apiVersion = "gateway.k8s.f5net.com/v1alpha1"
    kind       = "BNKNetPolicy"

    metadata = {
      name      = "demo-netpolicy-http"
      namespace = var.gateway_namespace
      labels = {
        "app.kubernetes.io/name"       = "demo-netpolicy-http"
        "app.kubernetes.io/component"  = "policy"
        "app.kubernetes.io/part-of"    = "bnk-demo"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }

    spec = {
      extensionRefs = [
        {
          group = "k8s.f5net.com"
          kind  = "F5BigCneIrule"
          name  = "demo-request-logger"
        }
      ]
      targetRefs = [
        {
          group       = "gateway.networking.k8s.io"
          kind        = "Gateway"
          name        = var.gateway_name
          sectionName = "http"
        }
      ]
    }
  }
}

# =============================================================================
# BNK NET POLICY — Attach iRule to HTTPS listener (if enabled)
# =============================================================================

resource "kubernetes_manifest" "netpolicy_https" {
  count = var.enable_https_listener ? 1 : 0

  depends_on = [
    kubernetes_manifest.request_logger_irule,
    kubernetes_manifest.hsl_publisher,
  ]

  manifest = {
    apiVersion = "gateway.k8s.f5net.com/v1alpha1"
    kind       = "BNKNetPolicy"

    metadata = {
      name      = "demo-netpolicy-https"
      namespace = var.gateway_namespace
      labels = {
        "app.kubernetes.io/name"       = "demo-netpolicy-https"
        "app.kubernetes.io/component"  = "policy"
        "app.kubernetes.io/part-of"    = "bnk-demo"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }

    spec = {
      extensionRefs = [
        {
          group = "k8s.f5net.com"
          kind  = "F5BigCneIrule"
          name  = "demo-request-logger"
        }
      ]
      targetRefs = [
        {
          group       = "gateway.networking.k8s.io"
          kind        = "Gateway"
          name        = var.gateway_name
          sectionName = "https"
        }
      ]
    }
  }
}

# =============================================================================
# BNK NET POLICY — Attach iRule to Smart listener (if enabled)
# =============================================================================

resource "kubernetes_manifest" "netpolicy_smart" {
  count = var.enable_smart_listener ? 1 : 0

  depends_on = [
    kubernetes_manifest.request_logger_irule,
    kubernetes_manifest.hsl_publisher,
  ]

  manifest = {
    apiVersion = "gateway.k8s.f5net.com/v1alpha1"
    kind       = "BNKNetPolicy"

    metadata = {
      name      = "demo-netpolicy-smart"
      namespace = var.gateway_namespace
      labels = {
        "app.kubernetes.io/name"       = "demo-netpolicy-smart"
        "app.kubernetes.io/component"  = "policy"
        "app.kubernetes.io/part-of"    = "bnk-demo"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }

    spec = {
      extensionRefs = [
        {
          group = "k8s.f5net.com"
          kind  = "F5BigCneIrule"
          name  = "demo-request-logger"
        }
      ]
      targetRefs = [
        {
          group       = "gateway.networking.k8s.io"
          kind        = "Gateway"
          name        = var.gateway_name
          sectionName = "smart"
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
    kubernetes_manifest.request_logger_irule,
    kubernetes_manifest.hsl_publisher,
    kubernetes_manifest.netpolicy_http,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying Demo iRules & Network Policies ==="
      kubectl get f5bigcneirule,f5bigloghslpub,bnknetpolicy -n ${var.gateway_namespace} -l app.kubernetes.io/part-of=bnk-demo 2>/dev/null || echo "Some CRDs may not be registered yet"
      echo "iRules verification complete"
    EOT
  }
}
