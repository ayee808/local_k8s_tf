# Architecture Documentation

**Project**: local_k8s_tf - Local Kubernetes ArgoCD Deployment
**Last Updated**: 2025-11-17
**Version**: Terraform 1.11.2, ArgoCD 7.9.1 (v2.14.11), Kubernetes v1.34.1, Ansible 2.18.3

---

## A. Infrastructure Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Docker Desktop Environment                       │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    Kubernetes Cluster (docker-desktop)            │  │
│  │                                                                   │  │
│  │  ┌─────────────────────────────────────────────────────────────┐ │  │
│  │  │  Namespace: argocd                                          │ │  │
│  │  │                                                             │ │  │
│  │  │  ┌──────────────────────┐    ┌─────────────────────────┐  │ │  │
│  │  │  │  argocd-server       │───▶│  LoadBalancer Service  │  │ │  │
│  │  │  │  (Deployment)        │    │  Type: LoadBalancer    │  │ │  │
│  │  │  │  - UI/API            │    │  Port: 80, 443         │  │ │  │
│  │  │  │  - HTTPS/gRPC        │    └──────────┬──────────────┘  │ │  │
│  │  │  └──────────────────────┘               │                 │ │  │
│  │  │                                          │                 │ │  │
│  │  │  ┌──────────────────────┐               │                 │ │  │
│  │  │  │  argocd-repo-server  │               │                 │ │  │
│  │  │  │  (Deployment)        │               │                 │ │  │
│  │  │  │  - Git repo cache    │               │                 │ │  │
│  │  │  │  - Manifest render   │               │                 │ │  │
│  │  │  └──────────────────────┘               │                 │ │  │
│  │  │                                          │                 │ │  │
│  │  │  ┌──────────────────────────────────┐   │                 │ │  │
│  │  │  │  argocd-application-controller   │   │                 │ │  │
│  │  │  │  (StatefulSet)                   │   │                 │ │  │
│  │  │  │  - K8s resource reconciliation   │   │                 │ │  │
│  │  │  │  - Sync state monitoring         │   │                 │ │  │
│  │  │  └──────────────────────────────────┘   │                 │ │  │
│  │  │                                          │                 │ │  │
│  │  │  ┌──────────────────────┐               │                 │ │  │
│  │  │  │  argocd-redis        │               │                 │ │  │
│  │  │  │  (Deployment)        │               │                 │ │  │
│  │  │  │  - Cache layer       │               │                 │ │  │
│  │  │  └──────────────────────┘               │                 │ │  │
│  │  │                                          │                 │ │  │
│  │  │  ┌──────────────────────┐               │                 │ │  │
│  │  │  │  argocd-dex-server   │               │                 │ │  │
│  │  │  │  (Deployment)        │               │                 │ │  │
│  │  │  │  - SSO/Auth          │               │                 │ │  │
│  │  │  └──────────────────────┘               │                 │ │  │
│  │  │                                          │                 │ │  │
│  │  │  ┌──────────────────────────────────┐   │                 │ │  │
│  │  │  │  argocd-applicationset-controller│   │                 │ │  │
│  │  │  │  (Deployment)                    │   │                 │ │  │
│  │  │  │  - Multi-cluster app templates   │   │                 │ │  │
│  │  │  └──────────────────────────────────┘   │                 │ │  │
│  │  │                                          │                 │ │  │
│  │  │  ┌──────────────────────────────────┐   │                 │ │  │
│  │  │  │  argocd-notifications-controller │   │                 │ │  │
│  │  │  │  (Deployment)                    │   │                 │ │  │
│  │  │  │  - Webhook/Slack/Email alerts    │   │                 │ │  │
│  │  │  └──────────────────────────────────┘   │                 │ │  │
│  │  │                                          │                 │ │  │
│  │  │  ┌──────────────────────────────────┐   │                 │ │  │
│  │  │  │  Secrets                         │   │                 │ │  │
│  │  │  │  - argocd-initial-admin-secret   │   │                 │ │  │
│  │  │  │  - TLS certificates              │   │                 │ │  │
│  │  │  └──────────────────────────────────┘   │                 │ │  │
│  │  └─────────────────────────────────────────┘                 │ │  │
│  │                                                               │ │  │
│  │  ┌─────────────────────────────────────────────────────────┐ │  │
│  │  │  Namespace: belay-example-app (or custom app_namespace) │ │  │
│  │  │                                                         │ │  │
│  │  │  [Application workloads managed by ArgoCD]             │ │  │
│  │  │  - Deployments, Services, ConfigMaps                   │ │  │
│  │  │  - Synced from Git repositories                        │ │  │
│  │  └─────────────────────────────────────────────────────────┘ │  │
│  │                                                                │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                       │
└───────────────────────────────────────┬───────────────────────────────┘
                                        │
                                        ▼
                              ┌─────────────────────┐
                              │  localhost:80       │
                              │  (LoadBalancer IP)  │
                              └─────────────────────┘
                                        │
                                        ▼
                              ┌─────────────────────┐
                              │  User Browser       │
                              │  ArgoCD UI Access   │
                              └─────────────────────┘

External Dependencies:
┌──────────────────────────┐
│  Git Repositories        │──▶ ArgoCD pulls K8s manifests
│  (GitLab/GitHub)         │    (configured via Ansible)
└──────────────────────────┘

┌──────────────────────────┐
│  Helm Repository         │──▶ Terraform pulls ArgoCD chart
│  argoproj.github.io      │    Version: 7.6.8
└──────────────────────────┘
```

**Network Flow**:
- **User → ArgoCD UI**: http://localhost (LoadBalancer) or https://localhost:8080 (port-forward)
- **ArgoCD → Git Repos**: HTTPS (port 443) for manifest retrieval
- **ArgoCD → K8s API**: In-cluster service account authentication
- **Terraform → Helm Repo**: HTTPS (port 443) to fetch ArgoCD chart

**Security Boundaries**:
- **Namespace isolation**: `argocd` and `belay-example-app` namespaces
- **Self-signed TLS**: ArgoCD server uses auto-generated certificates
- **Service account**: ArgoCD uses K8s RBAC for cluster access
- **Password management**: Auto-generated initially, rotated by Ansible

---

## B. Application Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Application Components                            │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│  TERRAFORM LAYER (Infrastructure Provisioning)                           │
│                                                                          │
│  ┌────────────────┐      ┌──────────────────┐      ┌─────────────────┐ │
│  │  Provider      │      │  Resources       │      │  Outputs        │ │
│  │  Configuration │─────▶│  - Namespaces    │─────▶│  - Access URLs  │ │
│  │  - Kubernetes  │      │  - Helm Release  │      │  - Commands     │ │
│  │  - Helm        │      └──────────────────┘      │  - Password     │ │
│  └────────────────┘                                └─────────────────┘ │
│                                                                          │
│  ┌────────────────┐                                                     │
│  │  Variables     │                                                     │
│  │  - kubeconfig  │                                                     │
│  │  - context     │                                                     │
│  │  - namespaces  │                                                     │
│  │  - chart ver   │                                                     │
│  └────────────────┘                                                     │
└──────────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  KUBERNETES LAYER (ArgoCD Installation)                                  │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  ArgoCD Server (Frontend/API)                                   │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │   │
│  │  │  Web UI      │  │  gRPC API    │  │  REST API            │  │   │
│  │  │  (React)     │  │  (CLI access)│  │  (webhook callbacks) │  │   │
│  │  └──────────────┘  └──────────────┘  └──────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                │                                        │
│                                ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  ArgoCD Application Controller (Backend Reconciliation)         │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │   │
│  │  │  Sync Engine │──│  Health      │──│  Diff Engine         │  │   │
│  │  │              │  │  Assessment  │  │  (desired vs actual) │  │   │
│  │  └──────────────┘  └──────────────┘  └──────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                │                                        │
│                                ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  ArgoCD Repository Server (Git/Helm Integration)                │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │   │
│  │  │  Git Clone   │──│  Manifest    │──│  Template Rendering  │  │   │
│  │  │  & Cache     │  │  Generation  │  │  (Helm/Kustomize)    │  │   │
│  │  └──────────────┘  └──────────────┘  └──────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                │                                        │
│                                ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Supporting Components                                          │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │   │
│  │  │  Redis       │  │  Dex Server  │  │  ApplicationSet Ctrl │  │   │
│  │  │  (Cache)     │  │  (SSO/Auth)  │  │  (Multi-cluster)     │  │   │
│  │  └──────────────┘  └──────────────┘  └──────────────────────┘  │   │
│  │  ┌──────────────┐                                               │   │
│  │  │ Notifications│                                               │   │
│  │  │ Controller   │                                               │   │
│  │  └──────────────┘                                               │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  ANSIBLE LAYER (Configuration Management)                                │
│                                                                          │
│  ┌────────────────┐      ┌──────────────────┐      ┌─────────────────┐ │
│  │  Playbooks     │─────▶│  Roles           │─────▶│  Tasks          │ │
│  │  - argocd-     │      │  - argocd-admin  │      │  - Password mgmt│ │
│  │    setup.yml   │      │    (14 tasks)    │      │  - CLI login    │ │
│  │                │      │  - argocd-apps   │      │  - Create apps  │ │
│  │                │      │    (19 tasks)    │      │  - Sync trigger │ │
│  └────────────────┘      └──────────────────┘      └─────────────────┘ │
│                                                                          │
│  ┌────────────────┐      ┌──────────────────┐                          │
│  │  Inventory     │      │  Variables       │                          │
│  │  - hosts.yml   │      │  - argocd-       │                          │
│  │  (localhost)   │      │    config.yml    │                          │
│  │                │      │  - vault.yml     │                          │
│  └────────────────┘      │  (encrypted)     │                          │
│                          └──────────────────┘                          │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  Configuration Details                                             │ │
│  │  - Python interpreter: /opt/homebrew/bin/python3                  │ │
│  │  - Required libraries: kubernetes (v34.1.0), bcrypt               │ │
│  │  - Collections: kubernetes.core (v5.1.0)                          │ │
│  │  - Password: bcrypt hash in argocd-secret                         │ │
│  │  - Applications: belay-portage-gitlab-example-app                 │ │
│  │  - GitLab repo: HolomuaTech/belay-portage-gitlab-example-app.git │ │
│  │  - Sync policies: auto-sync, prune, self-heal                    │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────┘

Data Flow Direction:
  Terraform ──▶ Kubernetes (Immutable Infrastructure)
  Ansible ──▶ ArgoCD API (Mutable Configuration)
  ArgoCD ──▶ Kubernetes API (Application Deployment)
  ArgoCD ──▶ Git Repos (Manifest Retrieval)
```

**Communication Patterns**:
- **Synchronous**: Web UI → ArgoCD Server → K8s API (immediate read/write)
- **Asynchronous**: Application Controller → Git polling (periodic reconciliation)
- **Event-driven**: Notifications Controller → Webhooks (on sync events)

---

## C. Application Structure Outline

### Terraform Module
Purpose: Infrastructure provisioning layer for ArgoCD installation on local Kubernetes

#### Provider Configurations
- **kubernetes provider**
  - config_path: Path to kubeconfig file
  - config_context: K8s context name (docker-desktop)

- **helm provider**
  - kubernetes.config_path: Same as kubernetes provider
  - kubernetes.config_context: Same as kubernetes provider

#### Resources

##### kubernetes_namespace.argocd
Purpose: Creates isolated namespace for ArgoCD installation
- metadata.name: Namespace name from var.argocd_namespace (default: "argocd")

##### kubernetes_namespace.helloworld
Purpose: Creates namespace for application deployments
- metadata.name: Namespace name from var.app_namespace (default: "belay-example-app")

##### helm_release.argocd
Purpose: Deploys ArgoCD via official Helm chart
- name: "argocd"
- namespace: References kubernetes_namespace.argocd
- chart: "argo-cd"
- repository: "https://argoproj.github.io/argo-helm"
- version: From var.argocd_chart_version (default: "7.6.8")
- values: Loaded from argocd-values.yaml (service type configuration)

#### Variables (variables.tf)

##### Kubernetes Configuration
- **kubeconfig_path**: string
  Path to kubeconfig file for cluster access
  Default: "~/.kube/config"

- **kube_context**: string
  Kubernetes context to use from kubeconfig
  Default: "docker-desktop"
  Validation: Must be valid K8s namespace format

##### Namespace Configuration
- **argocd_namespace**: string
  Namespace for ArgoCD installation
  Default: "argocd"
  Validation: Lowercase alphanumeric and hyphens only

- **app_namespace**: string
  Namespace for application deployments
  Default: "helloworld"
  Validation: Lowercase alphanumeric and hyphens only

##### ArgoCD Configuration
- **argocd_chart_version**: string
  Version of ArgoCD Helm chart to install
  Default: "7.6.8"

- **argocd_service_type**: string
  Kubernetes service type for ArgoCD server
  Default: "LoadBalancer"
  Validation: Must be LoadBalancer, NodePort, or ClusterIP

#### Outputs (outputs.tf)

##### argocd_namespace
Returns the actual ArgoCD namespace name from deployed resource

##### app_namespace
Returns the actual application namespace name from deployed resource

##### argocd_server_access
Provides multi-line instructions for accessing ArgoCD UI
- LoadBalancer access via http://localhost
- Port-forward access via kubectl command

##### argocd_admin_username
Returns static value: "admin"

##### argocd_initial_password
Provides kubectl commands to retrieve auto-generated admin password
- Linux/macOS command with base64 decoding
- Windows PowerShell command with .NET base64 decoding
- Notes about Ansible password rotation

##### useful_commands
Provides kubectl and ArgoCD CLI commands for:
- Checking installation status
- Viewing pods and services
- Viewing ArgoCD applications
- Accessing logs
- ArgoCD CLI login and usage

##### quick_start
Visual quick-start guide with formatted output
- Access instructions
- Password retrieval steps
- Verification commands
- Next steps for Ansible configuration

#### Configuration Files

##### argocd-values.yaml
Purpose: Helm chart values for ArgoCD customization
- server.service.type: LoadBalancer (exposes ArgoCD on localhost)
- Note: Admin password auto-generated by ArgoCD (not set here)

##### terraform.tfvars.example
Purpose: Template for user configuration
- Shows all 6 variables with descriptions
- All variables have defaults (no required values)
- Includes comments about Ansible configuration handoff

### ArgoCD Components (Deployed by Helm)

#### Frontend
Purpose: User-facing web interface and API layer

##### argocd-server (Deployment)
Purpose: Serves web UI and provides API access
- Container: quay.io/argoproj/argocd:v2.x.x
- Ports: 8080 (HTTP), 8083 (gRPC)
- Environment: K8s service account token for cluster access
- Volume mounts: TLS certificates, RBAC config

Key functions:
- **serveUI()**: Renders React-based web interface
- **handleAPIRequest(req)**: Processes REST/gRPC API calls
- **authenticateUser(username, password)**: Validates credentials against K8s secret
- **listApplications()**: Returns all ArgoCD Application resources
- **getApplicationStatus(appName)**: Returns sync/health status for application

##### argocd-server-ext (Deployment)
Purpose: External-facing server pod for LoadBalancer service
- Identical configuration to argocd-server
- Dedicated to LoadBalancer service endpoint

#### Backend Controllers

##### argocd-application-controller (StatefulSet)
Purpose: Core reconciliation engine that syncs Git state to K8s cluster
- Container: quay.io/argoproj/argocd:v2.x.x
- Replicas: 1 (StatefulSet for stable identity)
- Service account: argocd-application-controller

Key functions:
- **reconcileApplication(app)**: Main loop comparing desired (Git) vs actual (K8s) state
  - Fetches manifests from repo-server
  - Compares with live K8s resources
  - Applies diffs if auto-sync enabled
  - Returns sync result and health status

- **assessHealth(resources)**: Evaluates health of deployed resources
  - Checks pod status, deployment replicas
  - Returns: Healthy, Progressing, Degraded, Suspended, Missing

- **computeDiff(desired, actual)**: Generates diff between Git and cluster
  - Returns JSON diff of all resource changes

- **pruneResources(app, orphanedResources)**: Removes resources not in Git
  - Only if prune policy enabled

- **syncWaves(resources)**: Applies resources in order based on sync-wave annotation

##### argocd-applicationset-controller (Deployment)
Purpose: Manages ApplicationSet CRDs for multi-cluster app generation
- Container: quay.io/argoproj/argocd:v2.x.x
- Generates ArgoCD Application resources from templates

Key functions:
- **generateApplications(appSet)**: Creates Application resources from generators
- **reconcileApplicationSet(appSet)**: Updates applications when template changes

##### argocd-notifications-controller (Deployment)
Purpose: Sends notifications on application events
- Container: quay.io/argoproj/argocd:v2.x.x
- Supports webhooks, Slack, email, etc.

Key functions:
- **watchApplicationEvents()**: Monitors application sync/health changes
- **sendNotification(trigger, context)**: Sends notifications based on triggers

#### Repository Management

##### argocd-repo-server (Deployment)
Purpose: Handles Git repository operations and manifest generation
- Container: quay.io/argoproj/argocd:v2.x.x
- Replicas: 1
- Volume mounts: Git repository cache, GPG keys, TLS certificates

Key functions:
- **cloneRepository(repoURL, revision)**: Clones Git repo to local cache
  - Uses credentials from K8s secrets
  - Supports HTTPS, SSH, GitHub App authentication
  - Returns local path to cloned repo

- **generateManifests(app, revision)**: Generates K8s manifests from repo
  - Supports Helm, Kustomize, Jsonnet, plain YAML
  - Applies parameter overrides
  - Returns array of K8s resource manifests

- **renderHelmChart(chart, values)**: Renders Helm chart with values
  - Executes helm template command
  - Returns rendered YAML manifests

- **updateCache()**: Refreshes Git repository cache
  - Runs on periodic interval (default: 3 minutes)

#### Supporting Services

##### argocd-dex-server (Deployment)
Purpose: Provides SSO and OIDC authentication
- Container: ghcr.io/dexidp/dex:v2.x.x
- Integrates with external identity providers (Google, GitHub, LDAP, etc.)

Key functions:
- **authenticateOIDC(provider, token)**: Validates OIDC tokens
- **listConnectors()**: Returns configured SSO connectors

##### argocd-redis (Deployment)
Purpose: Caching layer for application state
- Container: redis:7.x
- Stores application metadata, UI cache
- No persistence (ephemeral cache)

Key functions:
- **cacheApplicationState(appName, state)**: Stores application state for fast retrieval
- **getCachedManifests(repoURL, revision)**: Retrieves cached manifests

### Kubernetes Resources (Created by ArgoCD)

#### Secrets

##### argocd-initial-admin-secret
Purpose: Stores auto-generated admin password on first install
- Type: Opaque
- Data fields:
  - password (base64): Auto-generated password (retrieved by Terraform output)
- Lifecycle: Deleted after password change via Ansible

##### argocd-secret
Purpose: Stores ArgoCD configuration secrets
- Type: Opaque
- Data fields:
  - admin.password (bcrypt): Admin password hash (updated by Ansible)
  - server.secretkey: Session encryption key

##### argocd-tls-certs-cm
Purpose: Stores TLS certificates for Git repositories
- Type: ConfigMap
- Used for HTTPS Git repository access

#### ServiceAccounts

##### argocd-server
Purpose: Service account for argocd-server pods
- Bound to Role: argocd-server
- Permissions: Read applications, projects, repositories

##### argocd-application-controller
Purpose: Service account for application-controller
- Bound to ClusterRole: argocd-application-controller
- Permissions: Full cluster access to manage applications

##### argocd-repo-server
Purpose: Service account for repo-server pods
- Bound to Role: argocd-repo-server
- Permissions: Read-only access to secrets for Git credentials

---

## D. Data Model Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│  Terraform State (Infrastructure Layer)                               │
└────────────────────────────────────────────────────────────────────────┘

kubernetes_namespace ─────────────────┐
  - argocd                             │
  - helloworld                         │
                                       │
                                       ▼
helm_release ─────────────────────────┘
  - argocd (chart v7.6.8)
  - references: kubernetes_namespace.argocd

                        │
                        │
                        ▼

┌────────────────────────────────────────────────────────────────────────┐
│  Kubernetes Resources (Deployed by Helm)                               │
└────────────────────────────────────────────────────────────────────────┘

Namespace                               Secret
  ├─ name: argocd                         ├─ argocd-initial-admin-secret (1:1)
  │                                       │    └─ data.password: <auto-gen>
  │                                       │
  │                                       ├─ argocd-secret (1:1)
  │                                       │    ├─ admin.password: <bcrypt>
  │                                       │    └─ server.secretkey: <random>
  │                                       │
  ├─ Deployment: argocd-server ──────────┼─ ServiceAccount: argocd-server (1:1)
  │    ├─ replicas: 2                    │
  │    └─ selector: app=argocd-server    │
  │                                      │
  ├─ StatefulSet: argocd-application-controller ─┼─ ServiceAccount: argocd-application-controller (1:1)
  │    ├─ replicas: 1                             │
  │    └─ selector: app=argocd-application-controller
  │                                                │
  ├─ Deployment: argocd-repo-server ──────────────┼─ ServiceAccount: argocd-repo-server (1:1)
  │    ├─ replicas: 1                             │
  │    └─ selector: app=argocd-repo-server        │
  │                                                │
  ├─ Deployment: argocd-redis                     │
  │    ├─ replicas: 1                             │
  │    └─ selector: app=argocd-redis              │
  │                                                │
  ├─ Deployment: argocd-dex-server                │
  │    └─ selector: app=argocd-dex-server         │
  │                                                │
  ├─ Deployment: argocd-applicationset-controller │
  │    └─ selector: app=argocd-applicationset-controller
  │                                                │
  ├─ Deployment: argocd-notifications-controller  │
  │    └─ selector: app=argocd-notifications-controller
  │                                                │
  └─ Service: argocd-server ──────────────────────┘
       ├─ type: LoadBalancer
       ├─ ports: 80, 443
       └─ externalIPs: localhost (Docker Desktop)


Namespace (Application)
  └─ name: belay-example-app (or custom)
       └─ [Application resources managed by ArgoCD]
            └─ Deployments, Services, ConfigMaps (synced from Git)

                        │
                        │
                        ▼

┌────────────────────────────────────────────────────────────────────────┐
│  ArgoCD Custom Resources (Managed by Ansible)                          │
└────────────────────────────────────────────────────────────────────────┘

Application (CRD: argoproj.io/v1alpha1)
  ├─ metadata.name: <app-name>
  ├─ metadata.namespace: argocd
  │
  ├─ spec.source ──────────────┐
  │    ├─ repoURL: <git-url>   │ (1:1 to Git Repository)
  │    ├─ path: <manifest-dir> │
  │    └─ targetRevision: HEAD │
  │                             │
  ├─ spec.destination          │
  │    ├─ server: https://kubernetes.default.svc
  │    └─ namespace: <target-namespace>
  │                             │
  ├─ spec.syncPolicy ──────────┘
  │    ├─ automated.prune: true
  │    ├─ automated.selfHeal: true
  │    └─ syncOptions: [CreateNamespace=true]
  │
  └─ status
       ├─ sync.status: Synced | OutOfSync
       ├─ health.status: Healthy | Progressing | Degraded
       └─ operationState: Running | Succeeded | Failed


Repository (ConfigMap: argocd-repositories-cm)
  ├─ metadata.name: argocd-repositories
  ├─ metadata.namespace: argocd
  └─ data
       └─ repositories: |
            - url: <git-repo-url>
              type: git
              passwordSecret: (optional)
              usernameSecret: (optional)
```

**Cardinality Key**:
- `(1:1)` - One-to-one relationship
- `(1:N)` - One-to-many relationship
- `(N:N)` - Many-to-many relationship

---

## E. Data Model Outline

### Terraform State Entities

#### kubernetes_namespace.argocd
Description: Represents the ArgoCD installation namespace
- metadata.name (PK): Namespace name (default: "argocd")
- metadata.uid: Unique Kubernetes identifier for namespace

Relationships:
- Referenced by helm_release.argocd (1:1)
- Contains all ArgoCD pods and services (1:N)

#### kubernetes_namespace.helloworld
Description: Represents the application deployment namespace
- metadata.name (PK): Namespace name (default: "belay-example-app")
- metadata.uid: Unique Kubernetes identifier for namespace

Relationships:
- Target for ArgoCD application deployments (1:N applications)

#### helm_release.argocd
Description: ArgoCD Helm chart deployment
- name (PK): "argocd"
- namespace (FK): References kubernetes_namespace.argocd.metadata[0].name
- chart: "argo-cd"
- version: Helm chart version (default: "7.6.8")
- values: YAML configuration from argocd-values.yaml

Relationships:
- Deployed to kubernetes_namespace.argocd (1:1)
- Creates multiple K8s resources (1:N)

### Kubernetes Resources (Deployed by Helm)

#### Secret: argocd-initial-admin-secret
Description: Stores auto-generated admin password on first install
- metadata.name (PK): "argocd-initial-admin-secret"
- metadata.namespace: "argocd"
- data.password: base64-encoded auto-generated password
- type: Opaque

Relationships:
- Retrieved by Terraform output for initial access (1:1)
- Deleted after Ansible password rotation

Lifecycle: Ephemeral (deleted after password change)

#### Secret: argocd-secret
Description: Stores ArgoCD core secrets and configuration
- metadata.name (PK): "argocd-secret"
- metadata.namespace: "argocd"
- data.admin.password: bcrypt hash of admin password (updated by Ansible)
- data.server.secretkey: Session encryption key
- type: Opaque

Relationships:
- Used by argocd-server for authentication (1:1)
- Updated by Ansible for password management (1:1)

Lifecycle: Persistent (updated, not replaced)

#### ServiceAccount: argocd-server
Description: Service account for ArgoCD server pods
- metadata.name (PK): "argocd-server"
- metadata.namespace: "argocd"

Relationships:
- Used by Deployment/argocd-server (1:1)
- Bound to Role/argocd-server (1:1)

Permissions: Read applications, projects, repositories

#### ServiceAccount: argocd-application-controller
Description: Service account for ArgoCD application controller
- metadata.name (PK): "argocd-application-controller"
- metadata.namespace: "argocd"

Relationships:
- Used by StatefulSet/argocd-application-controller (1:1)
- Bound to ClusterRole/argocd-application-controller (1:1)

Permissions: Full cluster access to manage application resources

#### Deployment: argocd-server
Description: Web UI and API server for ArgoCD
- metadata.name (PK): "argocd-server"
- metadata.namespace: "argocd"
- spec.replicas: 2
- spec.selector.matchLabels: app.kubernetes.io/name=argocd-server

Relationships:
- Uses ServiceAccount/argocd-server (1:1)
- Exposed by Service/argocd-server (1:1)
- Reads Secret/argocd-secret for authentication (1:1)

Ports: 8080 (HTTP), 8083 (gRPC)

#### StatefulSet: argocd-application-controller
Description: Core reconciliation controller for ArgoCD applications
- metadata.name (PK): "argocd-application-controller"
- metadata.namespace: "argocd"
- spec.replicas: 1
- spec.serviceName: argocd-application-controller

Relationships:
- Uses ServiceAccount/argocd-application-controller (1:1)
- Watches Application CRDs (1:N)
- Communicates with argocd-repo-server (N:1)

Lifecycle: StatefulSet (stable network identity)

#### Deployment: argocd-repo-server
Description: Git repository operations and manifest generation
- metadata.name (PK): "argocd-repo-server"
- metadata.namespace: "argocd"
- spec.replicas: 1

Relationships:
- Uses ServiceAccount/argocd-repo-server (1:1)
- Serves manifests to argocd-application-controller (1:N requests)
- Accesses Git repositories via configured credentials (N:N)

Volume mounts: /tmp (repo cache), /app/config/gpg/keys (GPG verification)

#### Service: argocd-server
Description: LoadBalancer service exposing ArgoCD UI
- metadata.name (PK): "argocd-server"
- metadata.namespace: "argocd"
- spec.type: LoadBalancer
- spec.ports:
  - http: 80 → 8080
  - https: 443 → 8080
- status.loadBalancer.ingress[0].ip: localhost (Docker Desktop)

Relationships:
- Routes traffic to Deployment/argocd-server (1:N pods)
- Exposed via LoadBalancer at http://localhost (1:1)

### ArgoCD Custom Resources (Managed by Ansible)

#### Application (CRD: argoproj.io/v1alpha1/Application)
Description: Defines a GitOps application managed by ArgoCD
- metadata.name (PK): Application identifier
- metadata.namespace: "argocd" (all Application CRDs in argocd namespace)
- spec.project: Project name (default: "default")
- spec.source.repoURL: Git repository URL
- spec.source.path: Path within repository to manifests
- spec.source.targetRevision: Git branch/tag/commit (default: "HEAD")
- spec.destination.server: K8s API server (default: "https://kubernetes.default.svc")
- spec.destination.namespace: Target namespace for deployment
- spec.syncPolicy.automated.prune: Auto-delete resources not in Git
- spec.syncPolicy.automated.selfHeal: Auto-sync on drift detection
- status.sync.status: Synced | OutOfSync
- status.health.status: Healthy | Progressing | Degraded | Missing | Suspended

Relationships:
- Deployed to destination namespace (1:1)
- Pulls manifests from Git repository (N:1 repo)
- Reconciled by argocd-application-controller (N:1 controller)

Lifecycle: Managed by Ansible, reconciled by ArgoCD controller

#### Repository (ConfigMap: argocd-repositories)
Description: Git repository credentials and configuration
- url: Git repository URL (unique identifier)
- type: "git"
- username: Git username (optional)
- password: Git password/token (optional, references Secret)
- sshPrivateKey: SSH private key (optional, references Secret)

Relationships:
- Referenced by Application.spec.source.repoURL (1:N applications)
- Credentials stored in separate Secrets (1:1 per repo)

Lifecycle: Managed by Ansible

### Variables and Configuration

#### terraform.tfvars
Description: User-provided variable values (gitignored)
- kubeconfig_path: Path to kubeconfig file
- kube_context: K8s context name
- argocd_namespace: ArgoCD namespace override
- app_namespace: Application namespace override
- argocd_chart_version: Helm chart version override
- argocd_service_type: Service type override

Relationships:
- Loaded by Terraform at runtime (no persistence)
- Values used to configure resources (1:N resources)

Lifecycle: Local configuration file (not in version control)

#### argocd-values.yaml
Description: Helm chart values for ArgoCD customization
- server.service.type: LoadBalancer

Relationships:
- Loaded by helm_release.argocd (1:1)
- Applied to ArgoCD Helm chart (1:1)

Lifecycle: Version controlled (committed to repository)

### Ansible Configuration Entities

#### Inventory: hosts.yml
Description: Ansible inventory defining connection and variables for localhost
- ansible_connection: "local"
- ansible_python_interpreter: "/opt/homebrew/bin/python3"
- kubernetes_context: "docker-desktop"
- argocd_namespace: "argocd"
- app_namespace: "belay-example-app"
- argocd_server: "localhost:4242"

Lifecycle: Version controlled, edited per environment

#### Variables: argocd-config.yml
Description: Non-sensitive ArgoCD configuration variables
- argocd_server_url: "https://localhost:4243"
- gitlab_app_name: "belay-portage-gitlab-example-app"
- gitlab_repo_url: GitLab repository URL
- gitlab_repo_path: "k8s"
- app_service_port: 4244 (configurable LoadBalancer port)
- auto_sync_enabled: true
- auto_sync_prune: true
- auto_sync_self_heal: true

Lifecycle: Version controlled, customizable per deployment

#### Variables: vault.yml
Description: Encrypted sensitive configuration (ansible-vault)
- argocd_admin_password: Secure admin password (encrypted)

Lifecycle: Encrypted with ansible-vault, NOT in version control (.gitignored)

Relationships:
- Loaded by playbooks/argocd-setup.yml (1:1)
- Password used by roles/argocd-admin for authentication (1:1)

Security: AES256 encrypted, password required for decryption

#### Playbook: argocd-setup.yml
Description: Main orchestration playbook for ArgoCD configuration
- hosts: localhost (local connection)
- vars_files: argocd-config.yml, vault.yml
- pre_tasks: 8 verification tasks
- roles: argocd-admin (14 tasks), argocd-apps (19 tasks)
- post_tasks: 8 validation tasks

Relationships:
- Executes roles/argocd-admin (1:1)
- Executes roles/argocd-apps (1:1)
- Loads variables from config files (1:N)

#### Role: argocd-admin
Description: Manages ArgoCD admin password rotation
Tasks (14):
1. Retrieve auto-generated password from argocd-initial-admin-secret
2. Extract password with base64 decoding
3. Verify password format and length
4. Check argocd CLI availability
5. Assert CLI is installed
6. Login to ArgoCD with initial password
7. Display login status (masked)
8. Update admin password from vault
9. Display update status
10. Verify new password by re-login
11. Confirm new password active
12. Get ArgoCD version
13. Display version information
14. Completion message

Relationships:
- Reads Secret/argocd-initial-admin-secret (1:1) [ephemeral]
- Updates Secret/argocd-secret admin.password field (1:1)
- Uses argocd CLI for authentication (N:1)

Security: All password operations use no_log: true

#### Role: argocd-apps
Description: Manages ArgoCD Application lifecycle
Tasks (19):
1. Display application configuration
2. Render manifest from Jinja2 template
3. Display manifest location
4. Validate manifest with kubectl dry-run
5. Display validation result
6. Check if application already exists
7. Display existing status
8. Create or update Application CRD
9. Display creation result
10. Wait for application creation (retry loop)
11. Get sync status via argocd CLI
12. Parse sync status JSON
13. Display sync and health status
14. Trigger initial sync if OutOfSync
15. Display sync trigger result
16. Clean up temporary manifest
17. Display completion message

Relationships:
- Creates Application CRD in argocd namespace (1:1)
- Uses template gitlab-app.yml.j2 (1:1)
- Applies to kubernetes.core.k8s module (N:1)

Lifecycle: Idempotent (handles create and update)

#### Template: gitlab-app.yml.j2
Description: Jinja2 template for ArgoCD Application CRD
- apiVersion: argoproj.io/v1alpha1
- kind: Application
- spec.source: GitLab repository, path, branch
- spec.destination: belay-example-app namespace
- spec.syncPolicy: automated with prune, selfHeal
- spec.syncPolicy.retry: 5 retries, exponential backoff

Relationships:
- Rendered by roles/argocd-apps (1:1)
- Variables injected from argocd-config.yml (N:1)

---

## F. Design Decisions

### 1. Terraform/Ansible Architecture Split

**Decision**: Separate infrastructure (Terraform) from configuration (Ansible)

**Context**:
- Initial design had Terraform managing both ArgoCD installation AND applications
- Security concern: admin passwords stored in Terraform state
- Flexibility concern: application updates require Terraform re-apply
- Best practice: Terraform for immutable infrastructure, Ansible for mutable configuration

**Benefits**:
- **Security**: Passwords encrypted with ansible-vault, never in Terraform state
- **Separation of concerns**: Infrastructure changes don't affect application config
- **Flexibility**: Update ArgoCD applications without touching infrastructure
- **Best practices**: Each tool used for its intended purpose
- **Drift management**: Ansible can reconcile configuration changes

**Trade-offs**:
- Additional complexity: two tools instead of one
- Requires Ansible knowledge in addition to Terraform
- Two-step deployment process

**Alternative considered**: Terraform-only approach with password in tfvars
- Rejected: Password still stored in state file, less secure

### 2. Docker Desktop Kubernetes Target

**Decision**: Target Docker Desktop Kubernetes for local development

**Context**:
- Need for local testing environment before cloud deployment
- Docker Desktop provides single-node Kubernetes cluster
- LoadBalancer service type supported out-of-the-box
- Simplifies setup compared to minikube or kind

**Benefits**:
- **Ease of setup**: One-click Kubernetes enablement in Docker Desktop
- **LoadBalancer support**: Native support without MetalLB or similar
- **Developer familiarity**: Docker Desktop widely used
- **Resource efficiency**: Shares resources with Docker daemon
- **Production parity**: Real Kubernetes API, not mocked

**Trade-offs**:
- Single-node cluster (no HA testing)
- Docker Desktop resource limits
- macOS/Windows only (Linux users need alternatives)

**Alternative considered**: minikube
- Rejected: Requires additional LoadBalancer setup (minikube tunnel)

### 3. Auto-Generated Admin Password

**Decision**: Let ArgoCD auto-generate admin password on install

**Context**:
- Originally had hardcoded password in argocd-values.yaml
- Security risk: password in Git history and Terraform state
- Need for secure default without user input

**Benefits**:
- **Security**: Unique password per deployment
- **No secrets in code**: Password never stored in Git or Terraform files
- **Terraform simplicity**: No password variable needed
- **Ansible handoff**: Ansible retrieves and rotates password

**Trade-offs**:
- Requires retrieval step before Ansible configuration
- Password stored in K8s secret (acceptable for local dev)

**Alternative considered**: User-provided password via tfvars
- Rejected: Still stored in Terraform state, user must remember it

### 4. LoadBalancer Service Type

**Decision**: Default to LoadBalancer service type for ArgoCD server

**Context**:
- Docker Desktop supports LoadBalancer natively
- Simplifies access (http://localhost vs port-forward)
- Production-like configuration

**Benefits**:
- **Simplicity**: Direct access without kubectl port-forward
- **Production parity**: Same service type as cloud deployments
- **Stability**: No need to maintain port-forward process
- **URL consistency**: http://localhost always works

**Trade-offs**:
- Docker Desktop specific (other local K8s need port-forward)
- Exposed on host network (acceptable for local dev)

**Alternative considered**: ClusterIP with port-forward instructions
- Rejected: Extra step for users, less convenient

### 5. Parameterization via Variables

**Decision**: All hardcoded values moved to variables with defaults

**Context**:
- Original config had hardcoded kubernetes context, paths, versions
- Inflexible for different environments or customization
- Terraform best practice: parameterize all configuration

**Benefits**:
- **Flexibility**: Users can override defaults via tfvars
- **Reusability**: Same config works for minikube, kind, etc.
- **Upgrades**: Chart version easily updated
- **Testing**: Different namespaces for isolation

**Trade-offs**:
- More files to understand (variables.tf, tfvars)
- Slightly more complex than single hardcoded file

**Alternative considered**: Keep hardcoded values
- Rejected: Inflexible, not Terraform best practice

### 6. Single Namespace for Applications

**Decision**: Create one application namespace (belay-example-app)

**Context**:
- ArgoCD can deploy to any namespace
- Initially considered multiple namespaces per app
- Simplicity for demo/local development

**Benefits**:
- **Simplicity**: Single namespace easier to understand
- **Resource efficiency**: Less overhead than multiple namespaces
- **Sufficient for demo**: Demonstrates ArgoCD functionality

**Trade-offs**:
- Multi-tenant scenarios require additional namespaces
- Production would likely use namespace-per-app

**Alternative considered**: Namespace-per-application
- Deferred: Can be added via Ansible later

### 7. Helm Chart Installation Method

**Decision**: Use Helm provider instead of kubectl apply

**Context**:
- ArgoCD can be installed via manifests or Helm
- Helm provides versioning and upgrade path
- Terraform has official Helm provider

**Benefits**:
- **Versioning**: Pin to specific chart version (7.6.8)
- **Upgrades**: `terraform apply` with new version
- **Customization**: Override values via argocd-values.yaml
- **Community support**: Official ArgoCD Helm chart

**Trade-offs**:
- Requires Helm repository setup (helm repo add)
- Abstraction layer over raw K8s manifests

**Alternative considered**: kubectl apply with ArgoCD manifests
- Rejected: Manual version management, harder upgrades

### 8. Comprehensive Outputs

**Decision**: Provide 7 detailed outputs with access instructions

**Context**:
- Users unfamiliar with ArgoCD need guidance
- Terraform outputs ideal for post-deployment info
- Reduces need for separate documentation

**Benefits**:
- **Self-documenting**: `terraform output` shows how to proceed
- **Cross-platform**: Linux/macOS and Windows commands
- **Copy-paste ready**: Exact commands for access
- **Ansible handoff**: Clear next steps documented

**Trade-offs**:
- Verbose output (but well-formatted)
- Maintenance burden (keep commands accurate)

**Alternative considered**: Minimal outputs (just URLs)
- Rejected: Users would need to search docs for commands

---

## G. Security Architecture

### Password Management Lifecycle

```
┌──────────────────────────────────────────────────────────────────────┐
│  1. Terraform Apply                                                  │
│     └─▶ ArgoCD Helm chart installed                                 │
│         └─▶ argocd-initial-admin-secret created (auto-generated)    │
│             └─▶ Password: Random 16-char alphanumeric               │
└──────────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│  2. Terraform Output                                                 │
│     └─▶ argocd_initial_password output provides kubectl command     │
│         └─▶ Retrieves password from K8s secret                      │
│             └─▶ Decoded from base64                                 │
└──────────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│  3. Ansible Retrieval                                                │
│     └─▶ Ansible task: kubectl get secret argocd-initial-admin...    │
│         └─▶ Stores in ansible variable: argocd_initial_pwd          │
└──────────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│  4. Ansible Password Rotation                                        │
│     └─▶ Ansible task: argocd account update-password                │
│         ├─▶ Old password: {{ argocd_initial_pwd }}                  │
│         └─▶ New password: {{ vault_argocd_admin_password }}         │
│             └─▶ Encrypted with ansible-vault                        │
└──────────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│  5. Secret Update                                                    │
│     └─▶ ArgoCD updates argocd-secret ConfigMap                      │
│         ├─▶ admin.password: <new-bcrypt-hash>                       │
│         └─▶ argocd-initial-admin-secret DELETED                     │
└──────────────────────────────────────────────────────────────────────┘
```

**Security Controls**:
1. **Auto-generation**: Unique password per deployment (no reuse)
2. **Ephemeral initial secret**: Deleted after rotation
3. **Bcrypt hashing**: Stored as hash in argocd-secret
4. **Ansible vault**: New password encrypted at rest
5. **No Terraform state**: Password never in terraform.tfstate

### Secrets Handling

#### Secrets Stored in Kubernetes
- `argocd-initial-admin-secret`: Auto-generated password (ephemeral)
- `argocd-secret`: Admin password hash, session keys (persistent)
- `argocd-tls-certs`: TLS certificates for Git repos (if needed)

#### Secrets Managed by Ansible
- Admin password: Encrypted with ansible-vault
- Git repository tokens: Encrypted with ansible-vault
- External SSO credentials: Encrypted with ansible-vault

#### Secrets NOT in Terraform
- ✅ No passwords in Terraform files
- ✅ No passwords in Terraform state
- ✅ No passwords in Git history (for new deployments)

### Network Security

**Encryption**:
- ArgoCD UI: Self-signed TLS certificates (acceptable for local dev)
- K8s API: TLS via service account token
- Git repositories: HTTPS (port 443)

**Access Control**:
- ArgoCD RBAC: Role-based access control for users
- K8s RBAC: Service accounts with least-privilege permissions
- Namespace isolation: argocd and belay-example-app separated

**Exposure**:
- LoadBalancer: Exposes ArgoCD on localhost only (Docker Desktop)
- No external ingress (local development only)
- Production: Would use Ingress with TLS and authentication

### RBAC Model

```
ServiceAccount: argocd-server
  └─▶ Role: argocd-server (namespace: argocd)
       └─▶ Rules:
            - apiGroups: ["argoproj.io"]
              resources: ["applications", "appprojects"]
              verbs: ["get", "list", "watch"]

ServiceAccount: argocd-application-controller
  └─▶ ClusterRole: argocd-application-controller
       └─▶ Rules:
            - apiGroups: ["*"]
              resources: ["*"]
              verbs: ["*"]
            (Full cluster access for app deployment)

ServiceAccount: argocd-repo-server
  └─▶ Role: argocd-repo-server (namespace: argocd)
       └─▶ Rules:
            - apiGroups: [""]
              resources: ["secrets"]
              verbs: ["get", "list", "watch"]
            (Read Git credentials only)
```

### Security Best Practices Implemented

1. **No hardcoded secrets**: All secrets auto-generated or managed by Ansible
2. **Gitignore protection**: terraform.tfvars, *.tfstate excluded
3. **Least privilege**: Service accounts have minimal required permissions
4. **Password rotation**: Ansible rotates auto-generated password
5. **Encryption at rest**: Ansible vault for configuration secrets
6. **Encryption in transit**: HTTPS for all external communication
7. **Namespace isolation**: Separate namespaces for ArgoCD and apps
8. **Audit trail**: Git history for infrastructure, Ansible logs for config

### Production Security Considerations

For production deployment, additional security measures required:
- External TLS certificates (not self-signed)
- SSO integration (OIDC, SAML, LDAP)
- Network policies to restrict pod-to-pod traffic
- Pod security policies/standards
- External secrets management (Vault, AWS Secrets Manager)
- Multi-factor authentication
- Audit logging to external SIEM
- Regular security scanning (Trivy, Snyk)

---

## H. Deployment Model

### Local Development (Current Implementation)

**Target Platform**: Docker Desktop Kubernetes (single-node)

**Deployment Flow**:
```
1. Developer Workstation
   └─▶ terraform init (downloads providers)
   └─▶ terraform apply (installs ArgoCD)
        └─▶ Helm chart pulled from argoproj.github.io
        └─▶ Deployed to local docker-desktop cluster
        └─▶ LoadBalancer service exposed at http://localhost

2. Ansible Configuration
   └─▶ ansible-playbook site.yml
        └─▶ Retrieves auto-generated password
        └─▶ Sets new admin password (from vault)
        └─▶ Creates ArgoCD applications
        └─▶ Configures Git repositories

3. ArgoCD Syncs Applications
   └─▶ Pulls manifests from Git
   └─▶ Deploys to belay-example-app namespace
   └─▶ Continuous reconciliation (every 3 minutes)
```

**Resource Requirements**:
- CPU: 2+ cores recommended
- Memory: 4GB+ allocated to Docker Desktop
- Disk: 20GB+ free space
- Network: Internet access for Helm chart and Git repos

**Limitations**:
- Single-node cluster (no HA)
- LoadBalancer requires Docker Desktop (minikube/kind need alternatives)
- Local storage only (no persistent volumes)
- Self-signed TLS certificates

### Production Deployment Considerations

**Cloud Kubernetes (EKS/GKE/AKS)**:
- Multi-node cluster with node auto-scaling
- External LoadBalancer (cloud provider managed)
- Persistent volumes for Redis (optional)
- External certificate management (cert-manager)
- Ingress controller with TLS termination
- Monitoring and alerting (Prometheus/Grafana)
- Backup and disaster recovery

**High Availability**:
- argocd-server: 3+ replicas behind load balancer
- argocd-repo-server: 3+ replicas for caching
- argocd-application-controller: Active/standby with leader election
- argocd-redis: Redis Sentinel or Redis Cluster

**Scalability**:
- Horizontal scaling: Increase replicas for server and repo-server
- Vertical scaling: Increase CPU/memory for application-controller
- Sharding: Split applications across multiple controllers

**Disaster Recovery**:
- Backup ArgoCD CRDs (Application, AppProject, Repository)
- Backup Secrets (encrypted)
- Git as source of truth (manifests recoverable)
- Terraform state backup (S3 backend recommended)

---

## I. Integration Points

### ArgoCD ↔ Git Repositories

**Protocol**: HTTPS or SSH
**Direction**: ArgoCD → Git (pull only)
**Frequency**: Every 3 minutes (default), configurable

**Contract**:
- **Input**: Git repository URL, branch/tag/commit, path to manifests
- **Output**: Raw Kubernetes YAML/Helm/Kustomize manifests
- **Authentication**: Token (HTTPS) or SSH key
- **Error handling**: Retry on failure, error displayed in UI

**SLA**: N/A (best effort for local dev)

**Failure Handling**:
- Network failure: Retry with exponential backoff
- Authentication failure: Application marked as "Unknown" health
- Manifest parse error: Sync fails with error details in UI

### ArgoCD ↔ Kubernetes API

**Protocol**: HTTPS with service account token
**Direction**: Bidirectional (ArgoCD reads and writes)
**Frequency**: Continuous (watch API for changes)

**Contract**:
- **Create/Update**: Apply K8s manifests from Git
- **Read**: Get current state of deployed resources
- **Delete**: Prune resources not in Git (if enabled)
- **Watch**: Monitor resource health and status

**SLA**: N/A (local cluster)

**Failure Handling**:
- API server unavailable: Queue sync operations, retry
- Permission denied: Display RBAC error in UI
- Resource conflict: Sync fails with conflict details

### ArgoCD ↔ Helm Repository

**Protocol**: HTTPS
**Direction**: ArgoCD → Helm repo (pull only)
**Frequency**: On-demand (when Helm chart referenced)

**Contract**:
- **Input**: Helm chart name, version, repository URL
- **Output**: Rendered Kubernetes manifests
- **Authentication**: Optional (public charts)
- **Error handling**: Chart fetch failure displayed in UI

**Failure Handling**:
- Chart not found: Sync fails with "chart not found" error
- Network failure: Retry with backoff
- Values parse error: Sync fails with validation error

### Terraform ↔ Helm Repository

**Protocol**: HTTPS
**Direction**: Terraform → Helm repo (pull only)
**Frequency**: On terraform apply/plan

**Contract**:
- **Input**: Chart name ("argo-cd"), version ("7.6.8")
- **Output**: Helm chart with all K8s manifests
- **Authentication**: None (public chart)
- **Error handling**: Terraform apply fails with error message

**Failure Handling**:
- Repository not added: Error "no cached repo found"
- Chart version not found: Error "chart version not found"
- Network failure: Terraform apply fails, user must retry

### Ansible ↔ ArgoCD API

**Protocol**: gRPC over HTTPS
**Direction**: Ansible → ArgoCD (read/write)
**Frequency**: On ansible-playbook execution

**Contract**:
- **Login**: POST /api/v1/session (username, password)
- **Update password**: PUT /api/v1/account/password
- **Create application**: POST /api/v1/applications
- **Add repository**: POST /api/v1/repositories

**SLA**: N/A (local dev)

**Failure Handling**:
- Authentication failure: Ansible task fails, playbook stops
- Application already exists: Ansible updates existing
- Repository already exists: Ansible skips or updates

### Ansible ↔ Kubernetes API

**Protocol**: HTTPS (kubectl)
**Direction**: Ansible → K8s (read only for password retrieval)
**Frequency**: Once per playbook run

**Contract**:
- **Get secret**: kubectl get secret argocd-initial-admin-secret
- **Output**: Base64-encoded password

**Failure Handling**:
- Secret not found: Ansible task fails (ArgoCD not deployed)
- Permission denied: Ansible task fails (kubeconfig issue)

---

## J. Technology Stack

### Infrastructure Layer
- **Terraform**: v1.11.2 (infrastructure as code)
- **Helm**: v3.x (Kubernetes package manager)
- **Kubernetes**: v1.34.1 (container orchestration)
- **Docker Desktop**: Latest (local K8s cluster)

### Configuration Layer
- **Ansible**: v2.x (configuration management)
- **Ansible Vault**: Built-in (secrets encryption)

### ArgoCD Stack
- **ArgoCD**: v7.6.8 (GitOps continuous delivery)
- **Redis**: v7.x (caching layer)
- **Dex**: v2.x (OIDC/SSO authentication)
- **Go**: Backend language (argocd binaries)
- **React**: Frontend framework (ArgoCD UI)

### Supporting Tools
- **kubectl**: v1.34.1 (Kubernetes CLI)
- **argocd CLI**: v2.x (ArgoCD command-line)
- **Git**: v2.x (version control)

---

## K. Operational Runbooks

### Daily Operations

**Check ArgoCD Health**:
```bash
# All pods running
kubectl get pods -n argocd

# Expected: 8/8 pods in Running state
# - argocd-application-controller-0
# - argocd-applicationset-controller-*
# - argocd-dex-server-*
# - argocd-notifications-controller-*
# - argocd-redis-*
# - argocd-repo-server-*
# - argocd-server-*
# - argocd-server-ext-*

# Check application sync status
kubectl get applications -n argocd

# Expected: All apps "Synced" and "Healthy"
```

**View Application Sync Logs**:
```bash
# Application controller logs (reconciliation)
kubectl logs -n argocd deployment/argocd-application-controller -f

# Repo server logs (manifest generation)
kubectl logs -n argocd deployment/argocd-repo-server -f

# Server logs (UI/API access)
kubectl logs -n argocd deployment/argocd-server -f
```

### Troubleshooting

**Issue: ArgoCD UI Not Accessible**
```bash
# Check service status
kubectl get svc -n argocd argocd-server

# Expected: TYPE=LoadBalancer, EXTERNAL-IP=localhost

# Check server pod
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server

# If pending/error, describe pod
kubectl describe pod <pod-name> -n argocd

# Fallback: Use port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

**Issue: Application Not Syncing**
```bash
# Check application status
kubectl get application <app-name> -n argocd -o yaml

# Look for:
# - status.sync.status: OutOfSync/Synced
# - status.health.status: Healthy/Degraded
# - status.conditions: Error messages

# Force sync via CLI
argocd app sync <app-name>

# Check repo-server logs for errors
kubectl logs -n argocd deployment/argocd-repo-server | grep ERROR
```

**Issue: Authentication Failed**
```bash
# Check admin secret exists
kubectl get secret -n argocd argocd-secret

# Retrieve current admin password (if initial secret still exists)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Reset admin password via kubectl
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {"admin.password": "<bcrypt-hash>"}}'

# Generate bcrypt hash
htpasswd -bnBC 10 "" <new-password> | tr -d ':\n'
```

### Maintenance Tasks

**Upgrade ArgoCD**:
```bash
# Update chart version in variables.tf
# argocd_chart_version = "7.7.0"

# Review changes
terraform plan

# Apply upgrade
terraform apply

# Verify new version
kubectl get pods -n argocd -o jsonpath='{.items[0].spec.containers[0].image}'
```

**Backup ArgoCD Configuration**:
```bash
# Export all Application CRDs
kubectl get applications -n argocd -o yaml > argocd-applications-backup.yaml

# Export all AppProject CRDs
kubectl get appprojects -n argocd -o yaml > argocd-projects-backup.yaml

# Export Secrets (encrypted)
kubectl get secrets -n argocd -o yaml > argocd-secrets-backup.yaml

# Store securely (encrypt before committing)
ansible-vault encrypt argocd-secrets-backup.yaml
```

**Restore ArgoCD Configuration**:
```bash
# Restore Application CRDs
kubectl apply -f argocd-applications-backup.yaml

# Restore AppProject CRDs
kubectl apply -f argocd-projects-backup.yaml

# Restore Secrets (decrypt first)
ansible-vault decrypt argocd-secrets-backup.yaml
kubectl apply -f argocd-secrets-backup.yaml
```

---

## L. References

### Documentation
- ArgoCD Official Docs: https://argo-cd.readthedocs.io/
- ArgoCD Helm Chart: https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd
- Terraform Kubernetes Provider: https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs
- Terraform Helm Provider: https://registry.terraform.io/providers/hashicorp/helm/latest/docs

### Project Files
- README.md: Setup and deployment instructions
- SECURITY.md: Password management and security notes
- implementation-terraform-refactor.md: Terraform refactor implementation plan
- implementation-argocd-gitlab-app.md: Ansible configuration plan

### Related Repositories
- ArgoCD: https://github.com/argoproj/argo-cd
- Argo Helm Charts: https://github.com/argoproj/argo-helm

---

**Document Version**: 1.0
**Last Verified**: 2025-11-17 (Deployment tested and operational)
