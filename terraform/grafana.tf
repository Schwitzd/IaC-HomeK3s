data "vault_generic_secret" "grafana" {
  path = "${var.vault_name}/grafana"
}

resource "helm_release" "grafana" {
  name            = "grafana"
  namespace       = kubernetes_namespace.namespaces["monitoring"].metadata[0].name
  chart           = "grafana"
  repository      = "https://grafana.github.io/helm-charts"
  version         = "8.12.1"
  cleanup_on_fail = true

  values = [
    "${file("grafana-values.yaml")}",
    jsonencode({
      adminUser     = data.vault_generic_secret.grafana.data["user"]
      adminPassword = data.vault_generic_secret.grafana.data["password"]
    })
  ]

  depends_on = [helm_release.prometheus]
}
