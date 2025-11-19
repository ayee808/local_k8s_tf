# Belay API → ArgoCD Integration Guide

## Overview
After Belay validates security artifacts from Portage CD, it triggers ArgoCD to sync the application deployment using ArgoCD's REST API.

**Workflow**:
```
GitLab CI → Portage CD (scans) → Belay API (validates) → ArgoCD API (sync) → Kubernetes
```

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
argocd_belay_api_token: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  <encrypted-token>
```

### API Endpoint

**Base URL**: `https://localhost:4243` (local development)

**Sync Endpoint**:
```
POST /api/v1/applications/belay-portage-gitlab-example-app/sync
```

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
