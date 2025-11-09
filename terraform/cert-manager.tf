data "vault_generic_secret" "cert_manager" {
  path = "${var.vault_name}/cert-manager"
}

resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "auth-api-cloudflare"
    namespace = kubernetes_namespace.namespaces["pki"].metadata[0].name
  }

  type = "Opaque"

  data = {
    "api-token" = "${data.vault_generic_secret.cert_manager.data.cloudflare_api}"
  }
}

## ClusterIssuer
resource "kubernetes_manifest" "le_clusterissuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "le-clusterissuer"
    }
    spec = {
      acme = {
        email  = "${data.vault_generic_secret.cert_manager.data.email}"
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "cloudflare-key"
        }
        solvers = [
          {
            dns01 = {
              cloudflare = {
                apiTokenSecretRef = {
                  name = "auth-api-cloudflare"
                  key  = "api-token"
                }
              }
            }
          }
        ]
      }
    }
  }

depends_on = [
  helm_release.cert_manager,
  kubernetes_secret.cloudflare_api_token
]
}

# cert-manager
resource "helm_release" "cert_manager" {
  name            = "cert-manager"
  namespace       = kubernetes_namespace.namespaces["pki"].metadata[0].name
  repository      = "https://charts.jetstack.io"
  chart           = "cert-manager"
  version         = "1.18.2"
  cleanup_on_fail = true


  set = [
    {
      name  = "crds.enabled"
      value = "true"
    }
  ]

  depends_on = [ 
    kubernetes_namespace.namespaces["kpi"]
   ]
}

# cert-manager deployment
resource "argocd_application" "cert_manager" {
  metadata {
    name      = "cert-manager"
    namespace = "argocd"
  }

  spec {
    project = "pki"

    source {
      repo_url        = "https://charts.jetstack.io"
      chart           = "cert-manager"
      target_revision = "1.18.2"

      helm {
        value_files = ["$values/cert-manager/values.yaml"]
      }
    }

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      ref             = "values"
      path            = "cert-manager"

      directory {
        recurse = true
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "pki"
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

  depends_on = [
    helm_release.argocd
  ]
}

# farm-ca deployment
resource "argocd_application" "farm_ca" {
  metadata {
    name      = "farm-ca"
    namespace = "argocd"
  }

  spec {
    project = "pki"

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      path            = "farm-ca"

      directory {
        recurse = true
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "pki"
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

      sync_options = [
        "ApplyOutOfSyncOnly=true"
      ]
    }
  }

  depends_on = [
    helm_release.argocd
  ]
}
