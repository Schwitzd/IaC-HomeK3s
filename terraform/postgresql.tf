# Vault paths
data "vault_generic_secret" "postgresql" {
  path = "${var.vault_name}/postgresql"
}

data "vault_generic_secret" "postgresql_roles" {
  path = "${var.vault_name}/postgresql-roles"
}

# S3 Backup Bucket
resource "garage_key" "pg_backup" {
  name = "pg-backup-key"
}

resource "garage_bucket" "pg_backup" {
  global_alias = "pg-backup"
}

resource "garage_bucket_key" "pg_backup" {
  bucket_id     = garage_bucket.pg_backup.id
  access_key_id = garage_key.pg_backup.access_key_id

  read  = true
  write = true

  depends_on = [
    garage_bucket.pg_backup,
    garage_key.pg_backup
  ]
}
