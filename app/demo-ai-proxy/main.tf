# bnk-forge-modules/app/demo-ai-proxy/main.tf
# AI LLM Proxy — LiteLLM (OpenAI-compatible) proxying to AWS Bedrock
# Auth: IRSA (IAM Roles for Service Accounts) — no API keys needed
# Metrics: Prometheus scrapes LiteLLM /metrics endpoint

# =============================================================================
# LOCALS
# =============================================================================

locals {
  ai_namespace = var.app_namespace

  # Bedrock model mapping — LiteLLM uses "bedrock/<model-id>" format
  # We deploy two "backends" with different model tiers for the Analyzer
  # to route between (simulating the NIM multi-model pattern on Bedrock)
  litellm_models = [
    {
      model_name = "smart-model"
      litellm_params = {
        model           = "bedrock/${var.bedrock_smart_model_id}"
        aws_region_name = var.aws_region
      }
    },
    {
      model_name = "fast-model"
      litellm_params = {
        model           = "bedrock/${var.bedrock_fast_model_id}"
        aws_region_name = var.aws_region
      }
    }
  ]
}

# =============================================================================
# LITELLM CONFIG — Bedrock model routing
# =============================================================================

resource "kubernetes_config_map_v1" "litellm_config" {
  depends_on = [var.namespaces_ready]

  metadata {
    name      = "litellm-config"
    namespace = local.ai_namespace
    labels = {
      "app.kubernetes.io/name"       = "litellm-config"
      "app.kubernetes.io/component"  = "ai-proxy"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  data = {
    "config.yaml" = yamlencode({
      model_list = local.litellm_models

      litellm_settings = {
        # Enable Prometheus metrics on /metrics
        success_callback = ["prometheus"]
        failure_callback = ["prometheus"]

        # General settings
        drop_params     = true
        set_verbose     = false
        request_timeout = 120
      }

      general_settings = {
        master_key = "sk-demo-not-secret"
      }
    })
  }
}

# =============================================================================
# SERVICE ACCOUNT — annotated for IRSA (Bedrock access)
# =============================================================================

resource "kubernetes_service_account_v1" "litellm" {
  depends_on = [var.namespaces_ready]

  metadata {
    name      = "litellm-proxy"
    namespace = local.ai_namespace
    labels = {
      "app.kubernetes.io/name"       = "litellm-proxy"
      "app.kubernetes.io/component"  = "ai-proxy"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
    # IRSA annotation — links to the IAM role that has bedrock:InvokeModel
    annotations = var.bedrock_iam_role_arn != "" ? {
      "eks.amazonaws.com/role-arn" = var.bedrock_iam_role_arn
    } : {}
  }
}

# =============================================================================
# LITELLM DEPLOYMENT
# =============================================================================

resource "kubernetes_deployment_v1" "litellm" {
  depends_on = [
    kubernetes_config_map_v1.litellm_config,
    kubernetes_service_account_v1.litellm,
  ]

  metadata {
    name      = "litellm-proxy"
    namespace = local.ai_namespace
    labels = {
      "app.kubernetes.io/name"       = "litellm-proxy"
      "app.kubernetes.io/component"  = "ai-proxy"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  spec {
    replicas = var.litellm_replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "litellm-proxy"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "litellm-proxy"
          "app.kubernetes.io/component" = "ai-proxy"
          "app.kubernetes.io/part-of"   = "bnk-demo"
        }
        annotations = {
          # Prometheus auto-discovery
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "4000"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.litellm.metadata[0].name

        container {
          name  = "litellm"
          image = var.litellm_image

          args = ["--config", "/app/config.yaml", "--port", "4000"]

          port {
            container_port = 4000
            name           = "http"
            protocol       = "TCP"
          }

          env {
            name  = "LITELLM_MASTER_KEY"
            value = "sk-demo-not-secret"
          }

          # AWS region for Bedrock — IRSA provides credentials automatically
          env {
            name  = "AWS_DEFAULT_REGION"
            value = var.aws_region
          }

          volume_mount {
            name       = "config"
            mount_path = "/app/config.yaml"
            sub_path   = "config.yaml"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health/liveliness"
              port = 4000
            }
            initial_delay_seconds = 15
            period_seconds        = 30
            timeout_seconds       = 5
          }

          readiness_probe {
            http_get {
              path = "/health/readiness"
              port = 4000
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.litellm_config.metadata[0].name
          }
        }
      }
    }
  }
}

# =============================================================================
# LITELLM SERVICE — OpenAI-compatible API
# =============================================================================

resource "kubernetes_service_v1" "litellm" {
  metadata {
    name      = "litellm-proxy"
    namespace = local.ai_namespace
    labels = {
      "app.kubernetes.io/name"       = "litellm-proxy"
      "app.kubernetes.io/component"  = "ai-proxy"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "litellm-proxy"
    }

    port {
      name        = "http"
      port        = 4000
      target_port = 4000
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# =============================================================================
# PROMETHEUS — scrapes LiteLLM metrics for F5BigAnalyzer
# =============================================================================

resource "kubernetes_config_map_v1" "prometheus_config" {
  depends_on = [var.namespaces_ready]

  metadata {
    name      = "prometheus-config"
    namespace = local.ai_namespace
    labels = {
      "app.kubernetes.io/name"       = "prometheus"
      "app.kubernetes.io/component"  = "metrics"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  data = {
    "prometheus.yml" = yamlencode({
      global = {
        scrape_interval     = "15s"
        evaluation_interval = "15s"
      }

      scrape_configs = [
        {
          job_name = "litellm"
          static_configs = [
            {
              targets = ["litellm-proxy.${local.ai_namespace}.svc.cluster.local:4000"]
              labels = {
                service = "litellm-proxy"
              }
            }
          ]
          metrics_path    = "/metrics"
          scrape_interval = "10s"
        }
      ]
    })
  }
}

resource "kubernetes_deployment_v1" "prometheus" {
  depends_on = [kubernetes_config_map_v1.prometheus_config]

  metadata {
    name      = "prometheus"
    namespace = local.ai_namespace
    labels = {
      "app.kubernetes.io/name"       = "prometheus"
      "app.kubernetes.io/component"  = "metrics"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "prometheus"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "prometheus"
          "app.kubernetes.io/component" = "metrics"
          "app.kubernetes.io/part-of"   = "bnk-demo"
        }
      }

      spec {
        container {
          name  = "prometheus"
          image = "prom/prometheus:v2.51.0"

          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus",
            "--storage.tsdb.retention.time=3d",
            "--web.enable-lifecycle",
          ]

          port {
            container_port = 9090
            name           = "http"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/prometheus/prometheus.yml"
            sub_path   = "prometheus.yml"
          }

          volume_mount {
            name       = "data"
            mount_path = "/prometheus"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/-/healthy"
              port = 9090
            }
            initial_delay_seconds = 10
            period_seconds        = 15
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.prometheus_config.metadata[0].name
          }
        }

        volume {
          name = "data"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "prometheus" {
  metadata {
    name      = "prometheus-service"
    namespace = local.ai_namespace
    labels = {
      "app.kubernetes.io/name"       = "prometheus"
      "app.kubernetes.io/component"  = "metrics"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "prometheus"
    }

    port {
      name        = "http"
      port        = 9090
      target_port = 9090
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# =============================================================================
# AI HTTPROUTE — /v1/chat → LiteLLM proxy on smart listener
# =============================================================================

resource "kubernetes_manifest" "ai_route" {
  count      = var.enable_ai_route ? 1 : 0
  depends_on = [var.gateway_ready]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"

    metadata = {
      name      = "ai-chat-route"
      namespace = var.gateway_namespace
      labels = {
        "app.kubernetes.io/name"       = "ai-chat-route"
        "app.kubernetes.io/component"  = "routing"
        "app.kubernetes.io/part-of"    = "bnk-demo"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }

    spec = {
      parentRefs = [
        {
          name        = var.gateway_name
          sectionName = "smart"
        }
      ]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/v1/chat"
              }
            }
          ]
          backendRefs = [
            {
              name      = "litellm-proxy"
              namespace = local.ai_namespace
              port      = 4000
              weight    = 1
            }
          ]
        },
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/v1/models"
              }
            }
          ]
          backendRefs = [
            {
              name      = "litellm-proxy"
              namespace = local.ai_namespace
              port      = 4000
              weight    = 1
            }
          ]
        }
      ]
    }
  }
}

# =============================================================================
# VERIFICATION
# =============================================================================

resource "null_resource" "verify_ai_proxy" {
  depends_on = [
    kubernetes_deployment_v1.litellm,
    kubernetes_deployment_v1.prometheus,
    kubernetes_service_v1.litellm,
    kubernetes_service_v1.prometheus,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying AI Proxy Stack ==="
      kubectl get deployments,services -n ${local.ai_namespace} -l app.kubernetes.io/part-of=bnk-demo,app.kubernetes.io/component=ai-proxy
      kubectl get deployments,services -n ${local.ai_namespace} -l app.kubernetes.io/part-of=bnk-demo,app.kubernetes.io/component=metrics
      echo "=== Checking LiteLLM readiness ==="
      kubectl rollout status deployment/litellm-proxy -n ${local.ai_namespace} --timeout=120s || echo "LiteLLM not ready yet — may need Bedrock IAM role"
      echo "AI Proxy verification complete"
    EOT
  }
}
