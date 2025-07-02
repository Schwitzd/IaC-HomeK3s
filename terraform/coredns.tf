resource "helm_release" "coredns" {
  name            = "coredns"
  namespace       = "kube-system"
  repository      = "https://coredns.github.io/helm"
  chart           = "coredns"
  version         = "1.43.0"
  cleanup_on_fail = true

  values = [
    yamlencode(yamldecode(templatefile("${path.module}/coredns-values.yaml", {
      coredns_ipv4 = "10.43.0.10"
      coredns_ipv6 = "fd22:2025:6a6a:43::10"
    })))
  ]
}


resource "argocd_application" "coredns" {
  metadata {
    name      = "coredns"
    namespace = "infrastructure"
  }

  spec {
    project = "kube-system"

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      path            = "coredns"
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "kube-system"
    }

    sync_policy {
      automated {
        prune       = false
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

  depends_on = [argocd_project.projects["default"]]
}
