# Google Cloud Storage bucket for Supabase Storage
resource "google_storage_bucket" "storage" {
  name          = "${var.project_id}-${var.project_name}-storage"
  location      = var.region
  storage_class = "STANDARD"

  # Enable versioning for data protection
  versioning {
    enabled = true
  }

  # Lifecycle rules
  lifecycle_rule {
    condition {
      age                = 30
      num_newer_versions = 3
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  # CORS configuration for browser uploads
  cors {
    origin          = ["*"]
    method          = ["GET", "POST", "PUT", "DELETE", "HEAD"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  # Uniform bucket-level access
  uniform_bucket_level_access = true

  # Encryption
  encryption {
    default_kms_key_name = google_kms_crypto_key.storage_key.id
  }

  # Logging
  logging {
    log_bucket = google_storage_bucket.logs.name
  }

  # Labels
  labels = {
    environment = var.environment
    purpose     = "supabase-storage"
  }
}

# Logging bucket
resource "google_storage_bucket" "logs" {
  name          = "${var.project_id}-${var.project_name}-logs"
  location      = var.region
  storage_class = "NEARLINE"

  # Lifecycle rule to delete old logs
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  # Uniform bucket-level access
  uniform_bucket_level_access = true
}

# KMS key ring
resource "google_kms_key_ring" "supabase" {
  name     = "${var.project_name}-keyring"
  location = var.region
}

# KMS crypto key for storage encryption
resource "google_kms_crypto_key" "storage_key" {
  name     = "${var.project_name}-storage-key"
  key_ring = google_kms_key_ring.supabase.id

  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = true
  }
}

# Grant Cloud Run service account access to storage bucket
resource "google_storage_bucket_iam_member" "storage_admin" {
  bucket = google_storage_bucket.storage.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.cloud_run_services.email}"
}

# Grant Cloud Run service account access to KMS key
resource "google_kms_crypto_key_iam_member" "storage_key_user" {
  crypto_key_id = google_kms_crypto_key.storage_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.cloud_run_services.email}"
}

# Output storage bucket name
output "storage_bucket_name" {
  value = google_storage_bucket.storage.name
}