# Kubernetes Configuration
variable "kubeconfig_path" {
  description = "Path to the kubeconfig file for Kubernetes cluster access"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kubernetes context to use from kubeconfig (e.g., docker-desktop, minikube)"
  type        = string
  default     = "docker-desktop"
}

# Namespace Configuration
variable "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD installation"
  type        = string
  default     = "argocd"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.argocd_namespace))
    error_message = "Namespace must be a valid Kubernetes namespace name (lowercase alphanumeric and hyphens only)."
  }
}

variable "app_namespace" {
  description = "Kubernetes namespace for application deployments"
  type        = string
  default     = "helloworld"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.app_namespace))
    error_message = "Namespace must be a valid Kubernetes namespace name (lowercase alphanumeric and hyphens only)."
  }
}

# ArgoCD Configuration
variable "argocd_chart_version" {
  description = "Version of the ArgoCD Helm chart to install"
  type        = string
  default     = "7.9.1"  # ArgoCD v2.14.11 (matches CLI v2.14.8)
}

variable "argocd_service_type" {
  description = "Kubernetes service type for ArgoCD server (LoadBalancer, NodePort, or ClusterIP)"
  type        = string
  default     = "LoadBalancer"

  validation {
    condition     = contains(["LoadBalancer", "NodePort", "ClusterIP"], var.argocd_service_type)
    error_message = "Service type must be one of: LoadBalancer, NodePort, or ClusterIP."
  }
}

variable "argocd_server_http_port" {
  description = "HTTP port for ArgoCD server LoadBalancer service"
  type        = number
  default     = 80

  validation {
    condition     = var.argocd_server_http_port > 0 && var.argocd_server_http_port < 65536
    error_message = "Port must be between 1 and 65535."
  }
}

variable "argocd_server_https_port" {
  description = "HTTPS port for ArgoCD server LoadBalancer service"
  type        = number
  default     = 443

  validation {
    condition     = var.argocd_server_https_port > 0 && var.argocd_server_https_port < 65536
    error_message = "Port must be between 1 and 65535."
  }
}

# Note: ArgoCD admin password and application repository URLs are managed by Ansible
# See: docs/implementation-argocd-gitlab-app.md for Ansible configuration
