# Namespace for the application
resource "kubernetes_namespace" "app" {
  metadata {
    name = "${var.app_name}-ns"
    labels = {
      managed = "terraform"
    }
  }

  depends_on = [module.aks]
}

# ConfigMap for application configuration
resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "${var.app_name}-config"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    "app-name"    = var.app_name
    "environment" = var.environment
    "log-level"   = "info"
  }

  depends_on = [kubernetes_namespace.app]
}

# Deployment for Node.js Hello World App
resource "kubernetes_deployment" "nodejs" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = var.app_name
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = var.app_name
      }
    }

    template {
      metadata {
        labels = {
          app = var.app_name
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "3000"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        container {
          image = "${module.aks.acr_login_server}/${var.app_name}:latest"
          name  = var.app_name

          port {
            name           = "http"
            container_port = 3000
            protocol       = "TCP"
          }

          env {
            name  = "NODE_ENV"
            value = var.environment
          }

          env {
            name  = "APP_NAME"
            value = var.app_name
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          liveness_probe {
            http_get {
              path   = "/"
              port   = 3000
              scheme = "HTTP"
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path   = "/"
              port   = 3000
              scheme = "HTTP"
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = false
            run_as_non_root            = false
          }
        }

        security_context {
          fs_group = 1000
        }

        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app"
                    operator = "In"
                    values   = [var.app_name]
                  }
                }
                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        image_pull_secrets {
          name = kubernetes_secret.acr.metadata[0].name
        }
      }
    }
  }

  depends_on = [module.aks, kubernetes_namespace.app]
}

# Secret for ACR authentication
resource "kubernetes_secret" "acr" {
  metadata {
    name      = "acr-secret"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  type = "kubernetes.io/dockercfg"

  data = {
    ".dockercfg" = base64encode(jsonencode({
      "${module.aks.acr_login_server}" = {
        "auth"  = base64encode("${var.acr_username}:${var.acr_password}")
        "email" = "devops@bankx.com"
      }
    }))
  }

  depends_on = [kubernetes_namespace.app]
}

# Horizontal Pod Autoscaler
resource "kubernetes_horizontal_pod_autoscaler_v2" "nodejs" {
  metadata {
    name      = "${var.app_name}-hpa"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.nodejs.metadata[0].name
    }

    min_replicas = 2
    max_replicas = 10

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }

    behavior {
      scale_down {
        stabilization_window_seconds = 300
        policy {
          type           = "Percent"
          value          = 50
          period_seconds = 60
        }
      }
      scale_up {
        stabilization_window_seconds = 60
        policy {
          type           = "Percent"
          value          = 100
          period_seconds = 60
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.nodejs]
}

# Service for the deployment
resource "kubernetes_service" "nodejs_app" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = var.app_name
    }
  }

  spec {
    selector = {
      app = var.app_name
    }

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 3000
      name        = "http"
    }

    type = "ClusterIP"

    session_affinity = "None"
  }

  depends_on = [kubernetes_deployment.nodejs]
}

# NetworkPolicy for the application
resource "kubernetes_network_policy" "app" {
  metadata {
    name      = "${var.app_name}-netpolicy"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = var.app_name
      }
    }

    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace.app.metadata[0].name
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = "3000"
      }
    }

    egress {
      to {
        namespace_selector {}
      }
      ports {
        protocol = "TCP"
        port     = "53"
      }
      ports {
        protocol = "UDP"
        port     = "53"
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace.app.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.app]
}
