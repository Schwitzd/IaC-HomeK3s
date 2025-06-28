# Vault path
data "vault_generic_secret" "argocd" {
  path = "${var.vault_name}/argocd"
}

# ArgoCD Deployment
resource "helm_release" "argocd" {
  name            = "argocd"
  namespace       = kubernetes_namespace.namespaces["infrastructure"].metadata[0].name
  chart           = "argo-cd"
  repository      = "https://argoproj.github.io/argo-helm"
  version         = "8.0.14"
  cleanup_on_fail = true

  values = [
    yamlencode(yamldecode(templatefile("${path.module}/argocd-values.yaml", {
      argocd_domain                = "argocd.schwitzd.me"
      argocd_server_admin_password = bcrypt(data.vault_generic_secret.argocd.data["password"])
    })))
  ]
}

# ArgoCD  Image Deployment
resource "helm_release" "argocd_image_updater" {
  name            = "argocd-image-updater"
  namespace       = kubernetes_namespace.namespaces["infrastructure"].metadata[0].name
  chart           = "argocd-image-updater"
  repository      = "https://argoproj.github.io/argo-helm"
  cleanup_on_fail = true

  values = [
    yamlencode(yamldecode(templatefile("${path.module}/argocd-image-updater-values.yaml", {
      argocd_server_address = data.vault_generic_secret.argocd.data["hostname"]
      harbor_api_url        = data.vault_generic_secret.harbor.data["externalURL"]
      harbor_credential     = data.vault_generic_secret.argocd.data["harbor_credential"]
    })))
  ]

  depends_on = [helm_release.argocd]
}

# ArgoCD projects
locals {
  argocd_projects = {
    monitoring = {
      description = "Monitoring, alerting, and observability services for the cluster"
      namespaces  = ["monitoring"]
      source_repos = [
        argocd_repository.repos["github_gitops"].repo,
        argocd_repository.repos["prometheus_helm"].repo
      ]
    },
    infrastructure = {
      description = "Workloads for all infrastructure services"
      namespaces  = ["infrastructure", "cattle-system"]
      source_repos = [
        argocd_repository.repos["github_gitops"].repo,
        argocd_repository.repos["rancher_helm"].repo
      ]
      cluster_resource_whitelist = [
        { group = "rbac.authorization.k8s.io", kind = "ClusterRole" },
        { group = "rbac.authorization.k8s.io", kind = "ClusterRoleBinding" },
        { group = "scheduling.k8s.io", kind = "PriorityClass" }
      ]
    },
    stocks = {
      description = "Workloads for all stock analysis, scraping, and trading-related services"
      namespaces  = ["stocks"]
      source_repos = [
        argocd_repository.repos["github_gitops"].repo
      ]
    },
    services = {
      description = "Reusable helper services and supporting workflows for the cluster"
      namespaces  = ["services"]
      source_repos = [
        argocd_repository.repos["github_gitops"].repo
      ]
    },
    database = {
      description = "Workloads for database services and supporting resources"
      namespaces  = ["database"]
      source_repos = [
        argocd_repository.repos["github_gitops"].repo,
        argocd_repository.repos["bitnami_helm"].repo,
        argocd_repository.repos["runix_helm"].repo
      ]
    },
    registry = {
      description = "Workloads for Harbor registry"
      namespaces  = ["registry"]
      source_repos = [
        argocd_repository.repos["github_gitops"].repo,
        argocd_repository.repos["bitnami_helm"].repo
      ]
    },
    longhorn = {
      description = "Workloads for Longhorn"
      namespaces  = ["longhorn-system"]
      source_repos = [
        argocd_repository.repos["github_gitops"].repo,
        argocd_repository.repos["longhorn_helm"].repo
      ]
      cluster_resource_whitelist = [
        { group = "apiextensions.k8s.io", kind = "CustomResourceDefinition" },
        { group = "rbac.authorization.k8s.io", kind = "ClusterRole" },
        { group = "rbac.authorization.k8s.io", kind = "ClusterRoleBinding" },
        { group = "scheduling.k8s.io", kind = "PriorityClass" }
      ]
    }
  }
}

resource "argocd_project" "projects" {
  for_each = local.argocd_projects

  metadata {
    name      = each.key
    namespace = "infrastructure"
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

  depends_on = [argocd_repository.repos]
}

# ArgoCD Repositories
locals {
  argocd_repositories = {
    github_gitops = {
      name     = "GitOps-HomeK3s"
      type     = "git"
      url      = data.vault_generic_secret.argocd.data["github_repo"]
      username = data.vault_generic_secret.argocd.data["github_username"]
      password = data.vault_generic_secret.argocd.data["github_pat"]
    }
    bitnami_helm = {
      name       = "Bitnami"
      type       = "helm"
      url        = "registry-1.docker.io/bitnamicharts"
      enable_oci = true
    }
    longhorn_helm = {
      name = "Longhorn"
      type = "helm"
      url  = "https://charts.longhorn.io"
    }
    runix_helm = {
      name = "Runix"
      type = "helm"
      url  = "https://helm.runix.net"
    }
    rancher_helm = {
      name = "Rancher"
      type = "helm"
      url  = "https://releases.rancher.com/server-charts/latest"
    }
    prometheus_helm = {
      name = "Prometheus"
      type = "helm"
      url  = "https://prometheus-community.github.io/helm-charts"
    }
  }
}

resource "argocd_repository" "repos" {
  for_each = local.argocd_repositories

  repo       = each.value.url
  name       = each.value.name
  type       = each.value.type
  enable_oci = lookup(each.value, "enable_oci", false)
  username   = lookup(each.value, "username", null)
  password   = lookup(each.value, "password", null)
}
