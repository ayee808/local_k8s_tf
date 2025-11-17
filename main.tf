terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
  }
}

# ArgoCD Namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
  }
}

# Helloworld Namespace
resource "kubernetes_namespace" "helloworld" {
  metadata {
    name = var.app_namespace
  }
}

# ArgoCD Installation using Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  version    = var.argocd_chart_version

  values = [
    templatefile("${path.module}/argocd-values.yaml.tpl", {
      service_type = var.argocd_service_type
      http_port    = var.argocd_server_http_port
      https_port   = var.argocd_server_https_port
    })
  ]
}

# ArgoCD Applications - Commented out for initial deployment
# These will be replaced with GitLab app configuration
# Note: ArgoCD CRDs must be installed before these can be applied

# # ArgoCD Hellow World API
# resource "kubernetes_manifest" "argocd_app_helloworld_api" {
#   manifest = yamldecode(file("${path.module}/argocd-manifests/argocd-app-helloworld-api.yaml"))
# }

# # ArgoCD Hellow World UI
# resource "kubernetes_manifest" "argocd_app_helloworld_ui" {
#   manifest = yamldecode(file("${path.module}/argocd-manifests/argocd-app-helloworld-ui.yaml"))
# }