# ark-analyzer secret
resource "kubernetes_secret" "ark_analyzer_secret" {
  metadata {
    name      = "ark-analyzer-secret"
    namespace = kubernetes_namespace.namespaces["stocks"].metadata[0].name
  }

  data = {
    TO_EMAILS         = data.vault_generic_secret.ark.data["to_emails"]
    MAILER_API_URL    = data.vault_generic_secret.ark.data["mailer_api_url"]
    POSTGRES_DB       = data.vault_generic_secret.ark.data["postgres_db"]
    POSTGRES_USER     = data.vault_generic_secret.ark.data["postgres_user"]
    POSTGRES_PASSWORD = data.vault_generic_secret.ark.data["postgres_password"]
    POSTGRES_HOST     = data.vault_generic_secret.postgresql.data["hostname"]
    POSTGRES_PORT     = data.vault_generic_secret.postgresql.data["port"]
  }

  type = "Opaque"
}

# ark-analyzer deployment
resource "argocd_application" "ark_analyzer" {
  for_each = local.ark_analyzer_jobs

  metadata {
    name      = "ark-analyzer-${each.key}"
    namespace = "argocd"
  }
  spec {
    project = "stocks"
    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      path            = "ark-analyzer"
      helm {
        value_files = [each.value.values_file]
      }
    }
    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "stocks"
    }
    sync_policy {
      automated {
        prune       = true
        self_heal   = true
        allow_empty = false
      }
      retry {
        limit = 5
        backoff {
          duration     = "30s"
          max_duration = "2m"
          factor       = 2
        }
      }
    }
  }
  depends_on = [
    helm_release.argocd,
    argocd_project.projects["stocks"],
    kubernetes_secret.ark_analyzer_secret,
    argocd_application.postgresql
  ]
}

## Deprecated
#resource "kubernetes_manifest" "ark_analyzer_cronjob_first_time_buys" {
#  manifest = yamldecode(templatefile("${path.module}/ark-analyzer-cronjob-first-time-buys.yaml", {
#    namespace = kubernetes_namespace.namespaces["stocks"].metadata[0].name
#    image     = "harbor.schwitzd.me/library/ark-analyzer:0.2.1"
#  }))
#
#  depends_on = [ kubernetes_secret.ark_analyzer_secret ]
#}
#
#resource "kubernetes_manifest" "ark_analyzer_cronjob_top_trades" {
#  manifest = yamldecode(templatefile("${path.module}/ark-analyzer-cronjob-top-trades.yaml", {
#    namespace = kubernetes_namespace.namespaces["stocks"].metadata[0].name
#    image     = "harbor.schwitzd.me/library/ark-analyzer:0.2.1"
#  }))
#
#  depends_on = [ kubernetes_secret.ark_analyzer_secret ]
#}

