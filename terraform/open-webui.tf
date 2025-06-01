# Deploy Open WebUI via Helm
resource "helm_release" "open_webui" {
  name            = "open-webui"
  namespace       = kubernetes_namespace.namespaces["ai"].metadata[0].name
  chart           = "open-webui"
  repository      = "https://open-webui.github.io/helm-charts"
  version         = "5.20.0"
  cleanup_on_fail = true

  values = [
    yamlencode(yamldecode(templatefile("${path.module}/open-webui-values.yaml", {
      open-webui_ingress_fqdn = "chat.schwitzd.me"
      ollama_host             = "http://ollama.ai.svc.cluster.local:11434"
    })))
  ]
}
