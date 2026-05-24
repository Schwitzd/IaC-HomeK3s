locals {
  github_gitops_repo_url = data.vault_generic_secret.argocd_github.data["github_repo"]
  namespaces = [
    "observability", "services", "database", "registry", "stocks", "productivity", "secrets",
    "argocd", "ai", "cattle-system", "rook-ceph", "storage", "pki", "identity", "edge-gateway",
    "cicd"
  ]

  # Argo CD - Repositories
  argocd_repositories = {
    github_gitops = {
      name     = "GitOps-HomeK3s"
      type     = "git"
      url      = data.vault_generic_secret.argocd_github.data["github_repo"]
      username = data.vault_generic_secret.argocd_github.data["github_username"]
      password = data.vault_generic_secret.argocd_github.data["github_pat"]
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
    },
    paperless_helm = {
      name       = "Paperless"
      type       = "helm"
      url        = "codeberg.org/wrenix/helm-charts"
      enable_oci = true
    },
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
