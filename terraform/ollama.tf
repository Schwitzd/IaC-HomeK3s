resource "helm_release" "ollama" {
  name            = "ollama"
  namespace       = kubernetes_namespace.namespaces["ai"].metadata[0].name
  chart           = "ollama"
  repository      = "https://otwld.github.io/ollama-helm"
  version         = "1.8.0"
  cleanup_on_fail = true

  values = [
    yamlencode(yamldecode(templatefile("ollama-values.yaml", {
      ollama_ingress_fqdn = "ollama.api.schwitzd.me"
    })))
  ]
}