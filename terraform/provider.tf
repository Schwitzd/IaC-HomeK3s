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
  config_context = "homefarm"
  insecure       = true
}

provider "vault" {
  address          = var.vault_url
  token            = var.vault_token
  skip_child_token = true
}

provider "vault" {
  alias            = "farm"
  address          = data.vault_generic_secret.vault_farm.data["address"]
  token            = data.vault_generic_secret.vault_farm.data["token"]
  skip_child_token = true
}

provider "helm" {
  kubernetes = {
    config_path    = "~/.kube/config"
    config_context = "homefarm"
    insecure       = true
  }
}

provider "argocd" {
  server_addr = data.vault_generic_secret.argocd_admin.data["hostname"]
  username    = data.vault_generic_secret.argocd_admin.data["username"]
  password    = data.vault_generic_secret.argocd_admin.data["password"]
}

provider "garage" {
  host   = data.vault_generic_secret.garage.data["admin_endpoint"]
  scheme = "https"
  token  = data.vault_generic_secret.garage.data["admin_token"]
}
