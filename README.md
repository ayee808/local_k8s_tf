# local_k8s_tf

Local Kubernetes Terraform Configuration for ArgoCD Deployment

## Overview

This Terraform configuration deploys ArgoCD to a local Kubernetes cluster (Docker Desktop). It follows a clean separation of concerns:

- **Terraform**: Manages infrastructure (namespaces, ArgoCD installation via Helm)
- **Ansible**: Manages configuration (admin password, applications, repositories)

This approach ensures passwords are never stored in Terraform state and provides flexibility to update ArgoCD configuration without re-applying infrastructure.

## Prerequisites

### Required Software

1. **Docker Desktop** with Kubernetes enabled
   - [Download Docker Desktop](https://www.docker.com/products/docker-desktop)
   - Enable Kubernetes: Settings → Kubernetes → Enable Kubernetes

2. **kubectl** - Kubernetes command-line tool
   ```bash
   # Verify installation
   kubectl version --client
   ```

3. **Terraform** (v1.0+)
   ```bash
   # Verify installation
   terraform version
   ```

4. **Helm** (v3.0+)
   ```bash
   # Verify installation
   helm version
   ```

### Verify Prerequisites

```bash
# 1. Check Kubernetes cluster is running
kubectl cluster-info

# 2. Check current context is docker-desktop
kubectl config current-context
# Expected: docker-desktop

# 3. Check nodes are ready
kubectl get nodes
# Expected: docker-desktop   Ready   control-plane

# 4. Add ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

## Quick Start

### 1. Configure Variables

```bash
# Copy the example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit if you need to customize (all variables have defaults)
# Example: Change application namespace
nano terraform.tfvars
```

**Available Variables:**
- `kubeconfig_path` - Path to kubeconfig (default: `~/.kube/config`)
- `kube_context` - Kubernetes context (default: `docker-desktop`)
- `argocd_namespace` - ArgoCD namespace (default: `argocd`)
- `app_namespace` - Application namespace (default: `helloworld`)
- `argocd_chart_version` - Helm chart version (default: `7.6.8`)
- `argocd_service_type` - Service type (default: `LoadBalancer`)

**Note**: ArgoCD admin password and applications are managed by Ansible (see below).

### 2. Deploy ArgoCD

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy ArgoCD
terraform apply
```

### 3. Access ArgoCD

After deployment completes:

```bash
# Get the auto-generated admin password
terraform output argocd_initial_password

# Access ArgoCD UI
# Option 1: Via LoadBalancer
open http://localhost

# Option 2: Via Port Forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
open https://localhost:8080
```

**Login Credentials:**
- Username: `admin`
- Password: (from `terraform output argocd_initial_password`)

### 4. Verify Installation

```bash
# Check all pods are running
kubectl get pods -n argocd

# Check LoadBalancer service
kubectl get svc -n argocd argocd-server

# View all outputs
terraform output
```

## Configuration with Ansible

After Terraform deploys the infrastructure, use Ansible to configure ArgoCD:

1. **Set Admin Password**: Ansible will change the auto-generated password to a secure one
2. **Configure Applications**: Deploy applications to ArgoCD (e.g., GitLab app)
3. **Setup Repositories**: Configure Git repository access

**See**: `docs/implementation-argocd-gitlab-app.md` for Ansible configuration instructions.

## Deployed Resources

This Terraform configuration creates:

### Namespaces
- `argocd` - ArgoCD installation namespace
- `belay-example-app` (or custom via `app_namespace`) - Application deployment namespace

### Helm Releases
- `argocd` - ArgoCD v7.6.8 (customizable)
  - Application Controller
  - API Server
  - Repository Server
  - Dex (SSO)
  - Redis
  - Notifications Controller
  - ApplicationSet Controller

### Services
- `argocd-server` - LoadBalancer service for ArgoCD UI (http://localhost)

## Useful Commands

```bash
# Check ArgoCD installation
kubectl get all -n argocd
kubectl get pods -n argocd

# Check application namespace
kubectl get all -n belay-example-app

# View ArgoCD applications
kubectl get applications -n argocd

# Check ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server -f

# Get all Terraform outputs
terraform output

# Get specific output
terraform output argocd_initial_password
terraform output quick_start
terraform output useful_commands
```

## ArgoCD CLI Usage

```bash
# Install ArgoCD CLI (macOS)
brew install argocd

# Login via LoadBalancer
argocd login localhost --username admin --password <password> --insecure

# Login via Port Forward (if using port-forward)
argocd login localhost:8080 --username admin --password <password> --insecure

# List applications
argocd app list

# Get app details
argocd app get <app-name>

# Sync an application
argocd app sync <app-name>
```

## Troubleshooting

### Cluster Not Running

**Issue**: `The connection to the server 127.0.0.1:6443 was refused`

**Solution**:
1. Open Docker Desktop
2. Go to Settings → Kubernetes
3. Enable "Enable Kubernetes"
4. Wait for Kubernetes to start (green indicator)

### Helm Repository Error

**Issue**: `no cached repo found`

**Solution**:
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

### Pods Not Starting

**Issue**: ArgoCD pods stuck in `Pending` or `CrashLoopBackOff`

**Solution**:
```bash
# Check pod events
kubectl describe pod <pod-name> -n argocd

# Check pod logs
kubectl logs <pod-name> -n argocd

# Common issues:
# - Insufficient resources (allocate more to Docker Desktop)
# - Image pull errors (check internet connection)
```

### LoadBalancer Stuck on Pending

**Issue**: `EXTERNAL-IP` shows `<pending>` instead of `localhost`

**Solution**:
- LoadBalancer only works with Docker Desktop Kubernetes
- Verify you're using `docker-desktop` context: `kubectl config current-context`
- Restart Docker Desktop if needed
- Use port-forward as alternative: `kubectl port-forward svc/argocd-server -n argocd 8080:443`

### Cannot Access ArgoCD UI

**Issue**: Browser cannot connect to ArgoCD

**Solution**:
```bash
# Check service is running
kubectl get svc -n argocd argocd-server

# Check pods are running
kubectl get pods -n argocd

# Try port-forward method
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at https://localhost:8080
# Accept self-signed certificate warning
```

## Cleanup

To remove all resources:

```bash
# Destroy all Terraform-managed resources
terraform destroy

# Verify namespaces are deleted
kubectl get namespaces | grep -E "argocd|belay-example-app"

# If namespaces stuck in Terminating state
kubectl delete namespace argocd --force --grace-period=0
kubectl delete namespace belay-example-app --force --grace-period=0
```

**Note**: This will remove ArgoCD and all deployed applications.

## Project Structure

```
local_k8s_tf/
├── main.tf                          # Main Terraform configuration
├── variables.tf                     # Variable definitions
├── outputs.tf                       # Output definitions
├── terraform.tfvars.example         # Example variable values
├── terraform.tfvars                 # Your variable values (gitignored)
├── argocd-values.yaml              # ArgoCD Helm chart values
├── .gitignore                       # Git ignore rules
├── README.md                        # This file
├── docs/
│   ├── implementation-terraform-refactor.md        # Implementation plan
│   ├── implementation-argocd-gitlab-app.md         # Ansible configuration plan
│   └── ARCHITECTURE-TERRAFORM-ANSIBLE-SPLIT.md    # Architecture decision record
└── argocd-manifests/               # ArgoCD application manifests (deprecated - use Ansible)
```

## Architecture Decisions

This project implements a **Terraform/Ansible split architecture**:

- **Infrastructure Layer (Terraform)**:
  - Kubernetes namespaces
  - ArgoCD Helm chart installation
  - LoadBalancer/Service configuration
  - No password management (ArgoCD auto-generates)

- **Configuration Layer (Ansible)**:
  - Admin password management (encrypted with ansible-vault)
  - ArgoCD application definitions
  - Git repository configuration
  - Sync policies and settings

**Benefits**:
- Passwords never stored in Terraform state
- Infrastructure and configuration independently managed
- Easier to update applications without touching infrastructure
- Better security with ansible-vault encryption

See `docs/ARCHITECTURE-TERRAFORM-ANSIBLE-SPLIT.md` for detailed rationale.

## Security Notes

- ✅ No passwords stored in Terraform files or state
- ✅ ArgoCD auto-generates initial password on first install
- ✅ `terraform.tfvars` is gitignored (never commit)
- ✅ Initial password visible via `terraform output` (for Ansible retrieval)
- ⚠️  Change auto-generated password via Ansible after deployment
- ⚠️  LoadBalancer uses self-signed certificates (acceptable for local dev)

## Contributing

When making changes:
1. Follow the implementation plans in `docs/`
2. Update relevant documentation
3. Test changes with `terraform plan` before `apply`
4. Keep Terraform focused on infrastructure only
5. Use Ansible for all configuration management

## License

See LICENSE file in repository root.

## Support

For issues or questions:
- Check `docs/implementation-terraform-refactor.md` for implementation details
- Review troubleshooting section above
- Check ArgoCD documentation: https://argo-cd.readthedocs.io/

---

**Last Updated**: 2025-11-16
**Terraform Version**: 1.11.2
**ArgoCD Version**: 7.6.8
**Kubernetes**: Docker Desktop v1.34.1
