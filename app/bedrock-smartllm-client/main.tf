###############################################################################
# app/bedrock-smartllm-client — module main
#
# A small Python pod that hammers the BNK Gateway VIP with varied prompts,
# pacing with a Poisson process so the load is bursty (like real clients).
# Emits client-side Prometheus metrics so the dashboard can show latency /
# request rate / model-served distribution as observed from outside BNK.
###############################################################################

locals {
  app_labels = merge({
    "app.kubernetes.io/name"       = "smartllm-client"
    "app.kubernetes.io/part-of"    = "bedrock-smartllm-demo"
    "app.kubernetes.io/component"  = "load-generator"
    "app.kubernetes.io/managed-by" = "terraform"
  }, var.common_labels)
}

resource "kubernetes_namespace_v1" "client" {
  count = var.create_namespace ? 1 : 0
  metadata {
    name   = var.namespace
    labels = local.app_labels
  }
}

resource "kubernetes_config_map_v1" "client_source" {
  metadata {
    name      = "smartllm-client-source"
    namespace = var.namespace
    labels    = local.app_labels
  }
  data = {
    "client.py"        = file("${path.module}/client/client.py")
    "requirements.txt" = file("${path.module}/client/requirements.txt")
  }
  depends_on = [kubernetes_namespace_v1.client]
}

resource "kubernetes_config_map_v1" "prompts" {
  metadata {
    name      = "smartllm-client-prompts"
    namespace = var.namespace
    labels    = local.app_labels
  }
  data = {
    "prompts.txt" = file("${path.module}/client/prompts.txt")
  }
  depends_on = [kubernetes_namespace_v1.client]
}

resource "kubernetes_deployment_v1" "client" {
  metadata {
    name      = "smartllm-client"
    namespace = var.namespace
    labels    = local.app_labels
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "smartllm-client"
      }
    }
    template {
      metadata {
        labels = local.app_labels
      }
      spec {
        init_container {
          name              = "pip-install"
          image             = var.client_image
          image_pull_policy = "IfNotPresent"
          command           = ["sh", "-c"]
          args = [
            "pip install --no-cache-dir --target /packages -r /src/requirements.txt"
          ]
          volume_mount {
            name       = "client-source"
            mount_path = "/src"
          }
          volume_mount {
            name       = "packages"
            mount_path = "/packages"
          }
          resources {
            requests = { cpu = "50m", memory = "64Mi" }
            limits   = { memory = "128Mi" }
          }
        }

        container {
          name              = "client"
          image             = var.client_image
          image_pull_policy = "IfNotPresent"
          command           = ["python", "/src/client.py"]

          env {
            name  = "GATEWAY_URL"
            value = var.gateway_url
          }
          env {
            name  = "REQUEST_RATE"
            value = tostring(var.request_rate)
          }
          env {
            name  = "MAX_TOKENS"
            value = tostring(var.max_tokens)
          }
          env {
            name  = "REQUEST_TIMEOUT"
            value = tostring(var.request_timeout_seconds)
          }
          env {
            name  = "PROMPTS_PATH"
            value = "/etc/prompts/prompts.txt"
          }
          env {
            name  = "METRICS_PORT"
            value = "9100"
          }
          env {
            name = "CLIENT_ID"
            value_from {
              field_ref { field_path = "metadata.name" }
            }
          }
          env {
            name  = "PYTHONPATH"
            value = "/packages"
          }

          port {
            name           = "metrics"
            container_port = 9100
          }

          volume_mount {
            name       = "client-source"
            mount_path = "/src"
          }
          volume_mount {
            name       = "packages"
            mount_path = "/packages"
          }
          volume_mount {
            name       = "prompts"
            mount_path = "/etc/prompts"
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = "metrics"
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          resources {
            requests = { cpu = "50m", memory = "96Mi" }
            limits   = { memory = "192Mi" }
          }
        }

        volume {
          name = "client-source"
          config_map {
            name = kubernetes_config_map_v1.client_source.metadata[0].name
          }
        }
        volume {
          name = "packages"
          empty_dir {}
        }
        volume {
          name = "prompts"
          config_map {
            name = kubernetes_config_map_v1.prompts.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "client" {
  metadata {
    name      = "smartllm-client"
    namespace = var.namespace
    labels = merge(local.app_labels, {
      "release" = var.prometheus_release_label
    })
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = "smartllm-client"
    }
    port {
      name        = "metrics"
      port        = 9100
      target_port = "metrics"
    }
    cluster_ip = "None" # headless — we only use this for Prometheus scrape
  }
}

resource "kubernetes_manifest" "servicemonitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "smartllm-client"
      namespace = var.namespace
      labels = merge(local.app_labels, {
        "release" = var.prometheus_release_label
      })
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "smartllm-client"
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

  depends_on = [kubernetes_service_v1.client]
}
