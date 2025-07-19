# Vault path
data "vault_generic_secret" "ark" {
  path = "${var.vault_name}/ark"
}

# ark-scraper secret
resource "kubernetes_secret" "ark_scraper_secret" {
  metadata {
    name      = "ark-scraper-secret"
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

# ark-scraper deployment
resource "argocd_application" "ark_scraper" {
  metadata {
    name      = "ark-scraper"
    namespace = "argocd"
  }

  spec {
    project = "stocks"

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      path            = "ark-scraper"
      ref             = "values"

      helm {
        value_files = ["$values/ark-scraper/values.yaml"]
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
    argocd_application.postgresql,
    kubernetes_secret.ark_scraper_secret
  ]
}

## Deprecated
#resource "kubernetes_manifest" "ark_scraper_cronjob" {
#  manifest = yamldecode(templatefile("${path.module}/ark-scraper-cronjob.yaml", {
#    namespace          = kubernetes_namespace.namespaces["stocks"].metadata[0].name
#    image              = "harbor.schwitzd.me/library/ark-scraper:0.5.2"
#    ARK_TRADE_FILE_URL = "https://etfs.ark-funds.com/hubfs/idt/trades/ARK_Trades.xls"
#  }))
#
#  depends_on = [ kubernetes_secret.ark_scraper_secret ]
#}
