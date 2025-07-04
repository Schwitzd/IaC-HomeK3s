data "vault_generic_secret" "cert_manager" {
  path = "${var.vault_name}/cert-manager"
}

resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = kubernetes_namespace.namespaces["infrastructure"].metadata[0].name
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
                  name = "cloudflare-api-token"
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
  namespace       = kubernetes_namespace.namespaces["infrastructure"].metadata[0].name
  repository      = "https://charts.jetstack.io"
  chart           = "cert-manager"
  version         = "1.18.1"
  cleanup_on_fail = true

  set = [
    {
      name  = "crds.enabled"
      value = "true"
    }
  ]
}
