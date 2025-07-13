# Ark-website backend deployment
resource "argocd_application" "ark_website_backend" {
  metadata {
    name      = "ark-website-backend"
    namespace = "argocd"
  }

  spec {
    project = "stocks"

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      path            = "ark-website/backend"
      ref             = "values"

      helm {
        value_files = ["$values/ark-website/backend/values.yaml"]
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "stocks"
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
    kubernetes_secret.ark_website_backend_secret,
    argocd_project.projects["stocks"]
  ]
}

# Ark-website frontend deplyoment
resource "argocd_application" "ark_website_frontend" {
  metadata {
    name      = "ark-website-frontend"
    namespace = "argocd"
  }

  spec {
    project = "stocks"

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      path            = "ark-website/frontend"
      ref             = "values"

      helm {
        value_files = ["$values/ark-website/frontend/values.yaml"]
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "stocks"
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
    kubernetes_secret.ark_website_frontend_secret,
    argocd_project.projects["stocks"]
  ]
}

## Deprecated
#resource "kubernetes_manifest" "ark_website_backend_deployment" {
#  manifest = yamldecode(templatefile("${path.module}/ark-website-backend-deployment.yaml", {
#    namespace = kubernetes_namespace.namespaces["stocks"].metadata[0].name
#    image     = "harbor.schwitzd.me/library/ark-website-backend:1.0.6"
#  }))
#
#  depends_on = [kubernetes_secret.ark_website_backend_secret]
#}
#
#resource "kubernetes_manifest" "ark_website_backend_service" {
#  manifest = yamldecode(templatefile("${path.module}/ark-website-backend-service.yaml", {
#    namespace = kubernetes_namespace.namespaces["stocks"].metadata[0].name
#  }))
#
#  depends_on = [kubernetes_manifest.ark_website_backend_deployment]
#}
#
#resource "kubernetes_manifest" "ark_website_backend_middleware" {
#  manifest = yamldecode(templatefile("${path.module}/ark-website-backend-middleware.yaml", {
#    ark_ingress_fqdn = "ark.api.schwitzd.me"
#    namespace        = kubernetes_namespace.namespaces["stocks"].metadata[0].name
#  }))
#
#  depends_on = [kubernetes_manifest.ark_website_backend_ingress]
#}
#
#resource "kubernetes_manifest" "ark_website_backend_ingress" {
#  manifest = yamldecode(templatefile("${path.module}/ark-website-backend-ingress.yaml", {
#    ark_ingress_fqdn = "ark.api.schwitzd.me"
#    namespace        = kubernetes_namespace.namespaces["stocks"].metadata[0].name
#  }))
#
#  depends_on = [kubernetes_manifest.ark_website_backend_service]
#}
#
#resource "kubernetes_manifest" "ark_website_frontend_deployment" {
#  manifest = yamldecode(templatefile("${path.module}/ark-website-frontend-deployment.yaml", {
#    namespace = kubernetes_namespace.namespaces["stocks"].metadata[0].name
#    image     = "harbor.schwitzd.me/library/ark-website-frontend:1.3.1"
#  }))
#
#  depends_on = [kubernetes_secret.ark_website_frontend_secret]
#}
#
#resource "kubernetes_manifest" "ark_website_frontend_service" {
#  manifest = yamldecode(templatefile("${path.module}/ark-website-frontend-service.yaml", {
#    namespace = kubernetes_namespace.namespaces["stocks"].metadata[0].name
#  }))
#
#  depends_on = [kubernetes_manifest.ark_website_frontend_deployment]
#}
#
#resource "kubernetes_manifest" "ark_website_frontend_ingress" {
#  manifest = yamldecode(templatefile("${path.module}/ark-website-frontend-ingress.yaml", {
#    ark_ingress_fqdn = "ark.schwitzd.me"
#    namespace        = kubernetes_namespace.namespaces["stocks"].metadata[0].name
#  }))
#
#  depends_on = [kubernetes_manifest.ark_website_frontend_service]
#}
#
#resource "kubernetes_secret" "ark_website_frontend_secret" {
#  metadata {
#    name      = "ark-website-frontend-secret"
#    namespace = kubernetes_namespace.namespaces["stocks"].metadata[0].name
#  }
#
#  data = {
#    NEXT_PUBLIC_ARK_BACKEND_URL = data.vault_generic_secret.ark.data["backend_url"]
#    NEXT_PUBLIC_ARK_BACKEND_API = data.vault_generic_secret.ark.data["backend_api"]
#  }
#
#  type = "Opaque"
#}
#
#resource "kubernetes_secret" "ark_website_backend_secret" {
#  metadata {
#    name      = "ark-website-backend-secret"
#    namespace = kubernetes_namespace.namespaces["stocks"].metadata[0].name
#  }
#
#  data = {
#    POSTGRES_DB       = data.vault_generic_secret.ark.data["postgres_db"]
#    POSTGRES_USER     = data.vault_generic_secret.ark.data["postgres_user"]
#    POSTGRES_PASSWORD = data.vault_generic_secret.ark.data["postgres_password"]
#    POSTGRES_HOST     = data.vault_generic_secret.postgresql.data["hostname"]
#    POSTGRES_PORT     = data.vault_generic_secret.postgresql.data["port"]
#    ARK_BACKEND_API   = data.vault_generic_secret.ark.data["backend_api"]
#  }
#
#  type = "Opaque"
#}