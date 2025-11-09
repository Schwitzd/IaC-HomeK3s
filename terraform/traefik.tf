resource "helm_release" "traefik" {
  name            = "traefik"
  namespace       = kubernetes_namespace.namespaces["infrastructure"].metadata[0].name
  chart           = "traefik"
  repository      = "https://traefik.github.io/charts"
  version         = "37.1.2"
  cleanup_on_fail = true

  values = [
    yamlencode(yamldecode(templatefile("${path.module}/traefik-values.yaml", {
      traefik_ipv4 = "192.168.14.50"
      traefik_ipv6 = "fd12:3456:789a:14::50"
    })))
  ]

  depends_on = [
    helm_release.cilium,
    helm_release.cert_manager
  ]
}

# Traefik Deployment
resource "argocd_application" "traefik" {
  metadata {
    name      = "traefik"
    namespace = "argocd"
  }

  spec {
    project = "infrastructure"

    source {
      repo_url        = "https://traefik.github.io/charts"
      chart           = "traefik"
      target_revision = "37.1.2"

      helm {
        value_files = ["$values/traefik/values.yaml"]
      }
    }

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      ref             = "values"
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "infrastructure"
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

      sync_options = [
        "ApplyOutOfSyncOnly=true"
      ]
    }
  }

  depends_on = [
    helm_release.argocd
  ]
}
