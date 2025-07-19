# Vault path
data "vault_generic_secret" "harbor" {
  path = "${var.vault_name}/harbor"
}

# Harbor secret
resource "kubernetes_secret" "harbor_external_db" {
  metadata {
    name      = "harbor-db-creds"
    namespace = kubernetes_namespace.namespaces["registry"].metadata[0].name
  }

  data = {
    db-password = data.vault_generic_secret.harbor.data["db_password"]
  }

  type = "Opaque"
}

resource "kubernetes_secret" "harbor_external_redis" {
  metadata {
    name      = "harbor-redis-creds"
    namespace = kubernetes_namespace.namespaces["registry"].metadata[0].name
  }

  data = {
    redis-password = data.vault_generic_secret.redis.data["password"]
  }

  type = "Opaque"
}

# Harbor deployment
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
          name  = "externalDatabase.user"
          value = data.vault_generic_secret.harbor.data["db_username"]
        }
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
    argocd_project.projects["registry"],
    kubernetes_secret.harbor_external_db,
    kubernetes_secret.harbor_external_redis,
    argocd_application.longhorn,
    argocd_application.postgresql,
    argocd_application.redis
  ]
}

## Deprecated
#resource "helm_release" "harbor" {
#  name            = "harbor"
#  namespace       = kubernetes_namespace.namespaces["registry"].metadata[0].name
#  chart           = "harbor"
#  repository      = "oci://registry-1.docker.io/bitnamicharts"
#  version         = "25.0.2"
#  cleanup_on_fail = true
#
#  values = [
#    yamlencode(yamldecode(templatefile("harbor-values.yaml", {
#      adminPassword              = data.vault_generic_secret.harbor.data["adminPassword"]
#      externalURL                = "https://${data.vault_generic_secret.harbor.data["externalURL"]}"
#      harbor_ingress_fqdn        = data.vault_generic_secret.harbor.data["externalURL"]
#      external_database_host     = data.vault_generic_secret.harbor.data["db_hostname"]
#      external_database_user     = data.vault_generic_secret.harbor.data["db_username"]
#      external_database_password = data.vault_generic_secret.harbor.data["db_password"]
#      external_redis_host        = "redis-master.database.svc.cluster.local"
#      external_redis_port        = 6379
#      external_redis_password    = data.vault_generic_secret.redis.data["password"]
#    })))
#  ]
#
#  depends_on = [helm_release.postgresql]
#}
