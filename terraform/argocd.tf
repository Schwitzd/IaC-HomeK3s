# Vault path
data "vault_generic_secret" "argocd_admin" {
  path = "${var.vault_name}/argocd/admin"
}

data "vault_generic_secret" "argocd_cluster_vps" {
  path = "${var.vault_name}/argocd/clusters/vps"
}

data "vault_generic_secret" "argocd_github" {
  path = "${var.vault_name}/argocd/github"
}

# ArgoCD - Bootstrap deployment
resource "helm_release" "argocd" {
  name            = "argocd"
  namespace       = kubernetes_namespace.namespaces["argocd"].metadata[0].name
  chart           = "argo-cd"
  repository      = "https://argoproj.github.io/argo-helm"
  version         = "9.5.11"
  cleanup_on_fail = true

  values = [
    yamlencode(yamldecode(templatefile("${path.module}/argocd/values.yaml", {
      argocd_domain                = "argocd.home.schwitzd.me"
      argocd_server_admin_password = bcrypt(data.vault_generic_secret.argocd_admin.data["password"])
    })))
  ]

  depends_on = [
    kubernetes_namespace.namespaces["argocd"]
  ]
}

resource "kubernetes_manifest" "argocd_tls" {
  manifest = yamldecode(templatefile("${path.module}/argocd/tls.yaml", {}))

  depends_on = [helm_release.argocd]
}

# ArgoCD - ApplicationSet Farm apps autodiscovery
resource "kubernetes_manifest" "apps_autodiscovery_farm" {
  manifest = yamldecode(file("${path.module}/argocd/apps-autodiscovery-farm.yaml"))

  depends_on = [
    helm_release.argocd,
    argocd_repository.gitops,
  ]
}

# ArgoCD - GitOps Repository
resource "argocd_repository" "gitops" {
  name       = "GitOps-HomeK3s"
  repo       = data.vault_generic_secret.argocd_github.data["github_repo"]
  type       = "git"
  username   = data.vault_generic_secret.argocd_github.data["github_username"]
  password   = data.vault_generic_secret.argocd_github.data["github_pat"]

  depends_on = [
    helm_release.argocd
  ]
}

# ArgoCD - VPS Cluster
resource "kubernetes_secret_v1" "argocd_cluster_vps_secret" {
  metadata {
    name      = "argocd-cluster-vps"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }

  type = "Opaque"

  data_wo = {
    name   = "vps"
    server = data.vault_generic_secret.argocd_cluster_vps.data["hostname"]
    config = jsonencode({
      bearerToken = data.vault_generic_secret.argocd_cluster_vps.data["bearer_token"]
      tlsClientConfig = {
        insecure = false
        caData   = data.vault_generic_secret.argocd_cluster_vps.data["ca_data"]
      }
    })
  }
  data_wo_revision = 10
}
