
# Prometheus deployment
resource "argocd_application" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = "argocd"
  }

  spec {
    project = "monitoring"
    source {
      repo_url        = "https://prometheus-community.github.io/helm-charts"
      chart           = "prometheus"
      target_revision = "27.24.0"
      helm {
        value_files = ["$values/prometheus/values.yaml"]
      }
    }

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      ref             = "values"
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "monitoring"
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
    argocd_project.projects["monitoring"],
    argocd_application.longhorn
  ]
}


## Deprecated
#resource "helm_release" "prometheus" {
#  name            = "prometheus"
#  namespace       = kubernetes_namespace.namespaces["monitoring"].metadata[0].name
#  repository      = "https://prometheus-community.github.io/helm-charts"
#  chart           = "prometheus"
#  version         = "27.11.0"
#  cleanup_on_fail = true
#
#  values = [
#    "${file("prometheus-values.yaml")}"
#  ]
#}
