# Private VPC connection for database
resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.project_name}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.supabase_vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.supabase_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Random password for database
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Cloud SQL Instance (if selected)
resource "google_sql_database_instance" "postgres" {
  count = var.database_type == "cloudsql" ? 1 : 0

  name             = "${var.project_name}-db-${random_id.db_suffix.hex}"
  database_version = var.database_version
  region           = var.region

  settings {
    tier              = var.database_tier
    disk_size         = var.database_disk_size
    disk_autoresize   = true
    availability_type = var.database_availability_type

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "03:00"
      location                       = var.region

      backup_retention_settings {
        retained_backups = 30
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.supabase_vpc.id
      enable_private_path_for_google_cloud_services = true
    }

    database_flags {
      name  = "max_connections"
      value = "200"
    }

    database_flags {
      name  = "shared_buffers"
      value = "256000"
    }

    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }

    maintenance_window {
      day          = 7
      hour         = 4
      update_track = "stable"
    }
  }

  deletion_protection = true

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# AlloyDB Cluster (if selected)
resource "google_alloydb_cluster" "postgres" {
  count = var.database_type == "alloydb" ? 1 : 0

  cluster_id = "${var.project_name}-alloydb-${random_id.db_suffix.hex}"
  location   = var.region

  network_config {
    network = google_compute_network.supabase_vpc.id
  }

  initial_user {
    user     = "postgres"
    password = random_password.db_password.result
  }

  automated_backup_policy {
    enabled = true

    weekly_schedule {
      days_of_week = ["SUNDAY"]

      start_times {
        hours   = 3
        minutes = 0
      }
    }

    quantity_based_retention {
      count = 30
    }
  }

  continuous_backup_config {
    enabled              = true
    recovery_window_days = 14
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# AlloyDB Primary Instance
resource "google_alloydb_instance" "primary" {
  count = var.database_type == "alloydb" ? 1 : 0

  cluster       = google_alloydb_cluster.postgres[0].name
  instance_id   = "${var.project_name}-alloydb-primary"
  instance_type = "PRIMARY"

  machine_config {
    cpu_count = 4
  }

  database_flags = {
    "max_connections" = "200"
    "shared_buffers"  = "256000"
  }
}

# Random suffix for database instance names
resource "random_id" "db_suffix" {
  byte_length = 4
}

# Database user for Supabase
resource "google_sql_user" "supabase" {
  count = var.database_type == "cloudsql" ? 1 : 0

  name     = "supabase"
  instance = google_sql_database_instance.postgres[0].name
  password = random_password.db_password.result
}

# Databases
locals {
  databases = [
    "postgres",
    "supabase"
  ]
}

resource "google_sql_database" "databases" {
  for_each = var.database_type == "cloudsql" ? toset(local.databases) : []

  name     = each.value
  instance = google_sql_database_instance.postgres[0].name
}

# Database connection secret
resource "google_secret_manager_secret" "db_url" {
  secret_id = "${var.project_name}-db-url"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_url" {
  secret = google_secret_manager_secret.db_url.id

  secret_data = var.database_type == "cloudsql" ? "postgresql://supabase:${random_password.db_password.result}@${google_sql_database_instance.postgres[0].private_ip_address}:5432/supabase" : "postgresql://postgres:${random_password.db_password.result}@${google_alloydb_instance.primary[0].ip_address}:5432/supabase"
}

# Output database connection info
output "database_private_ip" {
  value     = var.database_type == "cloudsql" ? google_sql_database_instance.postgres[0].private_ip_address : google_alloydb_instance.primary[0].ip_address
  sensitive = true
}

output "database_connection_name" {
  value = var.database_type == "cloudsql" ? google_sql_database_instance.postgres[0].connection_name : "${google_alloydb_cluster.postgres[0].name}/instances/${google_alloydb_instance.primary[0].instance_id}"
}