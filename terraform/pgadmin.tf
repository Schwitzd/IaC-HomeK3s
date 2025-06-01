data "vault_generic_secret" "pgadmin" {
  path = "${var.vault_name}/pgadmin"
}

resource "helm_release" "pgadmin" {
  name       = "pgadmin"
  namespace  = kubernetes_namespace.namespaces["database"].metadata[0].name
  chart      = "pgadmin4"
  repository = "https://helm.runix.net"
  version    = "1.36.0"
  cleanup_on_fail = true

  values = [
    yamlencode(yamldecode(templatefile("${path.module}/pgadmin-values.yaml", {
      pgadmin_ingress_fqdn = "pgadmin.schwitzd.me"
      pgadmin_email        = data.vault_generic_secret.pgadmin.data["email"]
      pgadmin_password     = data.vault_generic_secret.pgadmin.data["password"]
    })))
  ]

  depends_on = [helm_release.postgresql]
}