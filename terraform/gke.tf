# GKE Cluster for Kong API Gateway and Realtime service
resource "google_container_cluster" "supabase_gke" {
  name     = "${var.project_name}-gke"
  location = var.zone
  
  # Basic cluster configuration
  initial_node_count = 1
  
  # Network configuration
  network    = google_compute_network.supabase_vpc.name
  subnetwork = google_compute_subnetwork.supabase_subnet.name
  
  # IP allocation policy for VPC-native cluster
  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }
  
  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  
  # Security configurations
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
  
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All networks"
    }
  }
  
  # Cluster features
  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    
    http_load_balancing {
      disabled = false
    }
    
    network_policy_config {
      disabled = false
    }
    
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }
  
  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "04:00"
    }
  }
  
  # Release channel
  release_channel {
    channel = "REGULAR"
  }
  
  # Logging and monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }
  
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    
    managed_prometheus {
      enabled = true
    }
  }
  
  # Default node pool will be removed
  remove_default_node_pool = true
  
  depends_on = [
    google_project_service.apis,
    google_compute_network.supabase_vpc
  ]
}

# Node pool for general workloads
resource "google_container_node_pool" "supabase_nodes" {
  name       = "${var.project_name}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.supabase_gke.name
  node_count = var.gke_node_count
  
  # Autoscaling configuration
  autoscaling {
    min_node_count  = 2
    max_node_count  = 10
    location_policy = "BALANCED"
  }
  
  # Node configuration
  node_config {
    preemptible  = false
    machine_type = var.gke_node_machine_type
    disk_size_gb = var.gke_node_disk_size
    disk_type    = "pd-ssd"
    
    # Service account
    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    
    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
    
    # Node labels
    labels = {
      environment = var.environment
      purpose     = "supabase"
    }
    
    # Node taints
    taint {
      key    = "supabase"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
    
    # Shielded instance config
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
    
    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
  
  # Management configuration
  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Service account for GKE nodes
resource "google_service_account" "gke_nodes" {
  account_id   = "${var.project_name}-gke-nodes"
  display_name = "GKE Nodes Service Account"
}

# IAM roles for GKE nodes
resource "google_project_iam_member" "gke_node_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
    "roles/storage.objectViewer"
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Workload Identity binding for services
resource "google_service_account" "workload_identity" {
  account_id   = "${var.project_name}-wi"
  display_name = "Workload Identity Service Account"
}

resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.workload_identity.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[supabase/supabase-services]"
}

# Output cluster info
output "gke_cluster_name" {
  value = google_container_cluster.supabase_gke.name
}

output "gke_cluster_endpoint" {
  value     = google_container_cluster.supabase_gke.endpoint
  sensitive = true
}