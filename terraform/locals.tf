locals {
  namespaces = [
    "observability", "services", "database", "registry", "stocks",
    "argocd", "infrastructure", "ai", "cattle-system", "rook-ceph", "storage"
  ]

  # Argo CD - Projects
  argocd_projects = {
    cilium = {
      description = "eBPF-based networking policy managed with Cilium "
      namespaces  = ["kube-system", "cilium-secrets", "infrastructure", "database", "stocks", "cattle-system", "services", "observability", "storage", "rook-ceph"]
      source_repos = [
        argocd_repository.repos["github_gitops"].repo,
        argocd_repository.repos["cilium_helm"].repo
      ]
      cluster_resource_whitelist = [
        { group = "", kind = "Namespace" },
        { group = "cilium.io", kind = "CiliumClusterwideNetworkPolicy" },
        { group = "rbac.authorization.k8s.io", kind = "ClusterRole" },
        { group = "rbac.authorization.k8s.io", kind = "ClusterRoleBinding" }
      ]
    },
    kube-system = {
      description = "Core Kubernetes system components and controllers managed by the cluster"
      namespaces  = ["kube-system"]
      source_repos = [
        argocd_repository.repos["github_gitops"].repo,
        argocd_repository.repos["coredns_helm"].repo
      ]
      cluster_resource_whitelist = [
        { group = "rbac.authorization.k8s.io", kind = "ClusterRole" },
        { group = "rbac.authorization.k8s.io", kind = "ClusterRoleBinding" }
      ]
    },
    observability = {
      description = "Monitoring, alerting, and observability services for the cluster"
      namespaces  = ["observability"]
      source_repos = [
        argocd_repository.repos["github_gitops"].repo,
        argocd_repository.repos["prometheus_helm"].repo,
        argocd_repository.repos["grafana_helm"].repo
      ]
      cluster_resource_whitelist = [
        { group = "rbac.authorization.k8s.io", kind = "ClusterRole" },
        { group = "rbac.authorization.k8s.io", kind = "ClusterRoleBinding" }
      ]
    },
    infrastructure = {
      description = "Workloads for all infrastructure services"
      namespaces  = ["infrastructure", "cattle-system", "kube-system", "storage"]
      source_repos = [
        argocd_repository.repos["github_gitops"].repo,
        argocd_repository.repos["rancher_helm"].repo,
        argocd_repository.repos["traefik_helm"].repo,
        argocd_repository.repos["cert-manager_helm"].repo,
        argocd_repository.repos["garage_helm"].repo
      ]
      cluster_resource_whitelist = [
        { group = "rbac.authorization.k8s.io", kind = "ClusterRole" },
        { group = "rbac.authorization.k8s.io", kind = "ClusterRoleBinding" },
        { group = "scheduling.k8s.io", kind = "PriorityClass" },
        { group = "apiextensions.k8s.io", kind = "CustomResourceDefinition" },
        { group = "admissionregistration.k8s.io", kind = "ValidatingWebhookConfiguration" },
        { group = "admissionregistration.k8s.io", kind = "MutatingWebhookConfiguration" },
        { group = "networking.k8s.io", kind = "IngressClass" }
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
        argocd_repository.repos["groundhog2k_helm"].repo,
        argocd_repository.repos["cnpg_helm"].repo,
        argocd_repository.repos["runix_helm"].repo
      ]
      cluster_resource_whitelist = [
        { group = "apiextensions.k8s.io", kind = "CustomResourceDefinition" },
        { group = "rbac.authorization.k8s.io", kind = "ClusterRole" },
        { group = "rbac.authorization.k8s.io", kind = "ClusterRoleBinding" },
        { group = "admissionregistration.k8s.io", kind = "MutatingWebhookConfiguration" },
        { group = "admissionregistration.k8s.io", kind = "ValidatingWebhookConfiguration" },
        { group = "storage.k8s.io", kind = "StorageClass" }
      ]
    },
    registry = {
      description = "Workloads for Harbor registry"
      namespaces  = ["registry"]
      source_repos = [
        argocd_repository.repos["github_gitops"].repo,
        argocd_repository.repos["bitnami_helm"].repo,
        argocd_repository.repos["harbor_helm"].repo
      ]
    },
    rook-ceph = {
      description = "Workloads for Rook Cech"
      namespaces  = ["rook-ceph"]
      source_repos = [
        argocd_repository.repos["github_gitops"].repo,
        argocd_repository.repos["rook_helm"].repo
      ]
      cluster_resource_whitelist = [
        { group = "apiextensions.k8s.io", kind = "CustomResourceDefinition" },
        { group = "rbac.authorization.k8s.io", kind = "ClusterRole" },
        { group = "rbac.authorization.k8s.io", kind = "ClusterRoleBinding" },
        { group = "storage.k8s.io", kind = "StorageClass" }
      ]
    }
  }

  # Argo CD - Repositories
  argocd_repositories = {
    github_gitops = {
      name     = "GitOps-HomeK3s"
      type     = "git"
      url      = data.vault_generic_secret.argocd.data["github_repo"]
      username = data.vault_generic_secret.argocd.data["github_username"]
      password = data.vault_generic_secret.argocd.data["github_pat"]
    },
    bitnami_helm = {
      name       = "Bitnami"
      type       = "helm"
      url        = "registry-1.docker.io/bitnamicharts"
      enable_oci = true
    },
    longhorn_helm = {
      name = "Longhorn"
      type = "helm"
      url  = "https://charts.longhorn.io"
    },
    runix_helm = {
      name = "Runix"
      type = "helm"
      url  = "https://helm.runix.net"
    },
    rancher_helm = {
      name = "Rancher"
      type = "helm"
      url  = "https://releases.rancher.com/server-charts/latest"
    },
    prometheus_helm = {
      name = "Prometheus"
      type = "helm"
      url  = "https://prometheus-community.github.io/helm-charts"
    },
    cilium_helm = {
      name = "Cilium"
      type = "helm"
      url  = "https://helm.cilium.io"
    },
    coredns_helm = {
      name = "CoreDNS"
      type = "helm"
      url  = "https://coredns.github.io/helm"
    },
    traefik_helm = {
      name = "Traefik"
      type = "helm"
      url  = "https://traefik.github.io/charts"
    },
    cert-manager_helm = {
      name = "cert-manager"
      type = "helm"
      url  = "https://charts.jetstack.io"
    },
    grafana_helm = {
      name = "grafana"
      type = "helm"
      url  = "https://grafana.github.io/helm-charts"
    },
    garage_helm = {
      name = "garage"
      type = "git"
      url  = "https://git.deuxfleurs.fr/Deuxfleurs/garage.git"
    },
    rook_helm = {
      name = "rook"
      type = "helm"
      url  = "https://charts.rook.io/release"
    },
    groundhog2k_helm = {
      name = "groundhog2k"
      type = "helm"
      url  = "https://groundhog2k.github.io/helm-charts/"
    },
    cnpg_helm = {
      name = "cloudnative-pg"
      type = "helm"
      url  = "https://cloudnative-pg.github.io/charts"
    },
    harbor_helm = {
      name = "harbor"
      type = "helm"
      url  = "https://helm.goharbor.io"
    }
  }

  # Ark Analyzer
  ark_analyzer_jobs = {
    "first-time-buys" = {
      values_file = "$values/ark-analyzer/values-first-time-buys.yaml"
    }
    "top-trades" = {
      values_file = "$values/ark-analyzer/values-top-trades.yaml"
    }
  }

}
