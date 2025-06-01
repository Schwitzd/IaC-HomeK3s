data "vault_generic_secret" "postgresql" {
  path = "${var.vault_name}/postgresql"
}

resource "helm_release" "postgresql" {
  name            = "postgresql"
  namespace       = kubernetes_namespace.namespaces["database"].metadata[0].name
  chart           = "postgresql"
  repository      = "oci://registry-1.docker.io/bitnamicharts"
  version         = "16.5.5"
  cleanup_on_fail = true

  values = [
    "${file("postgresql-values.yaml")}",
    jsonencode({
      global = {
        postgresql = {
          auth = {
            postgresPassword = data.vault_generic_secret.postgresql.data["postgres"]
            username         = data.vault_generic_secret.postgresql.data["username"]
            password         = data.vault_generic_secret.postgresql.data["password"]
          }
        }
      }
    })
  ]
}
