data "vault_generic_secret" "redis" {
  path = "${var.vault_name}/redis"
}

resource "kubernetes_secret" "redis_auth" {
  metadata {
    name      = "redis-secret"
    namespace = kubernetes_namespace.namespaces["database"].metadata[0].name
  }

  data = {
    redis-password = data.vault_generic_secret.redis.data["password"]
  }

  type = "Opaque"
}

resource "argocd_application" "redis" {
  metadata {
    name      = "redis"
    namespace = "infrastructure"
    annotations = {
      "argocd.argoproj.io/sync-wave" = "1"
    }
  }

  spec {
    project = "database"
    source {
      repo_url        = "registry-1.docker.io/bitnamicharts"
      chart           = "redis"
      target_revision = "21.2.0"

      helm {
        value_files = ["$values/redis/values.yaml"]
      }
    }

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      ref             = "values"
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

  depends_on = [argocd_project.projects["database"]]
}


## Deprecated
#resource "helm_release" "redis" {
#  name            = "redis"
#  namespace       = kubernetes_namespace.namespaces["database"].metadata[0].name
#  chart           = "redis"
#  repository      = "oci://registry-1.docker.io/bitnamicharts"
#  version         = "21.1.3"
#  cleanup_on_fail = true
#
#
#  values = [
#    yamlencode(yamldecode(templatefile("redis-values.yaml", {
#      architecture  = "standalone"
#      storage_class = "longhorn"
#      pvc_size      = "5Gi"
#      redis_secret  = kubernetes_secret.redis_auth.metadata[0].name
#    })))
#  ]
#
#  depends_on = [kubernetes_secret.redis_auth]
#}
