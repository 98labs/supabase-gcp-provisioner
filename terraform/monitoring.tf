# Monitoring and Alerting Configuration

# Notification channel for alerts
resource "google_monitoring_notification_channel" "email" {
  count = var.enable_monitoring ? 1 : 0
  
  display_name = "${var.project_name} Email Alerts"
  type         = "email"
  
  labels = {
    email_address = var.smtp_from_email
  }
}

# Uptime checks
resource "google_monitoring_uptime_check_config" "services" {
  for_each = var.enable_monitoring ? {
    auth    = "/auth/health"
    rest    = "/rest/"
    storage = "/storage/v1/version"
  } : {}
  
  display_name = "${var.project_name}-${each.key}-uptime"
  timeout      = "10s"
  period       = "60s"
  
  http_check {
    path         = each.value
    port         = "443"
    use_ssl      = true
    validate_ssl = true
  }
  
  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.domain
    }
  }
}

# Alert policies
resource "google_monitoring_alert_policy" "high_cpu" {
  count = var.enable_monitoring ? 1 : 0
  
  display_name = "${var.project_name} High CPU Usage"
  combiner     = "OR"
  
  conditions {
    display_name = "High CPU usage"
    
    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND metric.type = \"run.googleapis.com/container/cpu/utilizations\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.email[0].id]
  
  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_alert_policy" "database_connections" {
  count = var.enable_monitoring ? 1 : 0
  
  display_name = "${var.project_name} High Database Connections"
  combiner     = "OR"
  
  conditions {
    display_name = "High connection count"
    
    condition_threshold {
      filter = var.database_type == "cloudsql" ? 
        "resource.type = \"cloudsql_database\" AND metric.type = \"cloudsql.googleapis.com/database/postgresql/num_backends\"" :
        "resource.type = \"alloydb_cluster\" AND metric.type = \"alloydb.googleapis.com/database/postgresql/num_backends\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 150
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.email[0].id]
  
  alert_strategy {
    auto_close = "1800s"
  }
}

# Dashboard
resource "google_monitoring_dashboard" "supabase" {
  count = var.enable_monitoring ? 1 : 0
  
  dashboard_json = jsonencode({
    displayName = "${var.project_name} Dashboard"
    gridLayout = {
      widgets = [
        {
          title = "Cloud Run CPU Utilization"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/container/cpu/utilizations\""
                }
              }
            }]
          }
        },
        {
          title = "Cloud Run Request Count"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\""
                }
              }
            }]
          }
        },
        {
          title = "Database Connections"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = var.database_type == "cloudsql" ?
                    "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/postgresql/num_backends\"" :
                    "resource.type=\"alloydb_cluster\" AND metric.type=\"alloydb.googleapis.com/database/postgresql/num_backends\""
                }
              }
            }]
          }
        },
        {
          title = "Load Balancer Request Count"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"https_lb_rule\" AND metric.type=\"loadbalancing.googleapis.com/https/request_count\""
                }
              }
            }]
          }
        }
      ]
    }
  })
}

# Log sinks for centralized logging
resource "google_logging_project_sink" "supabase_logs" {
  count = var.enable_logging ? 1 : 0
  
  name        = "${var.project_name}-logs-sink"
  destination = "storage.googleapis.com/${google_storage_bucket.logs.name}"
  
  filter = "resource.type=\"cloud_run_revision\" OR resource.type=\"k8s_container\" OR resource.type=\"cloudsql_database\" OR resource.type=\"alloydb_cluster\""
  
  unique_writer_identity = true
}

# Grant the logging service account access to the bucket
resource "google_storage_bucket_iam_member" "logging_sink_member" {
  count = var.enable_logging ? 1 : 0
  
  bucket = google_storage_bucket.logs.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.supabase_logs[0].writer_identity
}