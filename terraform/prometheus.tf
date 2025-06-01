resource "helm_release" "prometheus" {
  name            = "prometheus"
  namespace       = kubernetes_namespace.namespaces["monitoring"].metadata[0].name
  repository      = "https://prometheus-community.github.io/helm-charts"
  chart           = "prometheus"
  version         = "27.11.0"
  cleanup_on_fail = true

  values = [
    "${file("prometheus-values.yaml")}"
  ]
}
