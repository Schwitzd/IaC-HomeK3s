# Vault path
data "vault_generic_secret" "postgresql" {
  path = "${var.vault_name}/postgresql"
}

# PostgreSQL secret
resource "kubernetes_secret" "postgresql_auth" {
  metadata {
    name      = "postgresql-auth"
    namespace = kubernetes_namespace.namespaces["database"].metadata[0].name
  }

  data = {
    postgres-password = data.vault_generic_secret.postgresql.data["postgres"]
    username          = data.vault_generic_secret.postgresql.data["username"]
    password          = data.vault_generic_secret.postgresql.data["password"]
  }

  type = "Opaque"
}

# PostgreSQL deployment
resource "argocd_application" "postgresql" {
  metadata {
    name      = "postgresql"
    namespace = "argocd"
  }

  spec {
    project = "database"

    source {
      repo_url        = "registry-1.docker.io/bitnamicharts"
      chart           = "postgresql"
      target_revision = "16.7.19"

      helm {
        value_files = ["$values/postgresql/values.yaml"]
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
    argocd_project.projects["database"],
    kubernetes_secret.postgresql_auth,
    argocd_application.longhorn
  ]
}

## Deprecated
#resource "helm_release" "postgresql" {
#  name            = "postgresql"
#  namespace       = kubernetes_namespace.namespaces["database"].metadata[0].name
#  chart           = "postgresql"
#  repository      = "oci://registry-1.docker.io/bitnamicharts"
#  version         = "16.5.5"
#  cleanup_on_fail = true
#
#  values = [
#    "${file("postgresql-values.yaml")}",
#    jsonencode({
#      global = {
#        postgresql = {
#          auth = {
#            postgresPassword = data.vault_generic_secret.postgresql.data["postgres"]
#            username         = data.vault_generic_secret.postgresql.data["username"]
#            password         = data.vault_generic_secret.postgresql.data["password"]
#          }
#        }
#      }
#    })
#  ]
#}
