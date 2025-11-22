# Vault Path
data "vault_generic_secret" "azure" {
  path = "${var.vault_name}/azure"
}

# Current Azure context
data "azurerm_client_config" "me" {}
data "azurerm_subscription" "current" {}

# Resource group for the Key Vault
resource "azurerm_resource_group" "rg" {
  name     = var.vault_hc_rg
  location = var.azure_location
}

# Main Key Vault instance for Vault auto-unseal
resource "azurerm_key_vault" "kv" {
  name                        = var.vault_hc_key_name
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  tenant_id                   = data.azurerm_client_config.me.tenant_id

  sku_name                   = "standard"
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  rbac_authorization_enabled = true
}

# RSA key used by Farm Vault for seal/unseal operations
resource "azurerm_key_vault_key" "hc_unseal" {
  name         = var.vault_hc_vault_key
  key_vault_id = azurerm_key_vault.kv.id
  key_type     = "RSA"
  key_size     = 3072
  key_opts     = ["wrapKey", "unwrapKey"]

  depends_on   = [
    azurerm_role_assignment.me_kv_admin
  ]
}

# Azure AD application and service principal used by Vault
resource "azuread_application_registration" "vault_hc" {
  display_name = var.azure_sp_vault_hc
}

resource "azuread_service_principal" "vault_hc_sp" {
  client_id = azuread_application_registration.vault_hc.client_id
}

# Client secret for the SP
resource "azuread_application_password" "vault_hc_sp_secret" {
  application_id = azuread_application_registration.vault_hc.id
  display_name   = "vault-unseal-sp-secret"
  end_date       = timeadd(timestamp(), "17520h") # ~2 years
}

# Grant the farmer) full Key Vault admin rights
resource "azurerm_role_assignment" "me_kv_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.me.object_id
}

# Custom role definition for the Vault service principal
# Grants only the data-plane permissions needed for auto-unseal
resource "azurerm_role_definition" "kv_sp_farm" {
  name        = "Key Vault SP farm"
  scope       = data.azurerm_subscription.current.id
  description = "Minimal role for Vault auto-unseal (wrap/unwrap/get key)."

  permissions {
    actions          = []
    not_actions      = []
    data_actions     = [
      "Microsoft.KeyVault/vaults/keys/read",
      "Microsoft.KeyVault/vaults/keys/wrap/action",
      "Microsoft.KeyVault/vaults/keys/unwrap/action"
    ]
    not_data_actions = []
  }

  assignable_scopes = [data.azurerm_subscription.current.id]
}

# Assign the custom role to the Vault service principal
resource "azurerm_role_assignment" "sp_kv_farm" {
  scope                = azurerm_key_vault.kv.id
  role_definition_id   = azurerm_role_definition.kv_sp_farm.role_definition_resource_id
  principal_id         = azuread_service_principal.vault_hc_sp.object_id
  principal_type       = "ServicePrincipal"

  depends_on = [
    azurerm_key_vault.kv,
    azurerm_role_definition.kv_sp_farm,
    azuread_service_principal.vault_hc_sp,
  ]
}

# Push the Azure credentials and Key Vault info to K3s as a secret
resource "kubernetes_secret" "auth_azure_kv" {
  metadata {
    name      = "auth-azure-kv"
    namespace = kubernetes_namespace.namespaces["infrastructure"].metadata[0].name
  }

  type = "Opaque"
  data = {
    AZURE_TENANT_ID      = data.azurerm_client_config.me.tenant_id
    AZURE_CLIENT_ID      = azuread_application_registration.vault_hc.client_id
    AZURE_CLIENT_SECRET  = azuread_application_password.vault_hc_sp_secret.value
    AZURE_KEY_VAULT_NAME = azurerm_key_vault.kv.name
    AZURE_KEY_NAME       = azurerm_key_vault_key.hc_unseal.name
  }

  depends_on = [
    azurerm_role_definition.kv_sp_farm,
    azurerm_role_assignment.sp_kv_farm
  ]
}
