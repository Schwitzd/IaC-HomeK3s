resource "argocd_application" "longhorn" {
  metadata {
    name      = "longhorn"
    namespace = "infrastructure"
  }

  spec {
    project = "longhorn"
    source {
      repo_url        = "https://charts.longhorn.io"
      chart           = "longhorn"
      target_revision = "1.9.0"

      helm {
        value_files = ["$values/longhorn/values.yaml"]
      }
    }

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      ref             = "values"
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "longhorn-system"
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

    ignore_difference {
      group         = "apiextensions.k8s.io"
      kind          = "CustomResourceDefinition"
      json_pointers = ["/spec/preserveUnknownFields"]
    }
  }

  depends_on = [argocd_project.projects["longhorn"]]
}

## Deprecated
#resource "helm_release" "longhorn" {
#  name            = "longhorn"
#  namespace       = kubernetes_namespace.namespaces["longhorn-system"].metadata[0].name
#  chart           = "longhorn"
#  repository      = "https://charts.longhorn.io"
#  version         = "1.8.1"
#  cleanup_on_fail = true
#
#  values = [
#    yamlencode(yamldecode(templatefile("longhorn-values.yaml", {
#      longhorn_default_replica_count = 2,
#      longhorn_default_data_path     = "/mnt/nvme0/longhorn"
#      longhorn_ingress_fqdn          = "longhorn.schwitzd.me"
#    })))
#  ]
#}
