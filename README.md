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

### Prerequisites

1. **Ansible** (v2.10+)
   ```bash
   # Verify installation
   ansible --version
   ```

2. **Python Dependencies**
   ```bash
   # Install kubernetes Python library (required for k8s modules)
   pip3 install kubernetes

   # Install bcrypt (for password hashing)
   pip3 install bcrypt
   ```

3. **Ansible Collections**
   ```bash
   # Install kubernetes.core collection
   ansible-galaxy collection install kubernetes.core
   ```

4. **ArgoCD CLI** (for configuration tasks)
   ```bash
   # macOS
   brew install argocd

   # Verify installation
   argocd version --client
   ```

### Initial Setup

1. **Navigate to Ansible directory**
   ```bash
   cd ansible
   ```

2. **Create vault password file** (for ansible-vault encryption)
   ```bash
   # Option 1: Create password file (recommended for local dev)
   echo "your-vault-password" > .vault_pass
   chmod 600 .vault_pass

   # Option 2: Use --ask-vault-pass flag when running playbooks
   ```

3. **Configure admin password**
   ```bash
   # Copy example vault file
   cp vars/vault.yml.example vars/vault.yml

   # Edit and set secure password
   nano vars/vault.yml
   # Change: argocd_admin_password: "SecureArgoCD2025!"

   # Encrypt vault file
   ansible-vault encrypt vars/vault.yml --vault-password-file .vault_pass

   # Verify encryption
   cat vars/vault.yml  # Should show encrypted content
   ```

4. **Review configuration variables** (optional customization)
   ```bash
   # Edit non-sensitive configuration
   nano vars/argocd-config.yml

   # Key variables:
   # - argocd_server_url: https://localhost:4243
   # - gitlab_repo_url: GitLab repository URL
   # - app_service_port: 4244 (external port for application)
   # - auto_sync_enabled: true (GitOps auto-sync)
   ```

### Execute Ansible Playbook

Run the main playbook to configure ArgoCD:

```bash
# Full configuration (admin password + applications)
ansible-playbook -i inventory/hosts.yml playbooks/argocd-setup.yml --vault-password-file .vault_pass

# Or use interactive password prompt
ansible-playbook -i inventory/hosts.yml playbooks/argocd-setup.yml --ask-vault-pass

# Run specific roles only (using tags)
# Admin password only:
ansible-playbook -i inventory/hosts.yml playbooks/argocd-setup.yml --tags admin --vault-password-file .vault_pass

# Applications only (if password already set):
ansible-playbook -i inventory/hosts.yml playbooks/argocd-setup.yml --tags apps --vault-password-file .vault_pass

# Check mode (dry run, no changes)
ansible-playbook -i inventory/hosts.yml playbooks/argocd-setup.yml --check --vault-password-file .vault_pass
```

### What the Playbook Does

**Pre-tasks** (verification):
- Verifies ArgoCD namespace exists
- Checks ArgoCD server pod is running
- Validates application namespace exists

**Role: argocd-admin** (password management):
1. Retrieves auto-generated admin password from Kubernetes secret
2. Logs into ArgoCD CLI with initial password
3. Updates admin password to your secure password (from vault.yml)
4. Verifies new password works

**Role: argocd-apps** (application configuration):
1. Renders ArgoCD Application manifest from Jinja2 template
2. Validates manifest syntax with kubectl dry-run
3. Creates or updates ArgoCD application: `belay-portage-gitlab-example-app`
4. Triggers initial sync if application is OutOfSync
5. Configures sync policies: auto-sync, prune, self-heal

**Post-tasks** (validation):
- Lists all configured ArgoCD applications
- Verifies GitLab application exists
- Displays application sync and health status

### Verify Configuration

After playbook execution:

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Get detailed application status
argocd app get belay-portage-gitlab-example-app

# Check deployed pods
kubectl get pods -n belay-example-app

# Check application service
kubectl get svc -n belay-example-app
# Expected: LoadBalancer service on port 4244

# Access application
open http://localhost:4244
```

### Login to ArgoCD UI

```bash
# Access ArgoCD UI
open https://localhost:4243

# Login credentials:
# - Username: admin
# - Password: (your password from vars/vault.yml)
```

### Troubleshooting Ansible

**Issue: kubernetes Python library not found**
```bash
# Install with pip3
pip3 install kubernetes

# Verify installation
python3 -c "import kubernetes; print(kubernetes.__version__)"
```

**Issue: argocd CLI not found**
```bash
# Install ArgoCD CLI
brew install argocd

# Or download manually
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-amd64
chmod +x /usr/local/bin/argocd
```

**Issue: Ansible vault decryption failed**
```bash
# Verify vault password is correct
ansible-vault view vars/vault.yml --vault-password-file .vault_pass

# Re-encrypt with new password
ansible-vault rekey vars/vault.yml
```

**Issue: ArgoCD login context deadline exceeded**
```bash
# Check ArgoCD server is accessible
curl -k https://localhost:4243/healthz

# Verify ArgoCD version compatibility
argocd version --client
kubectl get pods -n argocd -o jsonpath='{.items[0].spec.containers[0].image}'

# If versions mismatch, upgrade ArgoCD via Terraform
# Update variables.tf: argocd_chart_version
terraform apply
```

**Issue: Application not syncing**
```bash
# Check application status
argocd app get belay-portage-gitlab-example-app

# Check repository is accessible
argocd repo list

# Force sync
argocd app sync belay-portage-gitlab-example-app
```

**See**: `docs/implementation-argocd-gitlab-app.md` for detailed implementation steps and troubleshooting.

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

**Last Updated**: 2025-11-17
**Terraform Version**: 1.11.2
**ArgoCD Version**: 7.9.1 (ArgoCD v2.14.11)
**Kubernetes**: Docker Desktop v1.34.1
**Ansible Version**: 2.18.3
