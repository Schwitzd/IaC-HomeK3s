resource "argocd_application" "trust_manager" {
  metadata {
    name      = "trust-manager"
    namespace = "argocd"
  }

  spec {
    project = "pki"

    source {
      repo_url        = "https://charts.jetstack.io"
      chart           = "trust-manager"
      target_revision = "0.19.0"

      helm {
        value_files = ["$values/trust-manager/values.yaml"]
      }
    }

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      ref             = "values"
      path            = "trust-manager"

      directory {
        recurse = true
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "pki"
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
    argocd_project.projects["pki"],
    argocd_application.cert_manager,
    argocd_application.farm_ca
  ]
}
