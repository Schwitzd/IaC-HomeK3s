# Paperless secrets
resource "kubernetes_secret" "paperless_external_db" {
  metadata {
    name      = "auth-db-paperless"
    namespace = kubernetes_namespace.namespaces["productivity"].metadata[0].name
  }

  data = {
    password = data.vault_generic_secret.postgresql_roles.data["paperless"]
  }

  type = "Opaque"
}

resource "kubernetes_secret" "paperless_external_redis" {
  metadata {
    name      = "auth-db-paperless-redis"
    namespace = kubernetes_namespace.namespaces["productivity"].metadata[0].name
  }

  data = {
    password = data.vault_generic_secret.redis.data["password"]
  }

  type = "Opaque"
}

# Paperless deployment
resource "argocd_application" "paperless_ngx" {
  metadata {
    name      = "paperless-ngx"
    namespace = "argocd"
  }

  spec {
    project = "productivity"

    source {
      repo_url        = "codeberg.org/wrenix/helm-charts"
      chart           = "paperless-ngx"
      target_revision = "0.2.7"

      helm {
        value_files = ["$values/paperless-ngx/values.yaml"]
      }
    }

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      ref             = "values"
      path            = "paperless-ngx"

      directory {
        recurse = true
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "productivity"
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
    helm_release.argocd,
    argocd_project.projects["productivity"],
    kubernetes_secret.paperless_external_db,
    kubernetes_secret.paperless_external_redis,
    argocd_application.cnpg_cluster,
    argocd_application.redis
  ]
}
