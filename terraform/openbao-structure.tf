# Vault path
data "vault_generic_secret" "vault_farm" {
  path = "${var.vault_name}/vault-farm"
}

# Vault Engines (KV)
resource "vault_mount" "namespaces" {
  provider = vault.farm

  for_each = toset(local.namespaces)

  path        = "farm/${each.value}"
  type        = "kv-v2"
  description = "Kubernetes secrets for project ${each.value}"
}

# Vault Policies
resource "vault_policy" "farm_rw" {
  provider = vault.farm

  for_each = toset(local.namespaces)

  name = "farm-${each.value}-rw"
  policy = <<-EOT
    # Full RW for secrets in project ${each.value}
    path "farm/${each.value}/data/*" {
      capabilities = ["create", "update", "read", "delete", "list"]
    }

    # Metadata (list, check versions, etc.)
    path "farm/${each.value}/metadata/*" {
      capabilities = ["read", "list", "delete"]
    }
  EOT

  depends_on = [
    vault_mount.namespaces
   ]
}

resource "vault_policy" "farm_ro" {
  provider = vault.farm

  for_each = toset(local.namespaces)

  name = "farm-${each.value}-ro"
  policy = <<-EOT
    # Read-only on secret values
    path "farm/${each.value}/data/*" {
      capabilities = ["read", "list"]
    }

    # Read/list metadata
    path "farm/${each.value}/metadata/*" {
      capabilities = ["read", "list"]
    }
  EOT

  depends_on = [
    vault_mount.namespaces
   ]
}

# Vault Authentication backend
resource "vault_auth_backend" "kubernetes" {
  provider = vault.farm

  type = "kubernetes"
  path = "kubernetes"
}

# Vault Authentication backend - Vault Secrets Operator
resource "vault_kubernetes_auth_backend_role" "eso" {
  provider = vault.farm

  backend   = vault_auth_backend.kubernetes.path
  role_name = "farm-eso"

  bound_service_account_names      = ["sa-external-secrets"]
  bound_service_account_namespaces = ["infrastructure"]

  # Reuse your read-only policies per namespace
  token_policies = [
    for ns in local.namespaces : "farm-${ns}-ro"
  ]

  token_ttl     = 3600
  token_max_ttl = 7200
}
