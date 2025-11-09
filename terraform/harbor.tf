# Vault path
data "vault_generic_secret" "harbor" {
  path = "${var.vault_name}/harbor"
}

# Harbor secret
resource "kubernetes_secret" "harbor_admin" {
  metadata {
    name      = "auth-harbor-admin"
    namespace = kubernetes_namespace.namespaces["registry"].metadata[0].name
  }

  data = {
    admin-password = data.vault_generic_secret.harbor.data["adminPassword"]
  }

  type = "Opaque"
}

resource "kubernetes_secret" "harbor_external_db" {
  metadata {
    name      = "auth-db-harbor-db"
    namespace = kubernetes_namespace.namespaces["registry"].metadata[0].name
  }

  data = {
    password = data.vault_generic_secret.harbor.data["db_password"]
  }

  type = "Opaque"
}

resource "kubernetes_secret" "harbor_external_redis" {
  metadata {
    name      = "auth-db-harbor-redis"
    namespace = kubernetes_namespace.namespaces["registry"].metadata[0].name
  }

  data = {
    REDIS_PASSWORD = data.vault_generic_secret.redis.data["password"]
  }

  type = "Opaque"
}

resource "argocd_application" "harbor" {
  metadata {
    name      = "harbor"
    namespace = "argocd"
  }

  spec {
    project = "registry"

    source {
      repo_url        = "registry-1.docker.io/bitnamicharts"
      chart           = "harbor"
      target_revision = "26.7.12"

      helm {
        value_files = ["$values/harbor/values.yaml"]


        parameter {
          name  = "externalRedis.password"
          value = data.vault_generic_secret.redis.data["password"]
        }
      }
    }

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      ref             = "values"
      path            = "harbor"

      directory {
        recurse = true
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "registry"
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
    kubernetes_secret.harbor_admin,
    kubernetes_secret.harbor_external_db,
    kubernetes_secret.harbor_external_redis,
    argocd_application.rook_ceph_cluster,
    argocd_application.cnpg_cluster,
    argocd_application.redis
  ]
}
