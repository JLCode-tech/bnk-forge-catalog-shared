###############################################################################
# app/bedrock-smartllm-backend — module main
#
# Deploys three single-model Bedrock shim pods (one per Bedrock model),
# each exposing an OpenAI-compat /v1/chat/completions + vllm:* Prometheus
# metrics. BNK Gateway + HTTPRoute fronts the three as weighted backends.
# The F5BigAnalyzer CR uses Prometheus to drive the weights.
###############################################################################

locals {
  base_labels = merge({
    "app.kubernetes.io/part-of"    = "bedrock-smartllm-demo"
    "app.kubernetes.io/managed-by" = "terraform"
  }, var.common_labels)
}

# ──────────────────────────────────────────────────────────────────────────────
# Shim source, shipped via ConfigMap + pip-install init container (no custom
# image build — Option 1 per design discussion).
# ──────────────────────────────────────────────────────────────────────────────
resource "kubernetes_config_map_v1" "shim_source" {
  metadata {
    name      = "bedrock-shim-source"
    namespace = var.namespace
    labels    = local.base_labels
  }
  data = {
    "app.py"           = file("${path.module}/shim/app.py")
    "requirements.txt" = file("${path.module}/shim/requirements.txt")
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# IRSA — all three shim pods share a single ServiceAccount annotated with the
# Bedrock-capable IAM role. See README.md for role creation.
# ──────────────────────────────────────────────────────────────────────────────
resource "kubernetes_service_account_v1" "bedrock" {
  metadata {
    name      = "bedrock-smartllm"
    namespace = var.namespace
    labels    = local.base_labels
    annotations = {
      "eks.amazonaws.com/role-arn" = var.bedrock_role_arn
    }
  }
  automount_service_account_token = true
}

# ──────────────────────────────────────────────────────────────────────────────
# One Deployment + Service + ServiceMonitor per model. Service/Deployment name
# doubles as the HTTPRoute backendRef name and the model_name Prometheus label.
# ──────────────────────────────────────────────────────────────────────────────
resource "kubernetes_deployment_v1" "shim" {
  for_each = var.models

  metadata {
    name      = each.key
    namespace = var.namespace
    labels = merge(local.base_labels, {
      "app.kubernetes.io/name"      = each.key
      "app.kubernetes.io/component" = "bedrock-shim"
    })
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name" = each.key
      }
    }
    template {
      metadata {
        labels = merge(local.base_labels, {
          "app.kubernetes.io/name"      = each.key
          "app.kubernetes.io/component" = "bedrock-shim"
        })
      }
      spec {
        service_account_name = kubernetes_service_account_v1.bedrock.metadata[0].name

        init_container {
          name              = "pip-install"
          image             = var.shim_image
          image_pull_policy = "IfNotPresent"
          command           = ["sh", "-c"]
          args = [
            "pip install --no-cache-dir --target /packages -r /src/requirements.txt"
          ]
          volume_mount {
            name       = "shim-source"
            mount_path = "/src"
          }
          volume_mount {
            name       = "packages"
            mount_path = "/packages"
          }
          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { memory = "256Mi" }
          }
        }

        container {
          name              = "shim"
          image             = var.shim_image
          image_pull_policy = "IfNotPresent"
          command           = ["python", "/src/app.py"]

          env {
            name  = "MODEL_ID"
            value = each.value.model_id
          }
          env {
            name  = "MODEL_NAME"
            value = each.key
          }
          env {
            name  = "AWS_REGION"
            value = var.aws_region
          }
          env {
            name  = "PYTHONPATH"
            value = "/packages"
          }
          env {
            name  = "CHAT_PORT"
            value = "8080"
          }
          env {
            name  = "METRICS_PORT"
            value = "9100"
          }

          port {
            name           = "chat"
            container_port = 8080
          }
          port {
            name           = "metrics"
            container_port = 9100
          }

          volume_mount {
            name       = "shim-source"
            mount_path = "/src"
          }
          volume_mount {
            name       = "packages"
            mount_path = "/packages"
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = "chat"
            }
            initial_delay_seconds = 30
            period_seconds        = 15
            failure_threshold     = 3
          }
          readiness_probe {
            http_get {
              path = "/health"
              port = "chat"
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            failure_threshold     = 3
          }

          resources {
            requests = { cpu = "100m", memory = "192Mi" }
            limits   = { memory = "384Mi" }
          }
        }

        volume {
          name = "shim-source"
          config_map {
            name = kubernetes_config_map_v1.shim_source.metadata[0].name
          }
        }
        volume {
          name = "packages"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "shim" {
  for_each = var.models

  metadata {
    name      = each.key
    namespace = var.namespace
    labels = merge(local.base_labels, {
      "app.kubernetes.io/name"      = each.key
      "app.kubernetes.io/component" = "bedrock-shim"
      # ServiceMonitor selector relies on this label matching Prometheus' release.
      "release" = var.prometheus_release_label
    })
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = each.key
    }
    port {
      name        = "chat"
      port        = 8080
      target_port = "chat"
    }
    port {
      name        = "metrics"
      port        = 9100
      target_port = "metrics"
    }
  }
}

resource "kubernetes_manifest" "servicemonitor" {
  for_each = var.models

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels = merge(local.base_labels, {
        "release" = var.prometheus_release_label
      })
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = each.key
        }
      }
      namespaceSelector = {
        matchNames = [var.namespace]
      }
      endpoints = [{
        port     = "metrics"
        interval = "15s"
        path     = "/metrics"
      }]
    }
  }

  depends_on = [kubernetes_service_v1.shim]
}

# ──────────────────────────────────────────────────────────────────────────────
# BNK Gateway — binds the VIP on the external VLAN.
# ──────────────────────────────────────────────────────────────────────────────
resource "kubernetes_manifest" "gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = var.gateway_name
      namespace = var.namespace
      labels    = local.base_labels
    }
    spec = {
      gatewayClassName = var.gateway_class
      addresses = [{
        type  = "IPAddress"
        value = var.gateway_vip
      }]
      listeners = [{
        name     = "http"
        protocol = "HTTP"
        port     = 80
        allowedRoutes = {
          namespaces = { from = "Same" }
        }
      }]
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# HTTPRoute — three weighted backends. Analyzer mutates these weights.
# ──────────────────────────────────────────────────────────────────────────────
resource "kubernetes_manifest" "httproute" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = var.httproute_name
      namespace = var.namespace
      labels    = local.base_labels
    }
    spec = {
      parentRefs = [{
        name = var.gateway_name
      }]
      rules = [{
        matches = [{
          path = { type = "PathPrefix", value = "/v1" }
        }]
        backendRefs = [
          for model_key, cfg in var.models : {
            name   = model_key
            port   = 8080
            weight = cfg.weight
          }
        ]
      }]
    }
  }

  depends_on = [
    kubernetes_manifest.gateway,
    kubernetes_service_v1.shim,
  ]

  # Analyzer rewrites backendRefs[].weight. Ignoring weight drift prevents
  # Terraform from fighting the controller every reconcile.
  field_manager {
    force_conflicts = false
  }

  lifecycle {
    ignore_changes = [
      manifest.spec.rules[0].backendRefs,
    ]
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# F5BigAnalyzer — Path A, builtin LLMLoadMonitor script, real Prometheus.
# Emits DeepSeek/vllm-shaped PromQL queries; our shim emits matching metrics.
# ──────────────────────────────────────────────────────────────────────────────
resource "kubernetes_manifest" "analyzer" {
  manifest = {
    apiVersion = "k8s.f5net.com/v1alpha1"
    kind       = "F5BigAnalyzer"
    metadata = {
      name      = var.analyzer_name
      namespace = var.namespace
      labels    = local.base_labels
    }
    spec = {
      name = var.analyzer_name
      applications = [{
        name      = var.httproute_name
        kind      = "HTTPRoute"
        group     = "gateway.networking.k8s.io"
        namespace = var.namespace
      }]
      dataSources = [{
        name     = "prometheus-bedrock"
        endpoint = var.prometheus_endpoint
        username = ""
        password = ""
      }]
      script = {
        type    = "builtin"
        builtin = { name = "LLMLoadMonitor" }
      }
      schedule = var.analyzer_schedule
    }
  }

  depends_on = [kubernetes_manifest.httproute]
}
