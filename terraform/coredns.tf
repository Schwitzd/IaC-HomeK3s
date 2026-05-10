resource "helm_release" "coredns" {
  name            = "coredns"
  namespace       = "kube-system"
  repository      = "https://coredns.github.io/helm"
  chart           = "coredns"
  version         = "1.45.2"
  cleanup_on_fail = true

  values = [
    yamlencode(yamldecode(templatefile("${path.module}/coredns-values.yaml", {
      coredns_ipv4 = "10.43.0.10"
      coredns_ipv6 = "fd22:2025:6a6a:ff::a"
    })))
  ]
}
