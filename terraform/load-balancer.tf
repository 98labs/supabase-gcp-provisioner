# Simplified Load Balancer Configuration for API Gateway

# Static IP address
resource "google_compute_global_address" "lb_ip" {
  name = "${var.project_name}-lb-ip"
}

# SSL Certificate (if custom domain enabled)
resource "google_compute_managed_ssl_certificate" "lb_cert" {
  count = var.enable_custom_domain ? 1 : 0
  
  name = "${var.project_name}-ssl-cert"
  
  managed {
    domains = [var.domain]
  }
}

# Cloud Armor Security Policy
resource "google_compute_security_policy" "cloud_armor" {
  count = var.enable_cloud_armor ? 1 : 0
  
  name = "${var.project_name}-cloud-armor"
  
  # Default rule
  rule {
    action   = "allow"
    priority = "2147483647"
    
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    
    description = "Default rule"
  }
  
  # Rate limiting rule
  rule {
    action   = "throttle"
    priority = "1000"
    
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    
    rate_limit_options {
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      
      conform_action = "allow"
      exceed_action  = "deny(429)"
      
      enforce_on_key = "IP"
    }
    
    description = "Rate limiting rule"
  }
  
  # SQL injection protection
  rule {
    action   = "deny(403)"
    priority = "1001"
    
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-stable')"
      }
    }
    
    description = "SQL injection protection"
  }
  
  # XSS protection
  rule {
    action   = "deny(403)"
    priority = "1002"
    
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-stable')"
      }
    }
    
    description = "XSS protection"
  }
}

# NEG for API Gateway
resource "google_compute_region_network_endpoint_group" "api_gateway_neg" {
  name                  = "${var.project_name}-api-gateway-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  
  serverless_deployment {
    platform = "apigateway.googleapis.com"
    resource = google_api_gateway_gateway.supabase_gateway.gateway_id
  }
}

# Backend service for API Gateway
resource "google_compute_backend_service" "api_gateway" {
  name        = "${var.project_name}-api-gateway-backend"
  protocol    = "HTTPS"
  timeout_sec = 30
  
  backend {
    group = google_compute_region_network_endpoint_group.api_gateway_neg.id
  }
  
  security_policy = var.enable_cloud_armor ? google_compute_security_policy.cloud_armor[0].id : null
  
  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# URL map for routing
resource "google_compute_url_map" "lb" {
  name            = "${var.project_name}-url-map"
  default_service = google_compute_backend_service.api_gateway.id
}

# HTTPS proxy
resource "google_compute_target_https_proxy" "lb" {
  count            = var.enable_custom_domain ? 1 : 0
  name             = "${var.project_name}-https-proxy"
  url_map          = google_compute_url_map.lb.id
  ssl_certificates = [google_compute_managed_ssl_certificate.lb_cert[0].id]
}

# HTTP proxy (for redirect)
resource "google_compute_target_http_proxy" "lb" {
  count   = 1
  name    = "${var.project_name}-http-proxy"
  url_map = var.enable_custom_domain ? google_compute_url_map.http_redirect[0].id : google_compute_url_map.lb.id
}

# Global forwarding rule for HTTPS
resource "google_compute_global_forwarding_rule" "https" {
  count                 = var.enable_custom_domain ? 1 : 0
  name                  = "${var.project_name}-https-forwarding"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  target                = google_compute_target_https_proxy.lb[0].id
  ip_address            = google_compute_global_address.lb_ip.id
}

# Global forwarding rule for HTTP
resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.project_name}-http-forwarding"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_http_proxy.lb[0].id
  ip_address            = google_compute_global_address.lb_ip.id
}

# HTTP to HTTPS redirect
resource "google_compute_url_map" "http_redirect" {
  count = var.enable_custom_domain ? 1 : 0
  name  = "${var.project_name}-http-redirect"
  
  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

# Output load balancer IP
output "load_balancer_ip" {
  value = google_compute_global_address.lb_ip.address
}

# Note: For a simpler setup, you can also directly use the API Gateway URL
# without a custom domain and load balancer
output "direct_api_gateway_url" {
  value = "https://${google_api_gateway_gateway.supabase_gateway.default_hostname}"
  description = "Direct API Gateway URL (use this if not using custom domain)"
}