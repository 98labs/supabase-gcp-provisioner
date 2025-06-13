# Cloud Run services for Supabase components

locals {
  cloud_run_services = {
    auth = {
      image = "supabase/gotrue:latest"
      port  = 9999
      env = {
        GOTRUE_API_HOST                     = "0.0.0.0"
        GOTRUE_API_PORT                     = "9999"
        GOTRUE_DB_DRIVER                    = "postgres"
        GOTRUE_SITE_URL                     = "https://${var.domain}"
        GOTRUE_URI_ALLOW_LIST               = "*"
        GOTRUE_DISABLE_SIGNUP               = "false"
        GOTRUE_JWT_ADMIN_ROLES              = "service_role"
        GOTRUE_JWT_AUD                      = "authenticated"
        GOTRUE_JWT_DEFAULT_GROUP_NAME       = "authenticated"
        GOTRUE_JWT_EXP                      = "3600"
        GOTRUE_EXTERNAL_EMAIL_ENABLED       = "true"
        GOTRUE_MAILER_AUTOCONFIRM           = "false"
        GOTRUE_SMTP_ADMIN_EMAIL             = var.smtp_from_email
        GOTRUE_SMTP_HOST                    = var.smtp_host
        GOTRUE_SMTP_PORT                    = tostring(var.smtp_port)
        GOTRUE_SMTP_USER                    = var.smtp_user
        GOTRUE_MAILER_URLPATHS_INVITE       = "/auth/v1/verify"
        GOTRUE_MAILER_URLPATHS_CONFIRMATION = "/auth/v1/verify"
        GOTRUE_MAILER_URLPATHS_RECOVERY     = "/auth/v1/verify"
        GOTRUE_MAILER_URLPATHS_EMAIL_CHANGE = "/auth/v1/verify"
        GOTRUE_EXTERNAL_PHONE_ENABLED       = "true"
        GOTRUE_SMS_AUTOCONFIRM              = "true"
      }
      secrets = {
        GOTRUE_DB_DATABASE_URL = google_secret_manager_secret_version.db_url.name
        GOTRUE_JWT_SECRET      = google_secret_manager_secret_version.jwt_secret.name
        GOTRUE_SMTP_PASS       = google_secret_manager_secret_version.smtp_password.name
      }
    }

    rest = {
      image = "postgrest/postgrest:latest"
      port  = 3000
      env = {
        PGRST_DB_SCHEMA                       = "public,storage,graphql_public"
        PGRST_DB_ANON_ROLE                    = "anon"
        PGRST_DB_USE_LEGACY_GUCS              = "false"
        PGRST_APP_SETTINGS_JWT_AUD            = "authenticated"
        PGRST_APP_SETTINGS_JWT_ROLE_CLAIM_KEY = ".role"
        PGRST_APP_SETTINGS_JWT_EXP            = "3600"
      }
      secrets = {
        PGRST_DB_URI     = google_secret_manager_secret_version.db_url.name
        PGRST_JWT_SECRET = google_secret_manager_secret_version.jwt_secret.name
      }
    }

    storage = {
      image = "supabase/storage-api:latest"
      port  = 5000
      env = {
        POSTGREST_URL               = "http://rest:3000"
        ANON_KEY                    = var.anon_key
        SERVICE_KEY                 = var.service_role_key
        TENANT_ID                   = "stub"
        REGION                      = var.region
        STORAGE_BACKEND             = "gcs"
        GCS_BUCKET                  = google_storage_bucket.storage.name
        FILE_SIZE_LIMIT             = "52428800"
        STORAGE_FILE_PATH           = "/var/lib/storage"
        GLOBAL_S3_PROTOCOL          = "https"
        ENABLE_IMAGE_TRANSFORMATION = "true"
        IMGPROXY_URL                = "http://imgproxy:5001"
      }
      secrets = {
        DATABASE_URL = google_secret_manager_secret_version.db_url.name
        JWT_SECRET   = google_secret_manager_secret_version.jwt_secret.name
      }
    }

    meta = {
      image = "supabase/postgres-meta:latest"
      port  = 8080
      env = {
        PG_META_PORT        = "8080"
        PG_META_DB_HOST     = var.database_type == "cloudsql" ? google_sql_database_instance.postgres[0].private_ip_address : google_alloydb_instance.primary[0].ip_address
        PG_META_DB_PORT     = "5432"
        PG_META_DB_NAME     = "postgres"
        PG_META_DB_USER     = "supabase"
        PG_META_DB_SSL_MODE = "disable"
      }
      secrets = {
        PG_META_DB_PASSWORD = google_secret_manager_secret_version.db_password.name
      }
    }

    studio = {
      image = "${google_artifact_registry_repository.supabase_docker.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.supabase_docker.repository_id}/studio:latest"
      port  = 3000
      env = {
        STUDIO_DEFAULT_ORGANIZATION   = "Default"
        STUDIO_DEFAULT_PROJECT        = "Default"
        STUDIO_PORT                   = "3000"
        SUPABASE_PUBLIC_URL           = "https://${var.domain}"
        SUPABASE_URL                  = "https://${var.domain}"
        SUPABASE_REST_URL             = "https://${var.domain}/rest/v1/"
        STUDIO_PG_META_URL            = "http://${var.project_name}-meta:8080"
        DEFAULT_ORGANIZATION_NAME     = "Default"
        DEFAULT_PROJECT_NAME          = "Default"
        NEXT_PUBLIC_SUPABASE_URL      = "https://${var.domain}"
        NEXT_PUBLIC_SUPABASE_ANON_KEY = var.anon_key
        NEXT_TELEMETRY_DISABLED       = "1"
      }
      secrets = {
        POSTGRES_PASSWORD         = google_secret_manager_secret_version.db_password.name
        DATABASE_URL              = google_secret_manager_secret_version.db_url.name
        SUPABASE_SERVICE_ROLE_KEY = google_secret_manager_secret_version.service_role_key.name
      }
      health_check_path = "/api/health"
      cpu_limit         = "4"
      memory_limit      = "4Gi"
    }
  }
}

# Create secrets
resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "${var.project_name}-jwt-secret"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "jwt_secret" {
  secret      = google_secret_manager_secret.jwt_secret.id
  secret_data = var.jwt_secret
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.project_name}-db-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

resource "google_secret_manager_secret" "smtp_password" {
  secret_id = "${var.project_name}-smtp-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "smtp_password" {
  secret      = google_secret_manager_secret.smtp_password.id
  secret_data = var.smtp_password
}

resource "google_secret_manager_secret" "service_role_key" {
  secret_id = "${var.project_name}-service-role-key"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "service_role_key" {
  secret      = google_secret_manager_secret.service_role_key.id
  secret_data = var.service_role_key
}

# Cloud Run services
resource "google_cloud_run_v2_service" "services" {
  for_each = local.cloud_run_services

  name     = "${var.project_name}-${each.key}"
  location = var.region

  template {
    service_account = google_service_account.cloud_run_services.email

    containers {
      image = each.value.image

      ports {
        container_port = each.value.port
      }

      # Environment variables
      dynamic "env" {
        for_each = each.value.env
        content {
          name  = env.key
          value = env.value
        }
      }

      # Secrets
      dynamic "env" {
        for_each = each.value.secrets
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }

      resources {
        limits = {
          cpu    = lookup(each.value, "cpu_limit", "2")
          memory = lookup(each.value, "memory_limit", "2Gi")
        }
      }

      startup_probe {
        http_get {
          path = lookup(each.value, "health_check_path", "/health")
          port = each.value.port
        }
        initial_delay_seconds = 10
        timeout_seconds       = 3
        period_seconds        = 5
        failure_threshold     = 10
      }

      liveness_probe {
        http_get {
          path = lookup(each.value, "health_check_path", "/health")
          port = each.value.port
        }
        initial_delay_seconds = 30
        timeout_seconds       = 3
        period_seconds        = 10
        failure_threshold     = 3
      }
    }

    scaling {
      min_instance_count = 1
      max_instance_count = 100
    }

    vpc_access {
      connector = google_vpc_access_connector.connector.id
      egress    = "PRIVATE_RANGES_ONLY"
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [
    google_project_service.apis,
    google_secret_manager_secret_iam_member.secret_access
  ]
}

# Service account for Cloud Run services
resource "google_service_account" "cloud_run_services" {
  account_id   = "${var.project_name}-cloud-run"
  display_name = "Cloud Run Services"
}

# IAM roles for Cloud Run service account
resource "google_project_iam_member" "cloud_run_roles" {
  for_each = toset([
    "roles/cloudsql.client",
    "roles/secretmanager.secretAccessor",
    "roles/storage.admin",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_run_services.email}"
}

# Grant access to secrets
resource "google_secret_manager_secret_iam_member" "secret_access" {
  for_each = {
    jwt_secret       = google_secret_manager_secret.jwt_secret.id
    db_url          = google_secret_manager_secret.db_url.id
    db_password     = google_secret_manager_secret.db_password.id
    smtp_password   = google_secret_manager_secret.smtp_password.id
    service_role_key = google_secret_manager_secret.service_role_key.id
  }

  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_services.email}"
}

# VPC Connector for Cloud Run
resource "google_vpc_access_connector" "connector" {
  name          = "${var.project_name}-connector"
  region        = var.region
  network       = google_compute_network.supabase_vpc.name
  ip_cidr_range = "10.1.0.0/28"

  min_instances = 2
  max_instances = 10

  depends_on = [google_project_service.apis]
}

# Cloud Run service URLs
output "cloud_run_urls" {
  value = {
    for k, v in google_cloud_run_v2_service.services : k => v.uri
  }
}