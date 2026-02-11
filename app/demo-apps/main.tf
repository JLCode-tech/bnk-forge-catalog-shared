# bnk-forge-modules/app/demo-apps/main.tf
# Demo Applications — Web Frontend, Echo API, Backend Service

# =============================================================================
# WEB FRONTEND (nginx with custom index.html)
# =============================================================================

resource "kubernetes_config_map_v1" "web_content" {
  depends_on = [var.namespaces_ready]

  metadata {
    name      = "demo-web-content"
    namespace = var.app_namespace
    labels = {
      "app.kubernetes.io/name"       = "demo-web"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  data = {
    "index.html" = <<-HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>BNK Demo - F5 BIG-IP Next for Kubernetes</title>
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
                 background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
                 color: #e2e8f0; min-height: 100vh; padding: 2rem; }
          .container { max-width: 900px; margin: 0 auto; }
          h1 { font-size: 2.5rem; margin-bottom: 0.5rem;
               background: linear-gradient(135deg, #3b82f6, #8b5cf6);
               -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
          .subtitle { color: #94a3b8; font-size: 1.1rem; margin-bottom: 2rem; }
          .card { background: rgba(30, 41, 59, 0.8); border: 1px solid #334155;
                  border-radius: 12px; padding: 1.5rem; margin-bottom: 1rem; }
          .card h3 { color: #60a5fa; margin-bottom: 0.5rem; }
          .card p { color: #94a3b8; font-size: 0.9rem; }
          a { color: #60a5fa; text-decoration: none; }
          a:hover { text-decoration: underline; }
          .endpoints { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-top: 1.5rem; }
          .endpoint { background: rgba(15, 23, 42, 0.6); border: 1px solid #1e3a5f;
                      border-radius: 8px; padding: 1rem; }
          .endpoint .method { display: inline-block; padding: 2px 8px; border-radius: 4px;
                              font-size: 0.75rem; font-weight: 700; margin-right: 0.5rem; }
          .get { background: #065f46; color: #6ee7b7; }
          .post { background: #7c2d12; color: #fdba74; }
          .badge { display: inline-block; padding: 2px 8px; border-radius: 9999px;
                   font-size: 0.7rem; background: #3b82f6; color: white; margin-left: 0.5rem; }
          .footer { margin-top: 2rem; text-align: center; color: #475569; font-size: 0.8rem; }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>F5 BNK Demo</h1>
          <p class="subtitle">BIG-IP Next for Kubernetes — Traffic Management Showcase</p>

          <div class="card">
            <h3>About This Demo</h3>
            <p>This application is deployed behind an F5 BNK Gateway showcasing Gateway API routing,
               firewall policies, iRules, and observability. All traffic flows through BNK TMM and
               is visible in the <strong>BNK-Forge F5 BNK page</strong>.</p>
          </div>

          <div class="endpoints">
            <div class="endpoint">
              <span class="method get">GET</span> <a href="/">/</a>
              <span class="badge">Web Route</span>
              <p style="margin-top:0.5rem;color:#64748b;font-size:0.8rem">This page — served by nginx through BNK Gateway port 80</p>
            </div>
            <div class="endpoint">
              <span class="method get">GET</span> <a href="/api/echo">/api/echo</a>
              <span class="badge">API Route</span>
              <p style="margin-top:0.5rem;color:#64748b;font-size:0.8rem">Echo server — returns full request details including BNK-injected headers</p>
            </div>
            <div class="endpoint">
              <span class="method post">POST</span> <code style="color:#94a3b8">/api/data</code>
              <span class="badge">API Route</span>
              <p style="margin-top:0.5rem;color:#64748b;font-size:0.8rem">POST echo — returns request body, demonstrates firewall allow rules</p>
            </div>
            <div class="endpoint">
              <span class="method get">GET</span> <a href="/health">/health</a>
              <span class="badge">Health Route</span>
              <p style="margin-top:0.5rem;color:#64748b;font-size:0.8rem">Health check endpoint — separate HTTPRoute for monitoring</p>
            </div>
          </div>

          <div class="card" style="margin-top:1.5rem">
            <h3>BNK Features Demonstrated</h3>
            <p>
              <strong>Gateway:</strong> 3 listeners (HTTP :80, HTTPS :443, Smart :8080)<br>
              <strong>HTTPRoutes:</strong> Path-based routing, header-based canary, weighted backends<br>
              <strong>Firewall:</strong> Allow/deny rules with address and port lists<br>
              <strong>iRules:</strong> Request logging with HSL to Fluent Bit &rarr; Loki<br>
              <strong>Security Policy:</strong> Rate limiting at 100 req/s<br>
              <strong>Network Policy:</strong> HTTP profile, iRule attachment per listener
            </p>
          </div>

          <div class="footer">
            <p>Deployed by BNK-Forge &middot; Powered by F5 BIG-IP Next for Kubernetes</p>
          </div>
        </div>
      </body>
      </html>
    HTML

    "nginx.conf" = <<-CONF
      server {
        listen 80;
        server_name _;

        location / {
          root /usr/share/nginx/html;
          index index.html;
        }

        location /healthz {
          return 200 'ok';
          add_header Content-Type text/plain;
        }
      }
    CONF
  }
}

resource "kubernetes_deployment_v1" "web" {
  depends_on = [kubernetes_config_map_v1.web_content]

  metadata {
    name      = "demo-web"
    namespace = var.app_namespace
    labels = {
      "app.kubernetes.io/name"       = "demo-web"
      "app.kubernetes.io/component"  = "frontend"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  spec {
    replicas = var.web_replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "demo-web"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "demo-web"
          "app.kubernetes.io/component" = "frontend"
          "app.kubernetes.io/part-of"   = "bnk-demo"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:1.25-alpine"

          port {
            container_port = 80
            name           = "http"
          }

          volume_mount {
            name       = "web-content"
            mount_path = "/usr/share/nginx/html/index.html"
            sub_path   = "index.html"
          }

          volume_mount {
            name       = "nginx-conf"
            mount_path = "/etc/nginx/conf.d/default.conf"
            sub_path   = "nginx.conf"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "32Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "64Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = 80
            }
            initial_delay_seconds = 3
            period_seconds        = 5
          }
        }

        volume {
          name = "web-content"
          config_map {
            name = kubernetes_config_map_v1.web_content.metadata[0].name
            items {
              key  = "index.html"
              path = "index.html"
            }
          }
        }

        volume {
          name = "nginx-conf"
          config_map {
            name = kubernetes_config_map_v1.web_content.metadata[0].name
            items {
              key  = "nginx.conf"
              path = "nginx.conf"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "web" {
  metadata {
    name      = "demo-web"
    namespace = var.app_namespace
    labels = {
      "app.kubernetes.io/name"       = "demo-web"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "demo-web"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# =============================================================================
# ECHO API SERVICE
# =============================================================================

resource "kubernetes_deployment_v1" "api" {
  depends_on = [var.namespaces_ready]

  metadata {
    name      = "demo-api"
    namespace = var.app_namespace
    labels = {
      "app.kubernetes.io/name"       = "demo-api"
      "app.kubernetes.io/component"  = "api"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  spec {
    replicas = var.api_replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "demo-api"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "demo-api"
          "app.kubernetes.io/component" = "api"
          "app.kubernetes.io/part-of"   = "bnk-demo"
        }
      }

      spec {
        container {
          name  = "echo"
          image = "ealen/echo-server:0.9.2"

          port {
            container_port = 80
            name           = "http"
          }

          env {
            name  = "PORT"
            value = "80"
          }

          resources {
            requests = {
              cpu    = "25m"
              memory = "32Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "64Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 3
            period_seconds        = 5
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "api" {
  metadata {
    name      = "demo-api"
    namespace = var.app_namespace
    labels = {
      "app.kubernetes.io/name"       = "demo-api"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "demo-api"
    }

    port {
      name        = "http"
      port        = 8080
      target_port = 80
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# =============================================================================
# BACKEND SERVICE (for app-to-app routing demo)
# =============================================================================

resource "kubernetes_deployment_v1" "backend" {
  depends_on = [var.namespaces_ready]

  metadata {
    name      = "demo-backend"
    namespace = var.app_namespace
    labels = {
      "app.kubernetes.io/name"       = "demo-backend"
      "app.kubernetes.io/component"  = "backend"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  spec {
    replicas = var.backend_replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "demo-backend"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "demo-backend"
          "app.kubernetes.io/component" = "backend"
          "app.kubernetes.io/part-of"   = "bnk-demo"
        }
      }

      spec {
        container {
          name  = "echo"
          image = "ealen/echo-server:0.9.2"

          port {
            container_port = 80
            name           = "http"
          }

          env {
            name  = "PORT"
            value = "80"
          }

          resources {
            requests = {
              cpu    = "25m"
              memory = "32Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "64Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "backend" {
  metadata {
    name      = "demo-backend"
    namespace = var.app_namespace
    labels = {
      "app.kubernetes.io/name"       = "demo-backend"
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "demo-backend"
    }

    port {
      name        = "http"
      port        = 8080
      target_port = 80
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}
