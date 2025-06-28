resource "helm_release" "metallb" {
  name            = "metallb"
  namespace       = kubernetes_namespace.namespaces["infrastructure"].metadata[0].name
  chart           = "metallb"
  repository      = "https://metallb.github.io/metallb"
  version         = "0.15.2"
  cleanup_on_fail = true

  values = [
    yamlencode(yamldecode(templatefile("${path.module}/metallb-values.yaml", {})))
  ]
}

resource "kubernetes_manifest" "metallb_ip" {
  manifest = yamldecode(templatefile("${path.module}/metallb-ip.yaml", {}))

  depends_on = [helm_release.metallb]
}

resource "kubernetes_manifest" "metallb_l2" {
  manifest = yamldecode(templatefile("${path.module}/metallb-l2.yaml", {}))

  depends_on = [helm_release.metallb]
}
