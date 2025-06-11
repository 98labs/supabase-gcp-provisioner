variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "supabase"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# Network Configuration
variable "subnet_cidr" {
  description = "CIDR range for main subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "gke_pods_cidr" {
  description = "CIDR range for GKE pods"
  type        = string
  default     = "10.0.16.0/20"
}

variable "gke_services_cidr" {
  description = "CIDR range for GKE services"
  type        = string
  default     = "10.0.32.0/20"
}

# Database Configuration
variable "database_type" {
  description = "Database type: cloudsql or alloydb"
  type        = string
  default     = "cloudsql"
  
  validation {
    condition     = contains(["cloudsql", "alloydb"], var.database_type)
    error_message = "Database type must be either 'cloudsql' or 'alloydb'"
  }
}

variable "database_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "POSTGRES_15"
}

variable "database_tier" {
  description = "Database instance tier"
  type        = string
  default     = "db-custom-4-16384"
}

variable "database_disk_size" {
  description = "Database disk size in GB"
  type        = number
  default     = 100
}

variable "database_availability_type" {
  description = "Database availability type"
  type        = string
  default     = "REGIONAL"
}

# GKE Configuration
variable "gke_node_count" {
  description = "Number of nodes in GKE cluster"
  type        = number
  default     = 3
}

variable "gke_node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "n2-standard-4"
}

variable "gke_node_disk_size" {
  description = "Disk size for GKE nodes in GB"
  type        = number
  default     = 100
}

# Supabase Configuration
variable "jwt_secret" {
  description = "JWT secret for authentication (32+ characters)"
  type        = string
  sensitive   = true
}

variable "anon_key" {
  description = "Supabase anon key"
  type        = string
  sensitive   = true
}

variable "service_role_key" {
  description = "Supabase service role key"
  type        = string
  sensitive   = true
}

variable "dashboard_username" {
  description = "Dashboard username"
  type        = string
  default     = "admin"
}

variable "dashboard_password" {
  description = "Dashboard password"
  type        = string
  sensitive   = true
}

variable "smtp_host" {
  description = "SMTP host for email"
  type        = string
  default     = ""
}

variable "smtp_port" {
  description = "SMTP port"
  type        = number
  default     = 587
}

variable "smtp_user" {
  description = "SMTP username"
  type        = string
  default     = ""
}

variable "smtp_password" {
  description = "SMTP password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "smtp_from_email" {
  description = "From email address"
  type        = string
  default     = "noreply@example.com"
}

# Domain Configuration
variable "domain" {
  description = "Domain for Supabase (e.g., api.example.com)"
  type        = string
}

variable "enable_custom_domain" {
  description = "Enable custom domain with SSL"
  type        = bool
  default     = true
}

# Feature Flags
variable "enable_monitoring" {
  description = "Enable Cloud Monitoring"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Enable Cloud Logging"
  type        = bool
  default     = true
}

variable "enable_cloud_armor" {
  description = "Enable Cloud Armor for DDoS protection"
  type        = bool
  default     = true
}