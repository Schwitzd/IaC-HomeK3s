# Vault path
data "vault_generic_secret" "fastapi_mailer" {
  path = "${var.vault_name}/fastapi-mailer"
}

# fastapi-mailer secret
resource "kubernetes_secret" "fastapi_mailer_secret" {
  metadata {
    name      = "fastapi-mailer-secret"
    namespace = kubernetes_namespace.namespaces["services"].metadata[0].name
  }

  data = {
    SMTP_HOST     = data.vault_generic_secret.fastapi_mailer.data["smtp_host"]
    SMTP_PORT     = data.vault_generic_secret.fastapi_mailer.data["smtp_port"]
    SMTP_USERNAME = data.vault_generic_secret.fastapi_mailer.data["smtp_username"]
    SMTP_PASSWORD = data.vault_generic_secret.fastapi_mailer.data["smtp_password"]
    FROM_EMAIL    = data.vault_generic_secret.fastapi_mailer.data["from_email"]
  }

  type = "Opaque"
}

# fastapi-mailer deployment
resource "argocd_application" "fastapi_mailer" {
  metadata {
    name      = "fastapi-mailer"
    namespace = "argocd"
  }

  spec {
    project = "services"

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      path            = "fastapi-mailer"
      ref             = "values"

      helm {
        value_files = ["$values/fastapi-mailer/values.yaml"]
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "services"
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
    argocd_project.projects["services"],
    kubernetes_secret.fastapi_mailer_secret
  ]
}

## Deprecated
#resource "kubernetes_manifest" "fastapi_mailer_deployment" {
#  manifest = yamldecode(templatefile("${path.module}/fastapi-mailer-deployment.yaml", {
#    namespace = kubernetes_namespace.namespaces["services"].metadata[0].name
#    image     = "harbor.schwitzd.me/library/fastapi-mailer:0.2.1"
#  }))
#}
#
#resource "kubernetes_manifest" "fastapi_mailer_service" {
#  manifest = yamldecode(templatefile("${path.module}/fastapi-mailer-service.yaml", {
#    namespace = kubernetes_namespace.namespaces["services"].metadata[0].name
#  }))
#}
#
#resource "kubernetes_manifest" "fastapi_mailer_ingress" {
#  manifest = yamldecode(templatefile("${path.module}/fastapi-mailer-ingress.yaml", {
#    namespace = kubernetes_namespace.namespaces["services"].metadata[0].name
#  }))
#}


