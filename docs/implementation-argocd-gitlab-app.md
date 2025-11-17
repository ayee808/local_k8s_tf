# Architecture: Terraform/Ansible Split

**IMPORTANT**: This project now follows a clear separation of concerns:

- **Terraform Responsibility** (completed first): Infrastructure provisioning (ArgoCD installation via Helm chart)
- **Ansible Responsibility** (this document): Configuration management (ArgoCD applications, repositories, settings, admin password)

This implementation document covers **Ansible configuration of ArgoCD** - the configuration layer that sits on top of the Terraform-provisioned infrastructure.

---

# Goal
Configure ArgoCD using Ansible to deploy the `belay-portage-gitlab-example-app` (React frontend) which is built and scanned via GitLab CI + Portage CD. The container images are pushed to GitLab Container Registry and should be continuously deployed by ArgoCD.

**Prerequisites**:
- Terraform must be applied first (ArgoCD installed to cluster)
- ArgoCD running with auto-generated admin password

# Current State

**Terraform Layer (Infrastructure - COMPLETED)**:
- Docker Desktop Kubernetes cluster configured
- ArgoCD installed via Helm chart v7.6.8
- Namespaces created: `argocd`, `belay-example-app`
- ArgoCD accessible via LoadBalancer at `http://localhost:4242`
- Auto-generated admin password: `5QcDSA1d6VN69vx4`
- **OLD**: Two ArgoCD Applications in Terraform (already removed in terraform refactor)

**Ansible Layer (Configuration - TO BE IMPLEMENTED)**:
- No Ansible playbooks yet
- No ArgoCD applications configured via Ansible
- Admin password still auto-generated (needs to be changed by Ansible)

**Application Repository** (`belay-portage-gitlab-example-app`):
- GitLab CI pipeline configured with Portage CD (.gitlab-ci.yml)
- Container image: `registry.gitlab.com/holomuatech/belay-portage-gitlab-example-app:latest`
- Application runs on port 8080 (nginx serving React build)
- **NO Kubernetes manifests yet** (need to create)

# Reference Documents
- Terraform implementation: `docs/implementation-terraform-refactor.md` (must be completed first)
- GitLab CI config: `../belay-portage-gitlab-example-app/.gitlab-ci.yml`
- ArgoCD CLI documentation: https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd/
- Ansible k8s module: https://docs.ansible.com/ansible/latest/collections/kubernetes/core/
- Implementation template: `docs/implementation-template.md`

# Workflow Rules
This is a live document intended to provide clear and concise context to the AI agent and operator performing the work. Always update this document as we work through it. After completing tasks, check the boxes to show the end user that the task has been completed. Provide any deviation details or decisions in line to the tasks. Once tasks have been updated, moved, deleted or completed, stop and provide an update to the user before moving on to validations. Perform validations using CLI libraries, Curl or browsermcp/playwright to verify things. If the validation cannot be done by you then provide step by step instructions to the user to validate the validation task. **Include this workflow paragraph in the actual implementation file so that an AI agent following this plan will understand how to work with the user.**

# Implementation Steps

## Step 0.0: Verify Terraform Prerequisites ✅ COMPLETE
Ensure Terraform has been applied and ArgoCD is running before proceeding with Ansible configuration.

Tasks:
- [x] Verify Terraform implementation is complete (check `implementation-terraform-refactor.md`) - All 10 steps completed
- [x] Confirm ArgoCD is installed: `kubectl get pods -n argocd` - 8/8 pods Running
- [x] Retrieve auto-generated admin password: `5QcDSA1d6VN69vx4`
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  ```
- [x] Access ArgoCD UI and verify it's accessible - LoadBalancer at `http://localhost:4242`

Validation Steps:
- [x] All ArgoCD pods in Running state - 8/8 pods healthy (73+ min uptime)
- [x] ArgoCD UI accessible at `http://localhost:4242` (LoadBalancer configured with custom ports)
- [x] Can login with username `admin` and auto-generated password `5QcDSA1d6VN69vx4`
- [x] No applications configured yet (empty dashboard) - Verified via kubectl

**Completion Notes** (2025-11-17):
- Namespace customization: Using `belay-example-app` instead of default `helloworld`
- Custom ArgoCD ports: HTTP=4242, HTTPS=4243 (configured in terraform.tfvars)
- All prerequisites verified and ready for Ansible configuration layer

---

## Step 1.0: Create Kubernetes Manifests in GitLab App Repo
Create K8s deployment and service manifests for the React application in the GitLab repository so ArgoCD can sync them.

**Location**: `../belay-portage-gitlab-example-app/k8s/`

**Files to create**:
- `deployment.yaml` - Kubernetes Deployment
  - Image: `registry.gitlab.com/holomuatech/belay-portage-gitlab-example-app:latest`
  - Port: 8080
  - ImagePullPolicy: Always (to pull latest CI builds)
  - Replicas: 1 (local dev)

- `service.yaml` - Kubernetes Service
  - Type: LoadBalancer (for docker-desktop local access)
  - Port: 80 → targetPort: 8080

Tasks:
- [ ] Create `../belay-portage-gitlab-example-app/k8s/` directory
- [ ] Create `deployment.yaml` with proper labels and image reference
- [ ] Create `service.yaml` with LoadBalancer configuration
- [ ] Commit and push to GitLab repo (required for ArgoCD to sync)

Validation Steps:
- [ ] Verify YAML syntax is valid: `kubectl apply --dry-run=client -f k8s/`
- [ ] Confirm files are in GitLab repo at `https://gitlab.com/holomuatech/belay-portage-gitlab-example-app/tree/main/k8s`

---

## Step 2.0: Create Ansible Project Structure
Set up Ansible directory structure for ArgoCD configuration management.

**Location**: `local_k8s_tf/ansible/`

**Directory structure**:
```
ansible/
├── ansible.cfg          # Ansible configuration
├── inventory/
│   └── hosts.yml        # Inventory (localhost for K8s config)
├── playbooks/
│   ├── argocd-setup.yml         # Main ArgoCD setup playbook
│   └── argocd-applications.yml  # ArgoCD application configuration
├── roles/
│   ├── argocd-admin/           # Admin password and settings
│   └── argocd-apps/            # Application definitions
└── vars/
    ├── argocd-config.yml       # ArgoCD configuration variables
    └── vault.yml               # Encrypted secrets (admin password)
```

Tasks:
- [ ] Create `ansible/` directory structure
- [ ] Create `ansible.cfg` with basic configuration
- [ ] Create `inventory/hosts.yml` with localhost entry
- [ ] Create `vars/argocd-config.yml` with non-sensitive config
- [ ] Create `vars/vault.yml` template for secrets (encrypted with ansible-vault)
- [ ] Update `.gitignore` to exclude `vars/vault.yml`

Validation Steps:
- [ ] Run `ansible --version` to verify Ansible is installed
- [ ] Run `ansible-inventory --list -i inventory/hosts.yml` to verify inventory
- [ ] Verify directory structure matches plan

---

## Step 3.0: Create Ansible Role - ArgoCD Admin Configuration
Create Ansible role to configure ArgoCD admin password and settings.

**Location**: `ansible/roles/argocd-admin/`

**Role tasks**:
1. Retrieve auto-generated admin password from K8s secret
2. Login to ArgoCD CLI with auto-generated password
3. Change admin password to secure password from vault
4. Configure ArgoCD settings (if needed)

Tasks:
- [ ] Create role directory: `ansible/roles/argocd-admin/tasks/main.yml`
- [ ] Task: Retrieve auto-generated password from K8s secret
- [ ] Task: Install/verify argocd CLI is available
- [ ] Task: Login to ArgoCD with auto-generated password
- [ ] Task: Update admin password from vault variable
- [ ] Task: Verify new password works
- [ ] Create `vars/main.yml` with ArgoCD server URL

Validation Steps:
- [ ] Run playbook in check mode: `ansible-playbook --check playbooks/argocd-setup.yml`
- [ ] Verify role syntax is valid
- [ ] Test password retrieval task independently

---

## Step 4.0: Create Ansible Role - ArgoCD Applications
Create Ansible role to define and configure ArgoCD applications.

**Location**: `ansible/roles/argocd-apps/`

**Role tasks**:
1. Create ArgoCD application for GitLab hello-world app
2. Configure repository access (if private)
3. Set sync policies (auto-sync, prune, self-heal)

Tasks:
- [ ] Create role directory: `ansible/roles/argocd-apps/tasks/main.yml`
- [ ] Task: Define GitLab hello-world application using `kubernetes.core.k8s` module
- [ ] Configure ArgoCD Application spec:
  - Repo URL: `https://gitlab.com/holomuatech/belay-portage-gitlab-example-app`
  - Path: `k8s/`
  - Destination namespace: `belay-example-app`
  - Auto-sync: enabled with prune and selfHeal
- [ ] Template application YAML in `templates/gitlab-app.yml.j2`
- [ ] Create `vars/main.yml` with application configuration variables

Validation Steps:
- [ ] Run playbook in check mode
- [ ] Verify application YAML syntax with `kubectl apply --dry-run=client`
- [ ] Test template rendering with ansible debug task

---

## Step 5.0: Create Main Playbook
Create main Ansible playbook that orchestrates ArgoCD configuration.

**Location**: `ansible/playbooks/argocd-setup.yml`

**Playbook structure**:
```yaml
---
- name: Configure ArgoCD
  hosts: localhost
  connection: local
  vars_files:
    - ../vars/argocd-config.yml
    - ../vars/vault.yml
  roles:
    - argocd-admin      # Configure admin password first
    - argocd-apps       # Then configure applications
```

Tasks:
- [ ] Create `argocd-setup.yml` playbook
- [ ] Add pre-tasks to verify ArgoCD is running
- [ ] Include both roles in correct order
- [ ] Add post-tasks to verify configuration
- [ ] Create `vars/argocd-config.yml` with non-sensitive variables
- [ ] Create `vars/vault.yml` with ansible-vault for admin password

Validation Steps:
- [ ] Run syntax check: `ansible-playbook --syntax-check playbooks/argocd-setup.yml`
- [ ] Run in check mode: `ansible-playbook --check playbooks/argocd-setup.yml`
- [ ] Verify vault is encrypted: `cat vars/vault.yml` should show encrypted content

---

## Step 6.0: Remove ArgoCD Applications from Terraform
Clean up Terraform configuration by removing ArgoCD application manifests (now managed by Ansible).

**File to modify**: `local_k8s_tf/main.tf`

**Changes**:
- Remove `kubernetes_manifest.argocd_app_helloworld_api` resource
- Remove `kubernetes_manifest.argocd_app_helloworld_ui` resource
- Remove `argocd-manifests/` directory (applications now in Ansible)

Tasks:
- [ ] Remove ArgoCD application resources from `main.tf`
- [ ] Delete `argocd-manifests/` directory
- [ ] Run `terraform plan` to verify changes
- [ ] Run `terraform apply` to remove application resources from state

Validation Steps:
- [ ] Terraform plan shows 2 resources to be destroyed (old apps)
- [ ] Terraform plan shows no other changes
- [ ] After apply, verify apps still exist in ArgoCD (managed by Ansible now)

---

## Step 7.0: Execute Ansible Playbook
Run the Ansible playbook to configure ArgoCD with new admin password and applications.

Tasks:
- [ ] Create ansible vault password file (or use --ask-vault-pass)
- [ ] Set secure admin password in `vars/vault.yml`
- [ ] Run playbook: `ansible-playbook -i inventory/hosts.yml playbooks/argocd-setup.yml --ask-vault-pass`
- [ ] Monitor playbook execution for errors
- [ ] Verify all tasks complete successfully

Validation Steps:
- [ ] Playbook completes without errors
- [ ] Admin password changed (old password no longer works)
- [ ] New password works for ArgoCD UI login
- [ ] ArgoCD application appears in dashboard
- [ ] Application shows sync status

---

## Step 8.0: Verify ArgoCD Deployment
Confirm ArgoCD successfully synced the GitLab app and deployed the container.

Tasks:
- [ ] Access ArgoCD UI with new admin password
- [ ] Check application sync status in ArgoCD UI
- [ ] Verify pods are running in `belay-example-app` namespace
- [ ] Test application accessibility via LoadBalancer

Validation Steps:
- [ ] ArgoCD shows application as "Synced" and "Healthy"
- [ ] Run `kubectl get pods -n belay-example-app` - pod should be Running
- [ ] Run `kubectl get svc -n belay-example-app` - service should have EXTERNAL-IP (localhost on docker-desktop)
- [ ] Access app in browser at `http://localhost` - should show React app
- [ ] Verify correct image is deployed: `kubectl describe pod -n belay-example-app | grep Image:`
- [ ] Old applications (helloworld-api, helloworld-ui) are removed

---

# Changelog

## Step 0.0 Completed - 2025-11-17
- **COMPLETE**: All Terraform prerequisites verified and ready for Ansible layer
- Infrastructure verification complete: ArgoCD v7.6.8 running (8/8 pods healthy)
- LoadBalancer accessible at `http://localhost:4242` with custom ports (HTTP=4242, HTTPS=4243)
- Auto-generated admin password retrieved: `5QcDSA1d6VN69vx4`
- **Namespace customization noted**: Using `belay-example-app` instead of default `helloworld`
- Updated all references in implementation document from `helloworld` to `belay-example-app`
- Ready to proceed with Step 1.0: Create Kubernetes manifests in GitLab repository

## Architectural Update - 2025-11-16
- **MAJOR CHANGE**: Switched from Terraform-based to Ansible-based ArgoCD configuration
- **Rationale**: Clear separation of concerns - Terraform for infrastructure, Ansible for configuration
- ArgoCD applications now managed via Ansible playbooks instead of Terraform manifests
- Admin password management moved to Ansible (Terraform installs with auto-generated password)
- Removed ArgoCD application resources from Terraform configuration
- Added Ansible project structure with roles for admin and applications
- Prerequisites now include completed Terraform implementation

## Initial Plan
- Created implementation plan based on user requirements
- Decision: Place K8s manifests in GitLab app repo (standard GitOps pattern)
- Decision: Use GitLab repo URL for ArgoCD: `https://gitlab.com/holomuatech/belay-portage-gitlab-example-app`
- Decision: Remove old hello-world apps completely
- Decision: Use LoadBalancer service type for docker-desktop local access
- **Updated**: Use Ansible instead of Terraform for ArgoCD application management
