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
  version         = "8.2.4"
  cleanup_on_fail = true

  values = [
    yamlencode(yamldecode(templatefile("${path.module}/argocd-values.yaml", {
      argocd_domain                = "argocd.schwitzd.me"
      argocd_server_admin_password = bcrypt(data.vault_generic_secret.argocd.data["password"])
    })))
  ]

  depends_on = [
    kubernetes_namespace.namespaces["argocd"]
  ]
}

# ArgoCD projects
resource "argocd_project" "projects" {
  for_each = local.argocd_projects

  metadata {
    name      = each.key
    namespace = kubernetes_namespace.namespaces["argocd"].metadata[0].name
  }

  spec {
    description  = each.value.description
    source_repos = each.value.source_repos

    dynamic "destination" {
      for_each = each.value.namespaces
      content {
        server    = "https://kubernetes.default.svc"
        namespace = destination.value
      }
    }

    dynamic "cluster_resource_whitelist" {
      for_each = lookup(each.value, "cluster_resource_whitelist", [])
      content {
        group = cluster_resource_whitelist.value.group
        kind  = cluster_resource_whitelist.value.kind
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    argocd_repository.repos
  ]
}

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
