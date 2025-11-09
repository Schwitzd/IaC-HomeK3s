# Vault path
data "vault_generic_secret" "garage" {
  path = "${var.vault_name}/garage"
}

# Garage deployment
resource "argocd_application" "garage" {
  metadata {
    name      = "garage"
    namespace = "argocd"
  }

  spec {
    project = "infrastructure"

    source {
      repo_url        = "https://git.deuxfleurs.fr/Deuxfleurs/garage.git"
      target_revision = "b43f309ec7"
      path            = "script/helm/garage"

      helm {
        value_files = ["$values/garage/values.yaml"]
      }
    }

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      ref             = "values"
      path            = "garage"

      directory {
        recurse = true
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "storage"
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
    kubernetes_namespace.namespaces["storage"],
    helm_release.argocd,
    argocd_application.rook_ceph_cluster
  ]
}