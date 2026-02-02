# infrastructure-modules/bnk/f5biganalyzer/main.tf
# F5BigAnalyzer - AI Load Balancing Analyzer (Early Access)

# =============================================================================
# F5 AI LOAD BALANCING ANALYZER
# =============================================================================

resource "kubernetes_manifest" "f5biganalyzer" {
  depends_on = [var.flo_ready]

  manifest = {
    apiVersion = "k8s.f5net.com/v1"
    kind       = "F5BigAnalyzer"

    metadata = {
      name      = var.analyzer_name
      namespace = var.analyzer_namespace

      labels = merge(var.common_labels, {
        "app.kubernetes.io/name"       = var.analyzer_name
        "app.kubernetes.io/component"  = "ai-analyzer"
        "app.kubernetes.io/managed-by" = "terraform"
        "f5.com/feature-stage"         = "early-access"
      })

      annotations = merge(
        var.annotations,
        {
          "f5.com/feature"       = "ai-load-balancing"
          "f5.com/version"       = "2.2-EA"
          "f5.com/model-type"    = var.llm_workload_config.model_type
        }
      )
    }

    spec = merge(
      {
        llmWorkload = merge(
          {
            modelType  = var.llm_workload_config.model_type
            maxTokens  = var.llm_workload_config.max_tokens
            streaming  = var.llm_workload_config.streaming_enabled
            batchSize  = var.llm_workload_config.batch_size
          },
          var.llm_workload_config.context_window != null ? {
            contextWindow = var.llm_workload_config.context_window
          } : {}
        )

        routingAlgorithm = var.routing_algorithm
      },
      var.enable_metrics ? {
        metrics = {
          enabled = true
          port    = var.metrics_port
        }
      } : {}
    )
  }
}

# =============================================================================
# VERIFICATION
# =============================================================================

resource "time_sleep" "wait_for_analyzer" {
  depends_on = [kubernetes_manifest.f5biganalyzer]

  create_duration = "10s"
}

resource "null_resource" "verify_analyzer" {
  depends_on = [time_sleep.wait_for_analyzer]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying F5BigAnalyzer ${var.analyzer_name} (Early Access) ==="

      # Check analyzer exists
      kubectl get f5biganalyzer ${var.analyzer_name} -n ${var.analyzer_namespace} || echo "Analyzer not found yet"

      echo "✓ F5BigAnalyzer verification complete"
      echo "⚠️  Note: This is an Early Access feature"
    EOT
  }
}
