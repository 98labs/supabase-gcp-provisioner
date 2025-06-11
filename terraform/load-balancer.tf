# Global External Application Load Balancer

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

# Health check for Kong
resource "google_compute_health_check" "kong" {
  name = "${var.project_name}-kong-health"
  
  http_health_check {
    port         = 8001
    request_path = "/status"
  }
  
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

# Backend service for Kong (GKE)
resource "google_compute_backend_service" "kong" {
  name                  = "${var.project_name}-kong-backend"
  protocol              = "HTTP"
  port_name             = "kong-proxy"
  timeout_sec           = 30
  enable_cdn            = false
  
  health_checks = [google_compute_health_check.kong.id]
  
  security_policy = var.enable_cloud_armor ? google_compute_security_policy.cloud_armor[0].id : null
  
  backend {
    group = google_container_cluster.supabase_gke.instance_group_urls[0]
  }
  
  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# NEG (Network Endpoint Group) for Cloud Run services
resource "google_compute_region_network_endpoint_group" "cloud_run_neg" {
  for_each = local.cloud_run_services
  
  name                  = "${var.project_name}-${each.key}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  
  cloud_run {
    service = google_cloud_run_v2_service.services[each.key].name
  }
}

# Backend services for Cloud Run
resource "google_compute_backend_service" "cloud_run" {
  for_each = local.cloud_run_services
  
  name        = "${var.project_name}-${each.key}-backend"
  protocol    = "HTTP"
  timeout_sec = 30
  
  backend {
    group = google_compute_region_network_endpoint_group.cloud_run_neg[each.key].id
  }
  
  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# URL map for routing
resource "google_compute_url_map" "lb" {
  name            = "${var.project_name}-url-map"
  default_service = google_compute_backend_service.kong.id
  
  host_rule {
    hosts        = [var.domain]
    path_matcher = "api-routes"
  }
  
  path_matcher {
    name            = "api-routes"
    default_service = google_compute_backend_service.kong.id
    
    # Auth service
    path_rule {
      paths   = ["/auth/*"]
      service = google_compute_backend_service.cloud_run["auth"].id
    }
    
    # REST service
    path_rule {
      paths   = ["/rest/*"]
      service = google_compute_backend_service.cloud_run["rest"].id
    }
    
    # Storage service
    path_rule {
      paths   = ["/storage/*"]
      service = google_compute_backend_service.cloud_run["storage"].id
    }
    
    # Postgres Meta service
    path_rule {
      paths   = ["/pg/*"]
      service = google_compute_backend_service.cloud_run["meta"].id
    }
    
    # Studio console
    path_rule {
      paths   = ["/console", "/console/*"]
      service = google_compute_backend_service.cloud_run["studio"].id
    }
    
    # Other services handled by Kong
    path_rule {
      paths   = ["/realtime/*", "/graphql/*", "/functions/*"]
      service = google_compute_backend_service.kong.id
    }
  }
}

# HTTP proxy
resource "google_compute_target_http_proxy" "lb" {
  count   = var.enable_custom_domain ? 0 : 1
  name    = "${var.project_name}-http-proxy"
  url_map = google_compute_url_map.lb.id
}

# HTTPS proxy
resource "google_compute_target_https_proxy" "lb" {
  count            = var.enable_custom_domain ? 1 : 0
  name             = "${var.project_name}-https-proxy"
  url_map          = google_compute_url_map.lb.id
  ssl_certificates = [google_compute_managed_ssl_certificate.lb_cert[0].id]
}

# Global forwarding rule for HTTP
resource "google_compute_global_forwarding_rule" "http" {
  count                 = var.enable_custom_domain ? 0 : 1
  name                  = "${var.project_name}-http-forwarding"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_http_proxy.lb[0].id
  ip_address            = google_compute_global_address.lb_ip.id
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

# HTTP to HTTPS redirect
resource "google_compute_url_map" "http_redirect" {
  count = var.enable_custom_domain ? 1 : 0
  name  = "${var.project_name}-http-redirect"
  
  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

resource "google_compute_target_http_proxy" "http_redirect" {
  count   = var.enable_custom_domain ? 1 : 0
  name    = "${var.project_name}-http-redirect-proxy"
  url_map = google_compute_url_map.http_redirect[0].id
}

resource "google_compute_global_forwarding_rule" "http_redirect" {
  count                 = var.enable_custom_domain ? 1 : 0
  name                  = "${var.project_name}-http-redirect-forwarding"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_http_proxy.http_redirect[0].id
  ip_address            = google_compute_global_address.lb_ip.id
}

# Output load balancer IP
output "load_balancer_ip" {
  value = google_compute_global_address.lb_ip.address
}