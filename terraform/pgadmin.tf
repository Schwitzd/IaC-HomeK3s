# Vault path
data "vault_generic_secret" "pgadmin" {
  path = "${var.vault_name}/pgadmin"
}

# Pgadmin secret
resource "kubernetes_secret" "pgadmin_secret" {
  metadata {
    name      = "pgadmin-secret"
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
      target_revision = "1.46.0"

      helm {
        value_files = ["$values/pgadmin/values.yaml"]
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
    kubernetes_secret.pgadmin_secret,
    argocd_application.longhorn
  ]
}

## Deprecated
#resource "helm_release" "pgadmin" {
#  name       = "pgadmin"
#  namespace  = kubernetes_namespace.namespaces["database"].metadata[0].name
#  chart      = "pgadmin4"
#  repository = "https://helm.runix.net"
#  version    = "1.36.0"
#  cleanup_on_fail = true
#
#  values = [
#    yamlencode(yamldecode(templatefile("${path.module}/pgadmin-values.yaml", {
#      pgadmin_ingress_fqdn = "pgadmin.schwitzd.me"
#      pgadmin_email        = data.vault_generic_secret.pgadmin.data["email"]
#      pgadmin_password     = data.vault_generic_secret.pgadmin.data["password"]
#    })))
#  ]
#
#}
