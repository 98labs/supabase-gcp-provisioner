# Google API Gateway Configuration

# Enable required APIs for API Gateway
resource "google_project_service" "api_gateway_apis" {
  for_each = toset([
    "apigateway.googleapis.com",
    "servicemanagement.googleapis.com",
    "servicecontrol.googleapis.com"
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# Process the OpenAPI spec with actual service URLs
locals {
  api_spec_template = file("${path.module}/../api-gateway/supabase-api-spec.yaml")

  api_spec = replace(
    replace(
      replace(
        replace(
          replace(
            replace(
              replace(
                replace(
                  local.api_spec_template,
                  "$${API_GATEWAY_HOST}",
                  var.domain
                ),
                "$${AUTH_SERVICE_URL}",
                google_cloud_run_v2_service.services["auth"].uri
              ),
              "$${REST_SERVICE_URL}",
              google_cloud_run_v2_service.services["rest"].uri
            ),
            "$${STORAGE_SERVICE_URL}",
            google_cloud_run_v2_service.services["storage"].uri
          ),
          "$${META_SERVICE_URL}",
          google_cloud_run_v2_service.services["meta"].uri
        ),
        "$${STUDIO_SERVICE_URL}",
        google_cloud_run_v2_service.services["studio"].uri
      ),
      "$${REALTIME_SERVICE_URL}",
      google_cloud_run_v2_service.realtime.uri
    ),
    "$${GRAPHQL_SERVICE_URL}",
    "https://${var.domain}/graphql/v1" # This will be handled by PostgREST
  )
}

# Create the API config
resource "google_api_gateway_api_config" "supabase_api_config" {
  provider      = google-beta
  api           = google_api_gateway_api.supabase_api.api_id
  api_config_id = "${var.project_name}-config-${substr(md5(local.api_spec), 0, 8)}"

  openapi_documents {
    document {
      path     = "spec.yaml"
      contents = base64encode(local.api_spec)
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    google_project_service.api_gateway_apis,
    google_cloud_run_v2_service.services
  ]
}

# Create the API
resource "google_api_gateway_api" "supabase_api" {
  provider = google-beta
  api_id   = "${var.project_name}-api"

  depends_on = [google_project_service.api_gateway_apis]
}

# Create the Gateway
resource "google_api_gateway_gateway" "supabase_gateway" {
  provider   = google-beta
  api_config = google_api_gateway_api_config.supabase_api_config.id
  gateway_id = "${var.project_name}-gateway"
  region     = var.region

  depends_on = [google_api_gateway_api_config.supabase_api_config]
}

# Create a Cloud Run service for Realtime (since it needs WebSocket support)
resource "google_cloud_run_v2_service" "realtime" {
  name     = "${var.project_name}-realtime"
  location = var.region

  template {
    service_account = google_service_account.cloud_run_services.email

    containers {
      image = "supabase/realtime:latest"

      ports {
        container_port = 4000
      }

      env {
        name  = "PORT"
        value = "4000"
      }

      env {
        name  = "DB_HOST"
        value = var.database_type == "cloudsql" ? google_sql_database_instance.postgres[0].private_ip_address : google_alloydb_instance.primary[0].ip_address
      }

      env {
        name  = "DB_PORT"
        value = "5432"
      }

      env {
        name  = "DB_NAME"
        value = "supabase"
      }

      env {
        name  = "DB_USER"
        value = "supabase"
      }

      env {
        name  = "DB_SSL"
        value = "false"
      }

      env {
        name  = "REPLICATION_MODE"
        value = "RLS"
      }

      env {
        name  = "REPLICATION_POLL_INTERVAL"
        value = "100"
      }

      env {
        name  = "SECURE_CHANNELS"
        value = "true"
      }

      env {
        name  = "SLOT_NAME"
        value = "supabase_realtime_rls"
      }

      env {
        name  = "REGION"
        value = var.region
      }

      # Secrets
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret_version.db_password.name
            version = "latest"
          }
        }
      }

      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret_version.jwt_secret.name
            version = "latest"
          }
        }
      }

      resources {
        limits = {
          cpu    = "2"
          memory = "2Gi"
        }
      }

      startup_probe {
        http_get {
          path = "/health"
          port = 4000
        }
        initial_delay_seconds = 10
        timeout_seconds       = 3
        period_seconds        = 5
        failure_threshold     = 10
      }

      liveness_probe {
        http_get {
          path = "/health"
          port = 4000
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

# Grant Cloud Run invoker permissions to API Gateway service account
resource "google_cloud_run_service_iam_member" "api_gateway_invoker" {
  for_each = merge(
    local.cloud_run_services,
    { realtime = {} }
  )

  service  = "${var.project_name}-${each.key}"
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"

  depends_on = [
    google_cloud_run_v2_service.services,
    google_cloud_run_v2_service.realtime
  ]
}

# Output the Gateway URL
output "api_gateway_url" {
  value       = "https://${google_api_gateway_gateway.supabase_gateway.default_hostname}"
  description = "The URL of the API Gateway"
}

output "api_gateway_managed_service" {
  value       = google_api_gateway_api_config.supabase_api_config.id
  description = "The managed service name for the API Gateway"
}