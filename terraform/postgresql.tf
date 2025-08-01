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

resource "kubernetes_secret" "postgresql_backup" {
  metadata {
    name      = "postgresql-backup"
    namespace = kubernetes_namespace.namespaces["database"].metadata[0].name
  }

  data = {
    POSTGRES_HOST        = data.vault_generic_secret.postgresql.data["hostname"]
    POSTGRES_USER        = data.vault_generic_secret.postgresql_backup.data["backup_user"]
    POSTGRES_PASSWORD    = data.vault_generic_secret.postgresql_backup.data["backup_password"]
    S3_ENDPOINT          = data.vault_generic_secret.garage.data["s3_endpoint"]
    S3_REGION            = data.vault_generic_secret.garage.data["s3_region"]
    S3_ACCESS_KEY_ID     = data.vault_generic_secret.postgresql_backup.data["s3_access_key"]
    S3_SECRET_ACCESS_KEY = data.vault_generic_secret.postgresql_backup.data["s3_access_key"]
    S3_BUCKET            = data.vault_generic_secret.postgresql_backup.data["s3_bucket"]
  }

  type = "Opaque"
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
      target_revision = "0.25.0"

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


# PostgreSQL Backup job
resource "argocd_application" "postgresql_backup" {
  metadata {
    name      = "postgresql-backup"
    namespace = "argocd"
  }

  spec {
    project = "database"

    source {
      repo_url        = argocd_repository.repos["github_gitops"].repo
      target_revision = "HEAD"
      path            = "postgresql-backup"

      helm {
        value_files = ["values.yaml"]
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

      retry {
        limit = 3
        backoff {
          duration     = "30s"
          max_duration = "2m"
          factor       = 2
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    argocd_project.projects["database"],
    kubernetes_secret.postgresql_backup,
    argocd_application.cnpg_cluster
  ]
}
