terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }

    argocd = {
      source = "argoproj-labs/argocd"
    }

    garage = {
      source = "schwitzd/garage"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "default"
  insecure       = true
}

provider "vault" {
  address          = var.vault_url
  token            = var.vault_token
  skip_child_token = true
}

provider "helm" {
  kubernetes = {
    config_path    = "~/.kube/config"
    config_context = "default"
    insecure       = true
  }
}

provider "argocd" {
  server_addr = "argocd.schwitzd.me:443"
  username    = data.vault_generic_secret.argocd.data["username"]
  password    = data.vault_generic_secret.argocd.data["password"]
}

provider "garage" {
  host   = data.vault_generic_secret.garage.data["admin_endpoint"]
  scheme = "https"
  token  = data.vault_generic_secret.garage.data["admin_token"]
}