# Belay API → ArgoCD Integration Guide

## Overview
After Belay validates security artifacts from Portage CD, it triggers ArgoCD to sync the application deployment using ArgoCD's REST API.

**Workflow**:
```
GitLab CI → Portage CD (scans) → Belay API (validates) → ArgoCD API (sync) → Kubernetes
```

---

## Quick Start: Test ArgoCD Sync via API

### Step 1: Get Your Token
```bash
# Navigate to project directory
cd /Users/ayee/Documents/Projects/_Holomua/belay-hello-world-demo/local_k8s_tf/ansible

# View vault and copy the token
ansible-vault view vars/vault.yml | grep argocd_belay_api_token

# Or export as environment variable
export ARGOCD_TOKEN=$(ansible-vault view vars/vault.yml | grep argocd_belay_api_token | awk '{print $2}')
```

### Step 2: Test Sync with curl

**Minimal Sync (just deploy latest from main branch)**:
```bash
curl -X POST https://localhost:4243/api/v1/applications/belay-portage-gitlab-example-app/sync \
  -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
  -H "Content-Type: application/json" \
  -k \
  -d '{
    "revision": "HEAD"
  }'
```

**Full Sync (recommended - includes prune)**:
```bash
curl -X POST https://localhost:4243/api/v1/applications/belay-portage-gitlab-example-app/sync \
  -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
  -H "Content-Type: application/json" \
  -k \
  -d '{
    "revision": "HEAD",
    "prune": true,
    "dryRun": false,
    "strategy": {
      "apply": {
        "force": false
      }
    }
  }'
```

**Sync Specific Commit**:
```bash
curl -X POST https://localhost:4243/api/v1/applications/belay-portage-gitlab-example-app/sync \
  -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
  -H "Content-Type: application/json" \
  -k \
  -d '{
    "revision": "fdaabd096ca305c434ce40d3780b582e0c7f2299",
    "prune": true
  }'
```

### Step 3: Verify Sync Status

```bash
# Check sync status via API
curl https://localhost:4243/api/v1/applications/belay-portage-gitlab-example-app \
  -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
  -k | jq '.status.sync'

# Or use ArgoCD CLI
argocd app get belay-portage-gitlab-example-app --server localhost:4243 --insecure
```

### Expected Response (Success)

```json
{
  "metadata": {
    "name": "belay-portage-gitlab-example-app",
    "namespace": "argocd"
  },
  "spec": {
    "source": {
      "repoURL": "https://gitlab.com/HolomuaTech/belay-portage-gitlab-example-app.git",
      "path": "k8s",
      "targetRevision": "main"
    }
  },
  "operation": {
    "sync": {
      "revision": "HEAD",
      "prune": true
    }
  }
}
```

After a few seconds, check the operation status:
```bash
curl https://localhost:4243/api/v1/applications/belay-portage-gitlab-example-app \
  -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
  -k | jq '.status.operationState'
```

Should show:
```json
{
  "phase": "Succeeded",
  "message": "successfully synced (all tasks run)"
}
```

---

## ArgoCD Configuration

### Application Details
- **Application Name**: `belay-portage-gitlab-example-app`
- **Namespace**: `argocd`
- **Deployment Namespace**: `belay-example-app`
- **Repository**: https://gitlab.com/HolomuaTech/belay-portage-gitlab-example-app.git
- **Path**: `k8s/`
- **Branch**: `main`

### Sync Policy
- **Auto-sync**: DISABLED (requires webhook trigger)
- **Manual sync**: ALLOWED (via UI/CLI)
- **Prune**: Enabled (removes resources not in Git)
- **Retry**: 5 attempts with exponential backoff (5s to 3m)

## ArgoCD API Integration

### Authentication
**Service Account**: `belay-webhook` (dedicated, least-privilege)

**Permissions** (RBAC):
- `applications:sync` - Trigger application sync
- `applications:get` - Read application status

**Token Storage**: Ansible Vault (`ansible/vars/vault.yml`)
```yaml
argocd_belay_api_token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Get the Token**:
```bash
# View the decrypted vault to get the token
ansible-vault view ansible/vars/vault.yml | grep argocd_belay_api_token

# Or set it as an environment variable
export ARGOCD_TOKEN=$(ansible-vault view ansible/vars/vault.yml | grep argocd_belay_api_token | cut -d: -f2 | tr -d ' ')
```

### API Endpoints

**Base URL**: `https://localhost:4243` (local development)
- For production: Update to your actual ArgoCD server URL
- Example: `https://argocd.yourdomain.com`

**Key Webhook URL for Belay Integration**:
```
POST https://localhost:4243/api/v1/applications/belay-portage-gitlab-example-app/sync
```

This is the **exact endpoint** Belay API should call after security validation passes.

### Request Format

**Headers**:
```http
Authorization: Bearer <argocd_belay_api_token>
Content-Type: application/json
```

**Body (Recommended)**:
```json
{
  "revision": "HEAD",
  "prune": true,
  "dryRun": false,
  "strategy": {
    "apply": {
      "force": false
    }
  },
  "syncOptions": {
    "items": [
      "Validate=false",
      "PrunePropagationPolicy=foreground",
      "Replace=true"
    ]
  }
}
```

**Body (Minimal)**:
```json
{
  "revision": "HEAD",
  "prune": false,
  "dryRun": false
}
```

### Response Format

**Success (200 OK)**:
```json
{
  "metadata": {
    "name": "belay-portage-gitlab-example-app",
    "namespace": "argocd"
  },
  "spec": {
    "source": {
      "repoURL": "https://gitlab.com/HolomuaTech/belay-portage-gitlab-example-app.git",
      "path": "k8s",
      "targetRevision": "main"
    },
    "destination": {
      "server": "https://kubernetes.default.svc",
      "namespace": "belay-example-app"
    }
  },
  "status": {
    "sync": {
      "status": "Synced",
      "revision": "abc123def456..."
    },
    "health": {
      "status": "Healthy"
    }
  }
}
```

**Unauthorized (401)**:
```json
{
  "error": "token is invalid",
  "code": 16,
  "message": "rpc error: code = Unauthenticated desc = invalid token"
}
```

**Not Found (404)**:
```json
{
  "error": "application 'belay-portage-gitlab-example-app' not found",
  "code": 5,
  "message": "rpc error: code = NotFound desc = application 'belay-portage-gitlab-example-app' not found"
}
```

**Permission Denied (403)**:
```json
{
  "error": "permission denied",
  "code": 7,
  "message": "rpc error: code = PermissionDenied desc = permission denied: applications, sync, default/belay-portage-gitlab-example-app, sub: belay-webhook, iat: 2025-11-17T19:00:00Z"
}
```

## Testing

### Manual curl Test
```bash
# Set variables
export ARGOCD_TOKEN="<token-from-vault>"
export ARGOCD_URL="https://localhost:4243"
export APP_NAME="belay-portage-gitlab-example-app"

# Test sync endpoint
curl -X POST "${ARGOCD_URL}/api/v1/applications/${APP_NAME}/sync" \
  -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
  -H "Content-Type: application/json" \
  -k \
  -d '{
    "revision": "HEAD",
    "prune": true,
    "dryRun": false
  }'
```

### Expected Workflow Test
1. **Trigger Portage CD**: Push to GitLab → CI runs Portage scans
2. **Portage sends webhook to Belay**: POST with scan artifacts
3. **Belay validates artifacts**: Check scan results against policy
4. **If validation passes**: Belay calls ArgoCD sync API
5. **ArgoCD syncs**: Deploys latest commit to Kubernetes
6. **Verify deployment**: Check pods in `belay-example-app` namespace

## Belay API Implementation Guide

### Environment Variables for Belay

Add these to your Belay API configuration:

```bash
# ArgoCD API Configuration
ARGOCD_API_URL=https://localhost:4243
ARGOCD_API_TOKEN=<get-from-ansible-vault>
ARGOCD_APP_NAME=belay-portage-gitlab-example-app
ARGOCD_VERIFY_SSL=false  # Set to true in production with valid cert
```

### Belay Webhook Handler Pseudocode

```python
# Example: Belay API webhook handler for Portage CD
from requests import post
import os

def handle_portage_webhook(request):
    """
    Handler for Portage CD webhook after security scans complete
    """
    # 1. Parse Portage CD payload
    scan_data = request.json

    # 2. Validate security scan results
    if not validate_security_scans(scan_data):
        log.warning(f"Security validation failed: {scan_data['project']}")
        return {"status": "rejected", "reason": "Security scans failed"}

    # 3. Extract Git revision from Portage payload
    git_revision = scan_data.get('git_sha', 'HEAD')

    # 4. Trigger ArgoCD sync via API
    try:
        argocd_response = trigger_argocd_sync(
            app_name=os.getenv('ARGOCD_APP_NAME'),
            revision=git_revision
        )

        log.info(f"ArgoCD sync triggered successfully: {git_revision}")
        return {
            "status": "success",
            "argocd_operation": argocd_response
        }

    except Exception as e:
        log.error(f"Failed to trigger ArgoCD sync: {e}")
        return {"status": "error", "message": str(e)}, 500


def trigger_argocd_sync(app_name, revision='HEAD'):
    """
    Trigger ArgoCD application sync via REST API
    """
    url = f"{os.getenv('ARGOCD_API_URL')}/api/v1/applications/{app_name}/sync"

    headers = {
        'Authorization': f"Bearer {os.getenv('ARGOCD_API_TOKEN')}",
        'Content-Type': 'application/json'
    }

    payload = {
        'revision': revision,
        'prune': True,
        'dryRun': False,
        'strategy': {
            'apply': {
                'force': False
            }
        }
    }

    response = post(
        url,
        json=payload,
        headers=headers,
        verify=os.getenv('ARGOCD_VERIFY_SSL', 'false').lower() == 'true',
        timeout=30
    )

    response.raise_for_status()
    return response.json()


def validate_security_scans(scan_data):
    """
    Validate Portage CD security scan results
    Returns True if scans pass, False otherwise
    """
    # Example validation logic
    required_scans = ['sast', 'dependency', 'container']

    for scan_type in required_scans:
        if scan_type not in scan_data.get('scans', {}):
            return False

        scan_result = scan_data['scans'][scan_type]

        # Check for critical vulnerabilities
        if scan_result.get('critical_count', 0) > 0:
            return False

        # Check for high vulnerabilities above threshold
        if scan_result.get('high_count', 0) > 5:
            return False

    return True
```

### cURL Example for Belay Testing

Test the complete flow manually:

```bash
# Set your token
export ARGOCD_TOKEN=$(ansible-vault view vars/vault.yml | grep argocd_belay_api_token | awk '{print $2}')

# Simulate what Belay will do: Trigger sync after validation
curl -X POST https://localhost:4243/api/v1/applications/belay-portage-gitlab-example-app/sync \
  -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
  -H "Content-Type: application/json" \
  -k \
  -d '{
    "revision": "HEAD",
    "prune": true,
    "dryRun": false
  }' | jq .

# Check the sync completed
sleep 5
curl https://localhost:4243/api/v1/applications/belay-portage-gitlab-example-app \
  -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
  -k | jq '.status.operationState'
```

---

## Belay API Integration Checklist

### Configuration
- [ ] Add ArgoCD API endpoint to Belay configuration
  - Environment variable: `ARGOCD_API_URL=https://localhost:4243`
- [ ] Add ArgoCD API token to Belay secrets management
  - Environment variable: `ARGOCD_API_TOKEN=<from-vault>`
- [ ] Configure application name mapping
  - Map Portage project → ArgoCD application name

### Implementation
- [ ] Implement ArgoCD sync trigger in Belay webhook handler
  - Location: Belay API webhook endpoint (receives Portage payload)
  - Trigger: After successful security validation
- [ ] Add HTTP client for ArgoCD API calls
  - Handle TLS/SSL (may need `insecure` flag for localhost)
  - Handle bearer token authentication
- [ ] Implement error handling
  - Retry logic for transient failures (network, ArgoCD unavailable)
  - Alert on persistent failures (invalid token, permission denied)
  - Log all sync requests and responses

### Logging & Monitoring
- [ ] Log ArgoCD sync requests
  - Include: timestamp, application name, revision, outcome
- [ ] Log ArgoCD sync responses
  - Include: HTTP status, sync status, errors
- [ ] Create audit trail
  - Link: Portage scan → Belay validation → ArgoCD sync → deployment
- [ ] Set up alerts
  - Alert on: repeated sync failures, permission errors, token expiration

### Security
- [ ] Validate token permissions (sync + get only)
- [ ] Implement token rotation procedure
- [ ] Use TLS/SSL for ArgoCD API calls (even on localhost)
- [ ] Store token securely (not in code, not in logs)
- [ ] Restrict network access to ArgoCD API (firewall/network policies)

### Testing
- [ ] Unit test: Belay → ArgoCD API call logic
- [ ] Integration test: End-to-end Portage → Belay → ArgoCD
- [ ] Security test: Belay rejects invalid scans (no ArgoCD sync)
- [ ] Failure test: Belay handles ArgoCD API errors gracefully
- [ ] Performance test: Sync triggers complete within SLA (< 30s)

## Troubleshooting

### Issue: 401 Unauthorized
**Cause**: Invalid or expired ArgoCD API token

**Fix**:
1. Regenerate token: `./scripts/generate-argocd-token.sh`
2. Update Belay configuration with new token
3. Restart Belay API service

### Issue: 403 Permission Denied
**Cause**: Token lacks required permissions (sync or get)

**Fix**:
1. Check RBAC policy: `kubectl get configmap argocd-rbac-cm -n argocd -o yaml`
2. Verify policy includes:
   ```
   p, role:belay-webhook, applications, sync, */*, allow
   p, role:belay-webhook, applications, get, */*, allow
   g, belay-webhook, role:belay-webhook
   ```
3. If missing, re-apply RBAC configuration from implementation doc

### Issue: 404 Not Found
**Cause**: Application name mismatch or application not deployed

**Fix**:
1. Verify application exists: `argocd app list`
2. Check application name in Belay configuration matches ArgoCD
3. If missing, deploy application: `ansible-playbook ansible/playbooks/argocd-setup.yml`

### Issue: Sync triggered but deployment fails
**Cause**: Application configuration errors or Kubernetes resource issues

**Fix**:
1. Check ArgoCD application status: `argocd app get belay-portage-gitlab-example-app`
2. Check application events: `kubectl describe app belay-portage-gitlab-example-app -n argocd`
3. Check pod logs: `kubectl logs -n belay-example-app <pod-name>`
4. Verify Git repository is accessible and has valid Kubernetes manifests

### Issue: Network connection refused
**Cause**: ArgoCD server not accessible from Belay API

**Fix**:
1. Verify ArgoCD server is running: `kubectl get pods -n argocd`
2. Check service endpoint: `kubectl get svc -n argocd argocd-server`
3. Test connectivity: `curl -k https://localhost:4243/api/version`
4. Update Belay configuration with correct ArgoCD URL

## Reference

### ArgoCD API Documentation
- Official API Docs: https://argo-cd.readthedocs.io/en/stable/developer-guide/api-docs/
- Sync API: https://argo-cd.readthedocs.io/en/stable/developer-guide/api-docs/#operation/ApplicationService_Sync

### Token Management
- Generation script: `scripts/generate-argocd-token.sh`
- Storage location: `ansible/vars/vault.yml` (encrypted)
- Rotation procedure: Run generation script, update vault, restart Belay

### RBAC Configuration
- Account ConfigMap: `kubectl get cm argocd-cm -n argocd`
- RBAC ConfigMap: `kubectl get cm argocd-rbac-cm -n argocd`
- Documentation: https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/

### Implementation Tracking
- Implementation document: `docs/implementation-argocd-webhook-sync.md`
- Project overview: `README.md`
- Architecture docs: `docs/architecture.md` (if exists)

---

## Quick Reference Card

### Key Information

| Item | Value |
|------|-------|
| **ArgoCD URL** | `https://localhost:4243` |
| **Application Name** | `belay-portage-gitlab-example-app` |
| **Sync Endpoint** | `POST /api/v1/applications/belay-portage-gitlab-example-app/sync` |
| **Service Account** | `belay-webhook` |
| **Token Location** | `ansible/vars/vault.yml` (encrypted) |
| **Git Repository** | `https://gitlab.com/HolomuaTech/belay-portage-gitlab-example-app.git` |
| **Deployment Namespace** | `belay-example-app` |
| **Sync Policy** | Manual (webhook-triggered) |

### Essential Commands

```bash
# Get token from vault
ansible-vault view ansible/vars/vault.yml | grep argocd_belay_api_token

# Export token as env var
export ARGOCD_TOKEN=$(ansible-vault view ansible/vars/vault.yml | grep argocd_belay_api_token | awk '{print $2}')

# Trigger sync via API (what Belay will do)
curl -X POST https://localhost:4243/api/v1/applications/belay-portage-gitlab-example-app/sync \
  -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
  -H "Content-Type: application/json" \
  -k \
  -d '{"revision":"HEAD","prune":true,"dryRun":false}'

# Check sync status
curl https://localhost:4243/api/v1/applications/belay-portage-gitlab-example-app \
  -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
  -k | jq '.status.operationState'

# Manual sync via CLI (fallback)
argocd app sync belay-portage-gitlab-example-app --server localhost:4243 --insecure

# Check application status
argocd app get belay-portage-gitlab-example-app --server localhost:4243 --insecure

# View deployed pods
kubectl get pods -n belay-example-app
```

### For Belay Developers

**Minimal Integration** (just trigger sync):
```python
import requests

def trigger_deployment(git_sha='HEAD'):
    url = "https://localhost:4243/api/v1/applications/belay-portage-gitlab-example-app/sync"
    headers = {
        "Authorization": f"Bearer {ARGOCD_TOKEN}",
        "Content-Type": "application/json"
    }
    data = {"revision": git_sha, "prune": True}
    
    response = requests.post(url, json=data, headers=headers, verify=False)
    return response.json()
```

**What Belay Receives** (from Portage CD):
```json
{
  "project": "belay-portage-gitlab-example-app",
  "git_sha": "fdaabd096ca305c434ce40d3780b582e0c7f2299",
  "git_branch": "main",
  "scans": {
    "sast": {"status": "passed", "critical_count": 0},
    "dependency": {"status": "passed", "high_count": 2},
    "container": {"status": "passed", "critical_count": 0}
  }
}
```

**What Belay Sends** (to ArgoCD):
```bash
POST https://localhost:4243/api/v1/applications/belay-portage-gitlab-example-app/sync
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "revision": "fdaabd096ca305c434ce40d3780b582e0c7f2299",
  "prune": true,
  "dryRun": false
}
```
