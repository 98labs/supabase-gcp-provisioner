terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "containerregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "apigateway.googleapis.com",
    "servicemanagement.googleapis.com",
    "servicecontrol.googleapis.com",
    "storage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudarmor.googleapis.com",
    "alloydb.googleapis.com",
    "artifactregistry.googleapis.com"
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# VPC Network
resource "google_compute_network" "supabase_vpc" {
  name                    = "${var.project_name}-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.apis]
}

# Subnets
resource "google_compute_subnetwork" "supabase_subnet" {
  name          = "${var.project_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.supabase_vpc.id

  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = var.gke_pods_cidr
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = var.gke_services_cidr
  }
}

# Cloud Router for NAT
resource "google_compute_router" "supabase_router" {
  name    = "${var.project_name}-router"
  region  = var.region
  network = google_compute_network.supabase_vpc.id
}

# Cloud NAT
resource "google_compute_router_nat" "supabase_nat" {
  name                               = "${var.project_name}-nat"
  router                             = google_compute_router.supabase_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Service Account for services
resource "google_service_account" "supabase_services" {
  account_id   = "${var.project_name}-services"
  display_name = "Supabase Services"
  description  = "Service account for Supabase services"
}

# Artifact Registry for Docker images
resource "google_artifact_registry_repository" "supabase_docker" {
  location      = var.region
  repository_id = "${var.project_name}-docker"
  description   = "Docker repository for Supabase images"
  format        = "DOCKER"

  depends_on = [google_project_service.apis]
}