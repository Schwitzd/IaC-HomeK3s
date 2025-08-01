terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    argocd = {
      source = "argoproj-labs/argocd"
    }
#    garage2 = {
#      source = "ceski23/garage2"
#      version = "0.1.1"
#    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
  insecure    = true
}

provider "vault" {
  address          = var.vault_url
  token            = var.vault_token
  skip_child_token = true
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
    insecure    = true
  }
}

provider "argocd" {
  server_addr = "argocd.schwitzd.me:443"
  username    = data.vault_generic_secret.argocd.data["username"]
  password    = data.vault_generic_secret.argocd.data["password"]
}

#provider "garage2" {
#  host   = "${data.vault_generic_secret.redis.data.s3_endpoint}:3903"
#  scheme = "https"
#  token  = "bd6751b4108b4538b1f9f06253aae20b53d63657b22f5fd3e3816faa86e76fb6"
#}
