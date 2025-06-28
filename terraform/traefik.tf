resource "helm_release" "traefik" {
  name            = "traefik"
  namespace       = kubernetes_namespace.namespaces["infrastructure"].metadata[0].name
  chart           = "traefik"
  repository      = "https://traefik.github.io/charts"
  version         = "36.2.0"
  cleanup_on_fail = true

  values = [
    yamlencode(yamldecode(templatefile("${path.module}/traefik-values.yaml", {
      traefik_ipv4 = "192.168.14.50"
      traefik_ipv6 = "fd12:3456:789a:14::50"
    })))
  ]

  depends_on = [ helm_release.metallb ]
}
