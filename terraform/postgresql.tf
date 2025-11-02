# Vault path
data "vault_generic_secret" "postgresql" {
  path = "${var.vault_name}/postgresql"
}

data "vault_generic_secret" "postgresql_roles" {
  path = "${var.vault_name}/postgresql-roles"
}

data "vault_generic_secret" "postgresql_backup" {
  path = "${var.vault_name}/postgresql-backup"
}

# PostgreSQL secret
resource "kubernetes_secret" "postgresql_superuser" {
  metadata {
    name      = "auth-db-postgresql-superuser"
    namespace = kubernetes_namespace.namespaces["database"].metadata[0].name
  }

  data = {
    username = data.vault_generic_secret.postgresql.data["superuser"]
    password = data.vault_generic_secret.postgresql.data["superuser_password"]
  }

  type = "Opaque"
}

# PostgreSQL roles
resource "kubernetes_secret" "postgresql_roles" {
  for_each = nonsensitive(data.vault_generic_secret.postgresql_roles.data)

  metadata {
    name      = "auth-db-${each.key}-role"
    namespace = kubernetes_namespace.namespaces["database"].metadata[0].name
    labels = {
      "cnpg.io/reload" = "true"
    }
  }

  data = {
    username = each.key
    password = each.value
  }

  type = "kubernetes.io/basic-auth"
}

# CloudNativePG pperator deployment
resource "argocd_application" "cnpg_operator" {
  metadata {
    name      = "cnpg-operator"
    namespace = "argocd"
  }

  spec {
    project = "database"

    source {
      repo_url        = "https://cloudnative-pg.github.io/charts"
      chart           = "cloudnative-pg"
      target_revision = "0.26.0"

      helm {
        value_files = ["$values/cnpg-operator/values.yaml"]
      }
    }

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      ref             = "values"
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "database"
    }

    sync_policy {
      automated {
        prune       = true
        self_heal   = true
        allow_empty = false
      }

      sync_options = [
        "ServerSideApply=true"
      ]

      retry {
        limit = 5
        backoff {
          duration     = "30s"
          max_duration = "2m"
          factor       = 2
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.namespaces["database"],
    helm_release.argocd,
    argocd_project.projects["database"]
  ]
}

# CloudNativePG cluster deployment
resource "argocd_application" "cnpg_cluster" {
  metadata {
    name      = "cnpg-cluster"
    namespace = "argocd"
  }

  spec {
    project = "database"

    source {
      repo_url        = "https://cloudnative-pg.github.io/charts"
      chart           = "cluster"
      target_revision = "0.3.1"

      helm {
        value_files = ["$values/cnpg-cluster/values.yaml"]
      }
    }

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      ref             = "values"
      path            = "cnpg-cluster"

      directory {
        recurse = true
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "database"
    }

    sync_policy {
      automated {
        prune       = true
        self_heal   = true
        allow_empty = false
      }

      sync_options = [
        "ServerSideApply=true"
      ]

      retry {
        limit = 5
        backoff {
          duration     = "30s"
          max_duration = "2m"
          factor       = 2
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.namespaces["database"],
    helm_release.argocd,
    argocd_project.projects["database"],
    argocd_application.cnpg_operator,
    kubernetes_secret.postgresql_superuser,
    kubernetes_secret.postgresql_roles
  ]
}

resource "argocd_application" "cnpg_barman_cloud" {
  metadata {
    name      = "cnpg-barman-cloud"
    namespace = "argocd"
  }
  spec {
    project = "database"

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      path            = "cnpg-barman-cloud"

      directory {
        recurse = true
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "database"
    }

    sync_policy {
      automated {
        prune       = true
        self_heal   = true
        allow_empty = false
      }

      sync_options = [
        "ServerSideApply=true"
      ]

      retry {
        limit = 5
        backoff {
          duration     = "30s"
          max_duration = "2m"
          factor       = 2
        }
      }
    }
  }
}

# S3 Backup Bucket
resource "garage_key" "pg_backup" {
  name       = "pg-backup-key"
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
