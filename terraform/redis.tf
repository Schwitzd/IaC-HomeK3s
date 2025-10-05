# Vault path
data "vault_generic_secret" "redis" {
  path = "${var.vault_name}/redis"
}

# Redis secret
resource "kubernetes_secret" "redis" {
  metadata {
    name      = "auth-db-redis"
    namespace = kubernetes_namespace.namespaces["database"].metadata[0].name
  }

  data = {
    REDIS_PASSWORD = data.vault_generic_secret.redis.data["password"]
  }

  type = "Opaque"
}

# Redis deployment
resource "argocd_application" "redis" {
  metadata {
    name      = "redis"
    namespace = "argocd"
    annotations = {
      "argocd.argoproj.io/sync-wave" = "1"
    }
  }

  spec {
    project = "database"
    source {
      repo_url        = "https://groundhog2k.github.io/helm-charts/"
      chart           = "redis"
      target_revision = "2.1.3"

      helm {
        value_files = ["$values/redis/values.yaml"]
      }
    }

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      ref             = "values"
      path            = "redis"

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
        limit = "5"
        backoff {
          duration     = "30s"
          max_duration = "2m"
          factor       = "2"
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.namespaces["database"],
    helm_release.argocd,
    argocd_project.projects["database"],
    kubernetes_secret.redis,
    argocd_application.rook_ceph_cluster
  ]
}
