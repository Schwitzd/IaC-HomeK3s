resource "argocd_application" "rook_ceph_operator" {
  metadata {
    name      = "rook-ceph-operator"
    namespace = "argocd"
  }

  spec {
    project = "rook-ceph"

    source {
      repo_url        = "https://charts.rook.io/release"
      chart           = "rook-ceph"
      target_revision = "1.18.4"

      helm {
        value_files = ["$values/rook-ceph-operator/values.yaml"]
      }
    }

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      ref             = "values"
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "rook-ceph"
    }

    sync_policy {
      automated {
        prune       = true
        self_heal   = true
        allow_empty = false
      }

      sync_options = [
        "ServerSideApply=true"
      ]

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

  depends_on = [
    helm_release.argocd,
    kubernetes_namespace.namespaces["rook-ceph"],
    argocd_project.projects["rook-ceph"]
  ]
}

resource "argocd_application" "rook_ceph_cluster" {
  metadata {
    name      = "rook-ceph-cluster"
    namespace = "argocd"
  }

  spec {
    project = "rook-ceph"

    source {
      repo_url        = "https://charts.rook.io/release"
      chart           = "rook-ceph-cluster"
      target_revision = "1.18.4"

      helm {
        value_files = ["$values/rook-ceph-cluster/values.yaml"]
      }
    }

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      ref             = "values"
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "rook-ceph"
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

  depends_on = [
    helm_release.argocd,
    kubernetes_namespace.namespaces["rook-ceph"],
    argocd_project.projects["rook-ceph"],
    argocd_application.rook_ceph_operator
  ]
}
