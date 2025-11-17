# Namespace Outputs
output "argocd_namespace" {
  description = "Kubernetes namespace where ArgoCD is installed"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "app_namespace" {
  description = "Kubernetes namespace for application deployments"
  value       = kubernetes_namespace.helloworld.metadata[0].name
}

# ArgoCD Access Information
output "argocd_server_access" {
  description = "Instructions for accessing the ArgoCD server UI"
  value       = <<-EOT

    ArgoCD Server Access:
    =====================

    Option 1: LoadBalancer (Docker Desktop)
    ----------------------------------------
    If using service type 'LoadBalancer', ArgoCD will be available at:

      HTTP:  http://localhost:${var.argocd_server_http_port}
      HTTPS: https://localhost:${var.argocd_server_https_port}

    Wait for external IP to be assigned:
      kubectl get svc argocd-server -n ${kubernetes_namespace.argocd.metadata[0].name}

    Option 2: Port Forward (All Environments)
    ------------------------------------------
    Create a port forward to access ArgoCD UI:

      kubectl port-forward svc/argocd-server -n ${kubernetes_namespace.argocd.metadata[0].name} 8080:443

    Then access ArgoCD at:
      URL: https://localhost:8080

    (Accept the self-signed certificate warning)

  EOT
}

output "argocd_admin_username" {
  description = "ArgoCD admin username"
  value       = "admin"
}

output "argocd_initial_password" {
  description = "Commands to retrieve the auto-generated ArgoCD admin password"
  value       = <<-EOT

    Retrieve ArgoCD Initial Admin Password:
    ========================================

    ArgoCD auto-generates an initial admin password on first install.
    Use this password for initial login, then Ansible will set a new password.

      # Linux/macOS:
      kubectl -n ${kubernetes_namespace.argocd.metadata[0].name} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

      # Windows PowerShell:
      kubectl -n ${kubernetes_namespace.argocd.metadata[0].name} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object {[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_))}

    Note: This password will be changed by Ansible during configuration.
    See: docs/implementation-argocd-gitlab-app.md

  EOT
}

# Helpful Commands
output "useful_commands" {
  description = "Useful kubectl commands for managing the deployment"
  value       = <<-EOT

    Useful Commands:
    ================

    Check ArgoCD Installation:
    --------------------------
      kubectl get all -n ${kubernetes_namespace.argocd.metadata[0].name}
      kubectl get pods -n ${kubernetes_namespace.argocd.metadata[0].name}

    Check Application Namespace:
    -----------------------------
      kubectl get all -n ${kubernetes_namespace.helloworld.metadata[0].name}

    View ArgoCD Applications:
    -------------------------
      kubectl get applications -n ${kubernetes_namespace.argocd.metadata[0].name}

    Check ArgoCD Server Logs:
    -------------------------
      kubectl logs -n ${kubernetes_namespace.argocd.metadata[0].name} deployment/argocd-server -f

    ArgoCD CLI Login:
    -----------------
      # Via LoadBalancer HTTP:
      argocd login localhost:${var.argocd_server_http_port} --username admin --password <your-password> --insecure

      # Via Port Forward (run port-forward first):
      argocd login localhost:8080 --username admin --password <your-password> --insecure

    List ArgoCD Apps (CLI):
    -----------------------
      argocd app list
      argocd app get <app-name>
      argocd app sync <app-name>

  EOT
}

# Quick Start Guide
output "quick_start" {
  description = "Quick start guide for accessing ArgoCD after deployment"
  value       = <<-EOT

    ╔════════════════════════════════════════════════════════════════════╗
    ║                   ArgoCD Deployment Complete!                      ║
    ╚════════════════════════════════════════════════════════════════════╝

    📋 Next Steps:

    1. Access ArgoCD UI:
       ${var.argocd_service_type == "LoadBalancer" ? "   → HTTP:  http://localhost:${var.argocd_server_http_port}" : "   → Run: kubectl port-forward svc/argocd-server -n ${kubernetes_namespace.argocd.metadata[0].name} 8080:443"}
       ${var.argocd_service_type == "LoadBalancer" ? "   → HTTPS: https://localhost:${var.argocd_server_https_port}" : ""}

    2. Get Initial Admin Password:
       → terraform output argocd_initial_password
       → Username: admin
       → Password: (auto-generated, see command above)

    3. Verify Installation:
       → kubectl get pods -n ${kubernetes_namespace.argocd.metadata[0].name}
       → All pods should be in 'Running' state

    4. Configure ArgoCD with Ansible:
       → See: docs/implementation-argocd-gitlab-app.md
       → Ansible will set admin password and configure applications

    📚 For more commands, see: terraform output useful_commands

  EOT
}
