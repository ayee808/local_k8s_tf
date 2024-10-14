terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "docker-desktop"
}

# ArgoCD Installation
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "kubernetes_manifest" "argocd_install" {
  manifest = yamldecode(file("${path.module}/argocd-install.yaml"))

  depends_on = [kubernetes_namespace.argocd]
}

resource "kubernetes_service" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/component" = "server"
      "app.kubernetes.io/name"      = "argocd-server"
      "app.kubernetes.io/part-of"   = "argocd"
    }
  }

  spec {
    port {
      name        = "http"
      port        = 80
      target_port = 8080
    }
    port {
      name        = "https"
      port        = 443
      target_port = 8080
    }
    selector = {
      "app.kubernetes.io/name" = "argocd-server"
    }
    type = "LoadBalancer"
  }

  depends_on = [kubernetes_manifest.argocd_install]
}

# Hello World K8s API Deployment
resource "kubernetes_deployment" "api" {
  metadata {
    name = "hello-world-k8s-api"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "hello-world-k8s-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "hello-world-k8s-api"
        }
      }

      spec {
        container {
          image = "ayee808/hello-world-k8s-api:latest"
          name  = "hello-world-k8s-api"

          port {
            container_port = 8000
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "api" {
  metadata {
    name = "hello-world-k8s-api-service"
  }

  spec {
    selector = {
      app = kubernetes_deployment.api.spec[0].template[0].metadata[0].labels.app
    }

    port {
      port        = 8000
      target_port = 8000
    }

    type = "ClusterIP"
  }
}

# Hello World K8s UI Deployment
resource "kubernetes_deployment" "ui" {
  metadata {
    name = "hello-world-k8s-ui"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "hello-world-k8s-ui"
      }
    }

    template {
      metadata {
        labels = {
          app = "hello-world-k8s-ui"
        }
      }

      spec {
        container {
          image = "ayee808/hello-world-k8s-ui:latest"
          name  = "hello-world-k8s-ui"

          port {
            container_port = 80
          }

          env {
            name  = "REACT_APP_API_URL"
            value = "http://hello-world-k8s-api-service:8000"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "ui" {
  metadata {
    name = "hello-world-k8s-ui-service"
  }

  spec {
    selector = {
      app = kubernetes_deployment.ui.spec[0].template[0].metadata[0].labels.app
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}
