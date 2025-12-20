terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }

    azurerm = {
      source = "hashicorp/azurerm"
    }
  
    azuread = {
      source = "hashicorp/azuread"
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

provider "vault" {
  alias            = "farm"
  address          = data.vault_generic_secret.vault_farm.data["address"]
  token            = data.vault_generic_secret.vault_farm.data["token"]
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
  server_addr = data.vault_generic_secret.argocd.data["hostname"]
  username    = data.vault_generic_secret.argocd.data["username"]
  password    = data.vault_generic_secret.argocd.data["password"]
}

provider "garage" {
  host   = data.vault_generic_secret.garage.data["admin_endpoint"]
  scheme = "https"
  token  = data.vault_generic_secret.garage.data["admin_token"]
}

provider "azurerm" { 
  features {
    key_vault {
      purge_soft_deleted_keys_on_destroy = true
      recover_soft_deleted_keys          = true
    }
  }

  tenant_id       = data.vault_generic_secret.azure.data["tenant_id"]
  subscription_id = data.vault_generic_secret.azure.data["subscription_id"]
}

provider "azuread" {
tenant_id = data.vault_generic_secret.azure.data["tenant_id"]
}