# Vault path
data "vault_generic_secret" "pgadmin" {
  path = "${var.vault_name}/pgadmin"
}

# Pgadmin secret
resource "kubernetes_secret" "pgadmin" {
  metadata {
    name      = "auth-pgadmin"
    namespace = kubernetes_namespace.namespaces["database"].metadata[0].name
  }

  data = {
    password = data.vault_generic_secret.pgadmin.data["password"]
  }

  type = "Opaque"
}

# Pgadmin deployment 
resource "argocd_application" "pgadmin" {
  metadata {
    name      = "pgadmin"
    namespace = "argocd"
  }

  spec {
    project = "database"

    source {
      repo_url        = "https://helm.runix.net"
      chart           = "pgadmin4"
      target_revision = "1.50.0"

      helm {
        value_files = ["$values/pgadmin/values.yaml"]
      }
    }

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      ref             = "values"
      path            = "pgadmin"

      directory {
        recurse = true
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "database"
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
    kubernetes_namespace.namespaces["database"],
    helm_release.argocd,
    kubernetes_secret.pgadmin,
    argocd_application.rook_ceph_cluster
  ]
}
