# bnk-forge-modules/app/demo-observability/main.tf
# Observability Stack — Fluent Bit (HSL receiver) + Loki (log aggregation)
# Pattern ported from lanner-bnk-poc/observability/

# =============================================================================
# LOKI — Log Aggregation
# =============================================================================

resource "kubernetes_config_map_v1" "loki_config" {
  depends_on = [var.namespaces_ready]

  metadata {
    name      = "loki-config"
    namespace = var.observability_namespace
    labels = {
      "app.kubernetes.io/name"       = "loki"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  data = {
    "config.yaml" = yamlencode({
      server = {
        http_listen_port = 3100
      }
      common = {
        path_prefix = "/loki"
        storage = {
          filesystem = {
            chunks_directory = "/loki/chunks"
            rules_directory  = "/loki/rules"
          }
        }
        replication_factor = 1
        ring = {
          kvstore = {
            store = "inmemory"
          }
        }
      }
      schema_config = {
        configs = [
          {
            from         = "2024-01-01"
            store        = "tsdb"
            object_store = "filesystem"
            schema       = "v13"
            index = {
              prefix = "index_"
              period = "24h"
            }
          }
        ]
      }
      query_range = {
        parallelise_shardable_queries = true
      }
      table_manager = {
        retention_deletes_enabled = true
        retention_period          = "${var.loki_retention_days * 24}h"
      }
    })
  }
}

resource "kubernetes_deployment_v1" "loki" {
  depends_on = [kubernetes_config_map_v1.loki_config]

  metadata {
    name      = "loki"
    namespace = var.observability_namespace
    labels = {
      "app.kubernetes.io/name"       = "loki"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "loki"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = "loki"
          "app.kubernetes.io/part-of" = "bnk-demo"
        }
      }

      spec {
        container {
          name  = "loki"
          image = "grafana/loki:3.0.0"

          args = ["-config.file=/etc/loki/config/config.yaml"]

          port {
            container_port = 3100
            name           = "http"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/loki/config"
          }

          resources {
            requests = {
              cpu    = "200m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.loki_config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "loki" {
  metadata {
    name      = "loki"
    namespace = var.observability_namespace
    labels = {
      "app.kubernetes.io/name"       = "loki"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "loki"
    }

    port {
      name        = "http"
      port        = 3100
      target_port = 3100
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# =============================================================================
# FLUENT BIT — HSL UDP Receiver → Loki Forwarder
# =============================================================================

resource "kubernetes_config_map_v1" "fluentbit_config" {
  depends_on = [var.namespaces_ready]

  metadata {
    name      = "fluent-bit-config"
    namespace = var.observability_namespace
    labels = {
      "app.kubernetes.io/name"       = "fluentbit-hsl"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  data = {
    "fluent-bit.conf" = <<-CONF
      [SERVICE]
          Flush        1
          Daemon       off
          Log_Level    info

      [INPUT]
          Name         udp
          Tag          hsl.demo
          Listen       0.0.0.0
          Port         ${var.fluentbit_hsl_port}

      [FILTER]
          Name         record_modifier
          Match        hsl.*
          Record       source hsl

      [OUTPUT]
          Name         loki
          Match        *
          Host         loki
          Port         3100
          labels       job=hsl, app=bnk, mode=genai
          label_keys   $source,$model,$endpoint,$status,$virtual_server
          line_format  json
    CONF
  }
}

resource "kubernetes_deployment_v1" "fluentbit" {
  depends_on = [kubernetes_config_map_v1.fluentbit_config]

  metadata {
    name      = "fluentbit-hsl"
    namespace = var.observability_namespace
    labels = {
      "app.kubernetes.io/name"       = "fluentbit-hsl"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "fluentbit-hsl"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = "fluentbit-hsl"
          "app.kubernetes.io/part-of" = "bnk-demo"
        }
      }

      spec {
        container {
          name  = "fluent-bit"
          image = "cr.fluentbit.io/fluent/fluent-bit:3.0"

          port {
            container_port = var.fluentbit_hsl_port
            name           = "udp"
            protocol       = "UDP"
          }

          volume_mount {
            name       = "config"
            mount_path = "/fluent-bit/etc/"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.fluentbit_config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "fluentbit" {
  metadata {
    name      = "fluentbit-hsl-udp"
    namespace = var.observability_namespace
    labels = {
      "app.kubernetes.io/name"       = "fluentbit-hsl"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "fluentbit-hsl"
    }

    port {
      name        = "hsl-udp"
      port        = var.fluentbit_hsl_port
      target_port = var.fluentbit_hsl_port
      protocol    = "UDP"
    }

    type = "ClusterIP"
  }
}
