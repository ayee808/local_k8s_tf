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
  config_path    = "~/.kube/config"
  config_context = "docker-desktop"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "docker-desktop"
  }
}

# ArgoCD Namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# Helloworld Namespace
resource "kubernetes_namespace" "helloworld" {
  metadata {
    name = "helloworld"
  }
}

# ArgoCD Installation using Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  version    = "7.6.8"

  values = [
    file("${path.module}/argocd-values.yaml")
  ]
}

# ArgoCD Hellow World API
resource "kubernetes_manifest" "argocd_app_helloworld_api" {
  manifest = yamldecode(file("${path.module}/argocd-manifests/argocd-app-helloworld-api.yaml"))
}

# ArgoCD Hellow World UI
resource "kubernetes_manifest" "argocd_app_helloworld_ui" {
  manifest = yamldecode(file("${path.module}/argocd-manifests/argocd-app-helloworld-ui.yaml"))
}