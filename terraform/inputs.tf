variable "vault_url" {
  description = "The Vault address"
  type        = string
}

variable "vault_token" {
  description = "The Vault API token"
  type        = string
  sensitive   = true
}

variable "vault_name" {
  description = "The Vault name"
  type        = string
  sensitive   = true
}

variable "azure_location" {
  description = "Azure region where the Key Vault and resources will be deployed"
  type        = string
}

variable "azure_sp_vault_hc" {
  description = "Display name for the Azure AD Service Principal used by Vault for auto-unseal"
  type        = string
}

variable "vault_hc_rg" {
  description = "Azure Resource Group name for the Vault auto-unseal setup"
  type        = string
}

variable "vault_hc_key_name" {
  description = "Azure Key Vault name for the Vault auto-unseal setup"
  type        = string
}

variable "vault_hc_vault_key" {
  description = "Name of the RSA key inside Azure Key Vault used by Vault for auto-unseal"
  type        = string
}
