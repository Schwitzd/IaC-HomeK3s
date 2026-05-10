# Minimal Cilium deployment
resource "helm_release" "cilium" {
  name       = "cilium"
  namespace  = "kube-system"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.19.3"

  values = [
    templatefile("${path.module}/cilium-values.yaml", {
      cluster_ipv4_cidr        = "10.42.0.0/16"
      cluster_ipv6_cidr        = "fd22:2025:6a6a:00::/56"
      ipv4_native_routing_cidr = "10.42.0.0/16"
      ipv6_native_routing_cidr = "fd22:2025:6a6a:00::/56" 
      k8s_service_host         = "fd12:3456:789a:14:3161:c474:a553:4ea2"
      k8s_service_port         = "6443"
    })
  ]
}

# Cilium - IP Pool & L2
resource "kubernetes_manifest" "cilium_ip" {
  manifest = yamldecode(templatefile("${path.module}/cilium-ip.yaml", {}))

  depends_on = [helm_release.cilium]
}

resource "kubernetes_manifest" "cilium_l2" {
  manifest = yamldecode(templatefile("${path.module}/cilium-l2.yaml", {}))

  depends_on = [helm_release.cilium]
}

# Cilium netwokr policies
resource "kubernetes_manifest" "network_policies" {
  for_each = fileset("${path.module}/network-policies", "*.yaml")

  manifest = yamldecode(file("${path.module}/network-policies/${each.value}"))

  depends_on = [ 
    kubernetes_namespace.namespaces
   ]
}

# DEPRECATED: Cilium deployment
#resource "argocd_application" "cilium" {
#  metadata {
#    name      = "cilium"
#    namespace = "argocd"
#  }
#
#  spec {
#    project = "cilium"
#
#    source {
#      repo_url        = "https://helm.cilium.io"
#      chart           = "cilium"
#      target_revision = "1.18.2"
#
#      helm {
#        value_files = ["$values/cilium/values.yaml"]
#      }
#    }
#
#    source {
#      repo_url        = local.github_gitops_repo_url
#      target_revision = "HEAD"
#      ref             = "values"
#    }
#
#    destination {
#      server    = "https://kubernetes.default.svc"
#      namespace = "kube-system"
#    }
#
#    sync_policy {
#      automated {
#        prune       = true
#        self_heal   = true
#        allow_empty = false
#      }
#
#      retry {
#        limit = "5"
#        backoff {
#          duration     = "30s"
#          max_duration = "2m"
#          factor       = "2"
#        }
#      }
#    }
#  }
#
#  depends_on = [
#    helm_release.argocd,
#    kubernetes_manifest.cilium_ip,
#    kubernetes_manifest.cilium_l2
#  ]
#}

# DEPRECATED: Cilium Policies
#resource "argocd_application" "cilium_policies" {
#  metadata {
#    name      = "cilium-policies"
#    namespace = "argocd"
#  }
#
#  spec {
#    project = "cilium"
#
#    source {
#      repo_url        = local.github_gitops_repo_url
#      target_revision = "main"
#      path            = "network-policies"
#
#      directory {
#        recurse = true
#      }
#    }
#
#    destination {
#      server    = "https://kubernetes.default.svc"
#      namespace = "kube-system"
#    }
#
#    sync_policy {
#      automated {
#        prune       = true
#        self_heal   = true
#        allow_empty = false
#      }
#      retry {
#        limit = "5"
#        backoff {
#          duration     = "30s"
#          max_duration = "2m"
#          factor       = "2"
#        }
#      }
#    }
#  }
#
#  depends_on = [
#    argocd_application.cilium
#  ]
#}
