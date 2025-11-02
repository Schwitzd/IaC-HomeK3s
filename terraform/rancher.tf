# Vault path
data "vault_generic_secret" "rancher" {
  path = "${var.vault_name}/rancher"
}

# Rancher deployment
resource "argocd_application" "rancher" {
  metadata {
    name      = "rancher"
    namespace = "argocd"
  }

  spec {
    project = "infrastructure"
    source {
      repo_url        = "https://releases.rancher.com/server-charts/latest"
      chart           = "rancher"
      target_revision = "2.11.3"

      helm {
        value_files = ["$values/rancher/values.yaml"]
      }
    }

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      ref             = "values"
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "cattle-system"
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
    argocd_project.projects["infrastructure"],
    kubernetes_namespace.namespaces["cattle-system"]
  ]
}
