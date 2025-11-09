# Vault path
data "vault_generic_secret" "argocd" {
  path = "${var.vault_name}/argocd"
}

# ArgoCD Deployment
resource "helm_release" "argocd" {
  name            = "argocd"
  namespace       = kubernetes_namespace.namespaces["argocd"].metadata[0].name
  chart           = "argo-cd"
  repository      = "https://argoproj.github.io/argo-helm"
  version         = "9.0.5"
  cleanup_on_fail = true

  values = [
    yamlencode(yamldecode(templatefile("${path.module}/argocd-values.yaml", {
      argocd_domain                = "argocd.home.schwitzd.me"
      argocd_server_admin_password = bcrypt(data.vault_generic_secret.argocd.data["password"])
    })))
  ]

  depends_on = [
    kubernetes_namespace.namespaces["argocd"]
  ]
}

resource "argocd_application" "argocd" {
  metadata {
    name      = "argocd"
    namespace = "argocd"
  }

  spec {
    project = "default"
    source {
      repo_url        = "https://argoproj.github.io/argo-helm"
      chart           = "argo-cd"
      target_revision = "9.1.0"

      helm {
        value_files = ["$values/argocd/values.yaml"]
      }
    }

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      ref             = "values"
      path            = "argocd"

      directory {
        recurse = true
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "argocd"
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
    kubernetes_namespace.namespaces["argocd"]
  ]
}

# ArgoCD projects - DEPRECATED
#resource "argocd_project" "projects" {
#  for_each = local.argocd_projects
#
#  metadata {
#    name      = each.key
#    namespace = kubernetes_namespace.namespaces["argocd"].metadata[0].name
#  }
#
#  spec {
#    description  = each.value.description
#    source_repos = each.value.source_repos
#
#    dynamic "destination" {
#      for_each = each.value.namespaces
#      content {
#        server    = "https://kubernetes.default.svc"
#        namespace = destination.value
#      }
#    }
#
#    dynamic "cluster_resource_whitelist" {
#      for_each = lookup(each.value, "cluster_resource_whitelist", [])
#      content {
#        group = cluster_resource_whitelist.value.group
#        kind  = cluster_resource_whitelist.value.kind
#      }
#    }
#  }
#
#  depends_on = [
#    helm_release.argocd,
#    argocd_repository.repos
#  ]
#}

# ArgoCD Repositories
resource "argocd_repository" "repos" {
  for_each = local.argocd_repositories

  repo       = each.value.url
  name       = each.value.name
  type       = each.value.type
  enable_oci = lookup(each.value, "enable_oci", false)
  username   = lookup(each.value, "username", null)
  password   = lookup(each.value, "password", null)

  depends_on = [
    helm_release.argocd
  ]
}
