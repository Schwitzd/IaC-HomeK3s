data "vault_generic_secret" "minio" {
  path = "${var.vault_name}/minio"
}

resource "helm_release" "minio" {
  name            = "minio"
  namespace       = kubernetes_namespace.namespaces["storage"].metadata[0].name
  chart           = "minio"
  repository      = "oci://registry-1.docker.io/bitnamicharts"
  version         = "16.0.7"
  cleanup_on_fail = true

  values = [
    yamlencode(yamldecode(templatefile("${path.module}/minio-values.yaml", {
      minio_console_fqdn = "minio.schwitzd.me"
      minio_api_fqdn     = "minio.api.schwitzd.me"
      minio_root_user    = data.vault_generic_secret.minio.data["rootUser"]
      minio_root_pass    = data.vault_generic_secret.minio.data["rootPassword"]
    })))
  ]
}
