# bnk-forge-modules/app/demo-traffic/main.tf
# Traffic Generators — CronJobs that send requests to backend services directly
#
# IMPORTANT: These CronJobs target backend services (demo-web, demo-api) via K8s
# ClusterIP, NOT the BNK Gateway VIP. BNK Gateways don't create K8s Services,
# and cluster pods can't reach the data-plane VIP without egress config.
#
# For real external→VIP→TMM→backend testing, use the existing jumphost:
#   ssh to jumphost → curl http://10.0.10.100 (Gateway VIP on external subnet)
#
# These CronJobs serve as internal health checks to verify backend pods are alive.

locals {
  # Target backend services directly via ClusterIP (bypasses BNK Gateway)
  backend_url = "http://${var.backend_service_name}.${var.app_namespace}.svc.cluster.local:${var.backend_service_port}"
  common_labels = {
    "app.kubernetes.io/component"  = "traffic-generator"
    "app.kubernetes.io/part-of"    = "bnk-demo"
    "app.kubernetes.io/managed-by" = "opentofu"
  }
}

# =============================================================================
# TRAFFIC SCRIPTS CONFIGMAP
# =============================================================================

resource "kubernetes_config_map_v1" "traffic_scripts" {
  depends_on = [var.routes_ready]

  metadata {
    name      = "demo-traffic-scripts"
    namespace = var.app_namespace
    labels = merge(local.common_labels, {
      "app.kubernetes.io/name" = "demo-traffic-scripts"
    })
  }

  data = {
    # Web traffic — GET / every interval
    "web-traffic.sh" = <<-SCRIPT
      #!/bin/sh
      echo "Starting web traffic generator → ${local.backend_url}/"
      end=$(($(date +%s) + 50))
      while [ $(date +%s) -lt $end ]; do
        curl -s -o /dev/null -w "Web: %%{http_code} %%{time_total}s\n" \
          -H "User-Agent: BNK-Demo-WebTraffic/1.0" \
          "${local.backend_url}/"
        sleep ${var.traffic_interval_seconds}
      done
      echo "Web traffic batch complete"
    SCRIPT

    # API traffic — GET and POST to /api/*
    "api-traffic.sh" = <<-SCRIPT
      #!/bin/sh
      echo "Starting API traffic generator → ${local.backend_url}/api/"
      end=$(($(date +%s) + 50))
      i=0
      while [ $(date +%s) -lt $end ]; do
        i=$((i + 1))
        if [ $((i % 2)) -eq 0 ]; then
          curl -s -o /dev/null -w "API GET: %%{http_code} %%{time_total}s\n" \
            -H "User-Agent: BNK-Demo-APITraffic/1.0" \
            "${local.backend_url}/api/echo?request=$i"
        else
          curl -s -o /dev/null -w "API POST: %%{http_code} %%{time_total}s\n" \
            -X POST \
            -H "Content-Type: application/json" \
            -H "User-Agent: BNK-Demo-APITraffic/1.0" \
            -d "{\"message\":\"demo request $i\",\"timestamp\":\"$(date -u +%%Y-%%m-%%dT%%H:%%M:%%SZ)\"}" \
            "${local.backend_url}/api/data"
        fi
        sleep ${var.traffic_interval_seconds}
      done
      echo "API traffic batch complete"
    SCRIPT

    # Canary traffic — GET with X-Canary header
    "canary-traffic.sh" = <<-SCRIPT
      #!/bin/sh
      echo "Starting canary traffic generator → ${local.backend_url}/api/echo"
      end=$(($(date +%s) + 50))
      while [ $(date +%s) -lt $end ]; do
        curl -s -o /dev/null -w "Canary: %%{http_code} %%{time_total}s\n" \
          -H "X-Canary: true" \
          -H "User-Agent: BNK-Demo-CanaryTraffic/1.0" \
          "${local.backend_url}/api/echo?canary=true"
        sleep ${var.traffic_interval_seconds}
      done
      echo "Canary traffic batch complete"
    SCRIPT

    # Health traffic — GET /health
    "health-traffic.sh" = <<-SCRIPT
      #!/bin/sh
      echo "Starting health check traffic → ${local.backend_url}/health"
      end=$(($(date +%s) + 50))
      while [ $(date +%s) -lt $end ]; do
        curl -s -o /dev/null -w "Health: %%{http_code} %%{time_total}s\n" \
          -H "User-Agent: BNK-Demo-HealthCheck/1.0" \
          "${local.backend_url}/health"
        sleep 60
      done
      echo "Health check batch complete"
    SCRIPT

    # Blocked traffic — GET with X-Forwarded-For from blocked range
    "blocked-traffic.sh" = <<-SCRIPT
      #!/bin/sh
      echo "Starting blocked source traffic → ${local.backend_url}/"
      end=$(($(date +%s) + 50))
      while [ $(date +%s) -lt $end ]; do
        curl -s -o /dev/null -w "Blocked: %%{http_code} %%{time_total}s\n" \
          -H "X-Forwarded-For: 198.51.100.1" \
          -H "User-Agent: BNK-Demo-BlockedTraffic/1.0" \
          "${local.backend_url}/api/echo?source=blocked"
        sleep 60
      done
      echo "Blocked traffic batch complete"
    SCRIPT
  }
}

# =============================================================================
# WEB TRAFFIC CRONJOB
# =============================================================================

resource "kubernetes_cron_job_v1" "web_traffic" {
  count = var.enable_web_traffic ? 1 : 0

  metadata {
    name      = "traffic-web"
    namespace = var.app_namespace
    labels = merge(local.common_labels, {
      "app.kubernetes.io/name" = "traffic-web"
    })
  }

  spec {
    schedule                      = "*/1 * * * *"
    concurrency_policy            = "Replace"
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 1

    job_template {
      metadata {
        labels = merge(local.common_labels, {
          "app.kubernetes.io/name" = "traffic-web"
        })
      }

      spec {
        active_deadline_seconds = 55
        backoff_limit           = 0

        template {
          metadata {
            labels = merge(local.common_labels, {
              "app.kubernetes.io/name" = "traffic-web"
            })
          }

          spec {
            restart_policy = "Never"

            container {
              name    = "curl"
              image   = "curlimages/curl:8.5.0"
              command = ["/bin/sh", "/scripts/web-traffic.sh"]

              volume_mount {
                name       = "scripts"
                mount_path = "/scripts"
              }

              resources {
                requests = {
                  cpu    = "10m"
                  memory = "16Mi"
                }
                limits = {
                  cpu    = "50m"
                  memory = "32Mi"
                }
              }
            }

            volume {
              name = "scripts"
              config_map {
                name         = kubernetes_config_map_v1.traffic_scripts.metadata[0].name
                default_mode = "0755"
              }
            }
          }
        }
      }
    }
  }
}

# =============================================================================
# API TRAFFIC CRONJOB
# =============================================================================

resource "kubernetes_cron_job_v1" "api_traffic" {
  count = var.enable_api_traffic ? 1 : 0

  metadata {
    name      = "traffic-api"
    namespace = var.app_namespace
    labels = merge(local.common_labels, {
      "app.kubernetes.io/name" = "traffic-api"
    })
  }

  spec {
    schedule                      = "*/1 * * * *"
    concurrency_policy            = "Replace"
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 1

    job_template {
      metadata {
        labels = merge(local.common_labels, {
          "app.kubernetes.io/name" = "traffic-api"
        })
      }

      spec {
        active_deadline_seconds = 55
        backoff_limit           = 0

        template {
          metadata {
            labels = merge(local.common_labels, {
              "app.kubernetes.io/name" = "traffic-api"
            })
          }

          spec {
            restart_policy = "Never"

            container {
              name    = "curl"
              image   = "curlimages/curl:8.5.0"
              command = ["/bin/sh", "/scripts/api-traffic.sh"]

              volume_mount {
                name       = "scripts"
                mount_path = "/scripts"
              }

              resources {
                requests = {
                  cpu    = "10m"
                  memory = "16Mi"
                }
                limits = {
                  cpu    = "50m"
                  memory = "32Mi"
                }
              }
            }

            volume {
              name = "scripts"
              config_map {
                name         = kubernetes_config_map_v1.traffic_scripts.metadata[0].name
                default_mode = "0755"
              }
            }
          }
        }
      }
    }
  }
}

# =============================================================================
# CANARY TRAFFIC CRONJOB
# =============================================================================

resource "kubernetes_cron_job_v1" "canary_traffic" {
  count = var.enable_canary_traffic ? 1 : 0

  metadata {
    name      = "traffic-canary"
    namespace = var.app_namespace
    labels = merge(local.common_labels, {
      "app.kubernetes.io/name" = "traffic-canary"
    })
  }

  spec {
    schedule                      = "*/2 * * * *"
    concurrency_policy            = "Replace"
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 1

    job_template {
      metadata {
        labels = merge(local.common_labels, {
          "app.kubernetes.io/name" = "traffic-canary"
        })
      }

      spec {
        active_deadline_seconds = 55
        backoff_limit           = 0

        template {
          metadata {
            labels = merge(local.common_labels, {
              "app.kubernetes.io/name" = "traffic-canary"
            })
          }

          spec {
            restart_policy = "Never"

            container {
              name    = "curl"
              image   = "curlimages/curl:8.5.0"
              command = ["/bin/sh", "/scripts/canary-traffic.sh"]

              volume_mount {
                name       = "scripts"
                mount_path = "/scripts"
              }

              resources {
                requests = {
                  cpu    = "10m"
                  memory = "16Mi"
                }
                limits = {
                  cpu    = "50m"
                  memory = "32Mi"
                }
              }
            }

            volume {
              name = "scripts"
              config_map {
                name         = kubernetes_config_map_v1.traffic_scripts.metadata[0].name
                default_mode = "0755"
              }
            }
          }
        }
      }
    }
  }
}

# =============================================================================
# BLOCKED TRAFFIC CRONJOB
# =============================================================================

resource "kubernetes_cron_job_v1" "blocked_traffic" {
  count = var.enable_blocked_traffic ? 1 : 0

  metadata {
    name      = "traffic-denied"
    namespace = var.app_namespace
    labels = merge(local.common_labels, {
      "app.kubernetes.io/name" = "traffic-denied"
    })
  }

  spec {
    schedule                      = "*/5 * * * *"
    concurrency_policy            = "Replace"
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 1

    job_template {
      metadata {
        labels = merge(local.common_labels, {
          "app.kubernetes.io/name" = "traffic-denied"
        })
      }

      spec {
        active_deadline_seconds = 55
        backoff_limit           = 0

        template {
          metadata {
            labels = merge(local.common_labels, {
              "app.kubernetes.io/name" = "traffic-denied"
            })
          }

          spec {
            restart_policy = "Never"

            container {
              name    = "curl"
              image   = "curlimages/curl:8.5.0"
              command = ["/bin/sh", "/scripts/blocked-traffic.sh"]

              volume_mount {
                name       = "scripts"
                mount_path = "/scripts"
              }

              resources {
                requests = {
                  cpu    = "10m"
                  memory = "16Mi"
                }
                limits = {
                  cpu    = "50m"
                  memory = "32Mi"
                }
              }
            }

            volume {
              name = "scripts"
              config_map {
                name         = kubernetes_config_map_v1.traffic_scripts.metadata[0].name
                default_mode = "0755"
              }
            }
          }
        }
      }
    }
  }
}
