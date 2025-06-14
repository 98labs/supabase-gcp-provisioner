output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

output "load_balancer_ip_address" {
  value       = google_compute_global_address.lb_ip.address
  description = "The IP address of the load balancer. Point your domain's A record to this IP."
}

output "supabase_url" {
  value = var.enable_custom_domain ? "https://${var.domain}" : "http://${google_compute_global_address.lb_ip.address}"
}

output "supabase_anon_key" {
  value     = var.anon_key
  sensitive = true
}

output "supabase_service_role_key" {
  value     = var.service_role_key
  sensitive = true
}

output "database_host" {
  value     = var.database_type == "cloudsql" ? google_sql_database_instance.postgres[0].private_ip_address : google_alloydb_instance.primary[0].ip_address
  sensitive = true
}

output "database_password" {
  value     = random_password.db_password.result
  sensitive = true
}

output "api_gateway_endpoint" {
  value       = "https://${google_api_gateway_gateway.supabase_gateway.default_hostname}"
  description = "The endpoint URL for the API Gateway"
}

output "cloud_run_service_urls" {
  value = merge(
    { for k, v in google_cloud_run_v2_service.services : k => v.uri },
    { realtime = google_cloud_run_v2_service.realtime.uri }
  )
  description = "Internal URLs for Cloud Run services (not directly accessible)"
}

output "storage_bucket" {
  value = google_storage_bucket.storage.name
}

output "artifact_registry" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.supabase_docker.repository_id}"
}

output "dashboard_url" {
  value = var.enable_monitoring ? "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.supabase[0].id}?project=${var.project_id}" : "Monitoring disabled"
}

output "next_steps" {
  value = <<-EOT
    
    ========================================
    Supabase deployment completed!
    ========================================
    
    1. Access your Supabase instance:
       ${var.enable_custom_domain ? "Custom Domain URL: https://${var.domain}" : "API Gateway URL: https://${google_api_gateway_gateway.supabase_gateway.default_hostname}"}
       ${var.enable_custom_domain ? "Point your domain (${var.domain}) to: ${google_compute_global_address.lb_ip.address}" : ""}
    
    2. Authentication Keys:
       Anon Key: <sensitive - use 'terraform output -raw supabase_anon_key'>
       Service Role Key: <sensitive - use 'terraform output -raw supabase_service_role_key'>
    
    3. Database connection:
       Host: <sensitive - use 'terraform output -raw database_host'>
       Port: 5432
       Database: supabase
       User: supabase
       Password: <sensitive - use 'terraform output -raw database_password'>
    
    4. Studio Dashboard:
       ${var.enable_custom_domain ? "https://${var.domain}/console" : "https://${google_api_gateway_gateway.supabase_gateway.default_hostname}/console"}
    
    5. API Endpoints:
       - Auth: /auth/v1/
       - REST: /rest/v1/
       - Storage: /storage/v1/
       - Realtime: /realtime/v1/
       - GraphQL: /graphql/v1
       - Functions: /functions/v1/
    
    6. Monitoring dashboard:
       ${var.enable_monitoring ? "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.supabase[0].id}?project=${var.project_id}" : "Monitoring disabled"}
    
    ========================================
  EOT
}