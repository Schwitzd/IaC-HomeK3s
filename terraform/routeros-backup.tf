data "vault_generic_secret" "routeros_backup" {
  path = "${var.vault_name}/routeros-backup"
}

resource "kubernetes_manifest" "routeros_backup_cronjob" {
  manifest = yamldecode(templatefile("${path.module}/routeros-backup-cronjob.yaml", {
    namespace = kubernetes_namespace.namespaces["infrastructure"].metadata[0].name
    image     = "harbor.schwitzd.me/library/routeros-backup:1.4.1"
  }))

  depends_on = [
    kubernetes_secret.routeros_backup_secret,
    kubernetes_secret.routeros_backup_ssh_key
  ]
}


resource "kubernetes_secret" "routeros_backup_secret" {
  metadata {
    name      = "routeros-backup-secret"
    namespace = kubernetes_namespace.namespaces["infrastructure"].metadata[0].name
  }

  data = {
    ROUTER_HOST       = data.vault_generic_secret.routeros_backup.data["router_hostname"]
    ROUTER_USER       = data.vault_generic_secret.routeros_backup.data["router_user"]
    SSH_KEY_PATH      = "/secrets/routeros-backup_ed25519"
    BACKUPNAME_PREFIX = "routeros"
    BACKUP_PASSWORD   = data.vault_generic_secret.routeros_backup.data["backup_password"]
    S3_ENDPOINT       = data.vault_generic_secret.minio.data["s3_endpoint"]
    S3_ACCESS_KEY     = data.vault_generic_secret.routeros_backup.data["s3_access_key"]
    S3_SECRET_KEY     = data.vault_generic_secret.routeros_backup.data["s3_secret_key"]
    S3_BUCKET         = "mikrotik"
    S3_PREFIX         = "backups/"
    BACKUP_DEST_TYPE  = "s3"
    RETENTION_POINTS  = "5"
  }

  type = "Opaque"
}

resource "kubernetes_secret" "routeros_backup_ssh_key" {
  metadata {
    name      = "routeros-backup-ssh-key"
    namespace = kubernetes_namespace.namespaces["infrastructure"].metadata[0].name
  }

  data = {
    routeros-backup_ed25519 = data.vault_generic_secret.routeros_backup.data["backup_sshkey"]
  }

  type = "Opaque"
}
