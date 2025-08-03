# Vault path
data "vault_generic_secret" "grafana" {
  path = "${var.vault_name}/grafana"
}

# Grafana secret
resource "kubernetes_secret" "grafana_admin" {
  metadata {
    name      = "auth-grafana-admin"
    namespace = kubernetes_namespace.namespaces["observability"].metadata[0].name
  }

  data = {
    admin-user     = data.vault_generic_secret.grafana.data["user"]
    admin-password = data.vault_generic_secret.grafana.data["password"]
  }

  type = "Opaque"
}

# Grafama deployment
resource "argocd_application" "grafana" {
  metadata {
    name      = "grafana"
    namespace = "argocd"
  }

  spec {
    project = "observability"

    source {
      repo_url        = "https://grafana.github.io/helm-charts"
      chart           = "grafana"
      target_revision = "9.3.0"

      helm {
        value_files = ["$values/grafana/values.yaml"]
      }
    }

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      ref             = "values"
      path            = "grafana"

      directory {
        recurse = true
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "observability"
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
    argocd_project.projects["observability"],
    kubernetes_secret.grafana_admin,
    argocd_application.rook_ceph_cluster,
    argocd_application.prometheus
  ]
}
