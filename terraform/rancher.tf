data "vault_generic_secret" "rancher" {
  path = "${var.vault_name}/rancher"
}

resource "helm_release" "rancher" {
  name            = "rancher"
  namespace       = kubernetes_namespace.namespaces["cattle-system"].metadata[0].name
  chart           = "rancher"
  repository      = "https://releases.rancher.com/server-charts/latest"
  version         = "2.10.3"
  cleanup_on_fail = true

  values = [
    yamlencode(yamldecode(templatefile("rancher-values.yaml", {
      rancher_ingress_fqdn = "rancher.schwitzd.me"
      rancher_password     = data.vault_generic_secret.rancher.data["password"]
    })))
  ]

  depends_on = [data.vault_generic_secret.rancher]
}
