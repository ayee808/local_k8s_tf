# Manual Steps Guide: ArgoCD Webhook-Based Sync Configuration

## Overview
This guide walks you through the remaining manual steps to complete the ArgoCD webhook-based sync configuration.

---

## Step 1: Generate ArgoCD API Token

### Option A: Using the Helper Script (Recommended)

The helper script automates token generation but requires the ArgoCD admin password from Ansible Vault.

```bash
cd /Users/ayee/Documents/Projects/_Holomua/belay-hello-world-demo/local_k8s_tf

# Run the script
./scripts/generate-argocd-token.sh

# You'll be prompted for the vault password
# The script will:
# 1. Retrieve admin password from vault
# 2. Login to ArgoCD
# 3. Generate token for belay-webhook account
# 4. Test the token
# 5. Provide ansible-vault encrypt command
```

### Option B: Manual Token Generation

If the script doesn't work, follow these manual steps:

#### 1. Get the ArgoCD Admin Password

The password is stored in Ansible Vault. You have two options:

**Option B1: View the entire vault file**
```bash
cd /Users/ayee/Documents/Projects/_Holomua/belay-hello-world-demo/local_k8s_tf

# View the vault (you'll be prompted for vault password)
ansible-vault view ansible/vars/vault.yml

# Look for the 'argocd_admin_password' variable
```

**Option B2: Extract just the password**
```bash
cd /Users/ayee/Documents/Projects/_Holomua/belay-hello-world-demo/local_k8s_tf

# This command will prompt for vault password and show just the admin password
ansible-vault view ansible/vars/vault.yml | grep -A1 'argocd_admin_password' | tail -n1
```

#### 2. Login to ArgoCD

```bash
# Replace <PASSWORD> with the password from step 1
argocd login localhost:4243 \
  --username admin \
  --password '<PASSWORD>' \
  --insecure
```

Expected output:
```
'admin:login' logged in successfully
Context 'localhost:4243' updated
```

#### 3. Verify the belay-webhook Account Exists

```bash
argocd account list --server localhost:4243 --insecure
```

Expected output:
```
NAME            ENABLED  CAPABILITIES
admin           true     login
belay-webhook   true     apiKey
```

#### 4. Generate the API Token

**First Time (No Token Exists)**:
```bash
argocd account generate-token \
  --account belay-webhook \
  --id belay-webhook-token \
  --server localhost:4243 \
  --insecure
```

This will output a long JWT token string like:
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJhcmdvY2QiLCJzdWIiOiJiZWxheS13ZWJob29rOmFwaUtleSIsIm5iZiI6MTczMTg5...
```

**IMPORTANT**: Copy this token - you'll need it for the next steps!

**If Token Already Exists (Regeneration)**:

If you see this error:
```
FATA[0000] rpc error: code = Unknown desc = failed to update account with new token: account already has token with id 'belay-webhook-token'
```

You have two options:

**Option 1: Delete and regenerate** (recommended if updating vault):
```bash
# Delete the existing token (note: token ID is a positional argument, not --id flag)
argocd account delete-token \
  --account belay-webhook \
  belay-webhook-token \
  --server localhost:4243 \
  --insecure

# Generate a new token
argocd account generate-token \
  --account belay-webhook \
  --id belay-webhook-token \
  --server localhost:4243 \
  --insecure
```

**Option 2: Use the existing token** (if already in vault and working):
```bash
# View the token from vault
ansible-vault view ansible/vars/vault.yml | grep argocd_belay_api_token

# If the token is already there and working, skip to Step 2 (Deploy Configuration)
```

#### 5. Test the Token

```bash
# Replace <TOKEN> with the token from step 4
export ARGOCD_TOKEN='<TOKEN>'

# Test authentication
curl -k -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
  https://localhost:4243/api/v1/applications
```

Expected output: JSON array of applications (should see belay-portage-gitlab-example-app)

If you get a 401 error, the token is invalid. If you get a 403 error, check RBAC permissions.

#### 6. Add Token to Ansible Vault

Your vault file uses **Format 1** (entire file encrypted), so you need to add the **raw token** (not encrypted).

**IMPORTANT**: Save the raw token from Step 4 - you'll need it in the next step!

```bash
cd /Users/ayee/Documents/Projects/_Holomua/belay-hello-world-demo/local_k8s_tf

# Edit the vault (this decrypts it for editing)
ansible-vault edit ansible/vars/vault.yml
```

When prompted, enter your vault password. The editor will open showing the **decrypted** contents:

```yaml
---
argocd_admin_password: <existing-password>
```

**Add the raw token as plain text** (the JWT token from Step 4, NOT the encrypted version):

```yaml
---
argocd_admin_password: <existing-password>
argocd_belay_api_token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJhcmdvY2QiLCJzdWIiOiJiZWxheS13ZWJob29rOmFwaUtleSIsIm5iZiI6MTczMTg5...
```

Save and exit:
- **Vim**: Press `Esc`, type `:wq`, press Enter
- **Nano**: Press `Ctrl+X`, then `Y`, then Enter

Ansible will automatically re-encrypt the entire file when you save.

**Important Notes**:
- ❌ **DON'T** paste the `!vault |` encrypted block - that's for a different vault format
- ✅ **DO** paste the actual JWT token (the long string starting with `eyJ...`)
- ❌ **DON'T** run `ansible-vault encrypt_string` - not needed for this vault format
- ✅ **DO** just paste the raw token into the decrypted vault file

#### 7. Verify Token is Stored Correctly

```bash
# View the vault to confirm token was added
ansible-vault view ansible/vars/vault.yml

# You should see:
# ---
# argocd_admin_password: ...
# argocd_belay_api_token: eyJhbGci...
```

The token should be visible as plain text when decrypted. The file itself is encrypted on disk.

---

## Step 2: Deploy Configuration Changes via Ansible

Now that the token is stored in the vault, deploy the ArgoCD application configuration with auto-sync disabled.

```bash
cd /Users/ayee/Documents/Projects/_Holomua/belay-hello-world-demo/local_k8s_tf

# Run the Ansible playbook
ansible-playbook ansible/playbooks/argocd-setup.yml --ask-vault-pass
```

You'll be prompted for the vault password. Expected output:

```
PLAY [ArgoCD Setup Playbook] ***************************************************

TASK [Gathering Facts] *********************************************************
ok: [localhost]

...

TASK [argocd-apps : Apply ArgoCD Application manifest] ************************
changed: [localhost] => (item=belay-portage-gitlab-example-app)

PLAY RECAP *********************************************************************
localhost                  : ok=19   changed=1    unreachable=0    failed=0
```

Look for the "changed" status on the "Apply ArgoCD Application manifest" task.

### Verify the Deployment

```bash
# Check that auto-sync is disabled (should return empty - no "automated" field)
kubectl get app -n argocd belay-portage-gitlab-example-app -o jsonpath='{.spec.syncPolicy}' | jq .

# Check application status
argocd app get belay-portage-gitlab-example-app --server localhost:4243 --insecure
```

Expected output:
```
Name:               belay-portage-gitlab-example-app
...
Sync Policy:        <none>
Sync Status:        Synced
Health Status:      Healthy
```

Note: "Sync Policy: <none>" means auto-sync is disabled ✅

---

## Step 3: Validate Auto-Sync is Disabled

Test that the application no longer automatically syncs when Git changes are made.

### Test 1: Verify No Auto-Sync on Git Change

1. **Make a test change in the GitLab repository**:
   - Go to: https://gitlab.com/HolomuaTech/belay-portage-gitlab-example-app
   - Edit a file in the `k8s/` directory (e.g., add a comment to a ConfigMap)
   - Commit the change

2. **Wait 5+ minutes** (ArgoCD refresh interval is 60 seconds, so wait several cycles)

3. **Check ArgoCD application status**:
   ```bash
   argocd app get belay-portage-gitlab-example-app --server localhost:4243 --insecure
   ```

4. **Expected Result**:
   - Sync Status should show: **OutOfSync** (detected the Git change)
   - But the application should **NOT** auto-deploy
   - Pods in `belay-example-app` namespace should **NOT** have restarted

   ✅ **SUCCESS**: Auto-sync is disabled if ArgoCD shows OutOfSync but doesn't deploy

### Test 2: Verify Manual Sync Still Works

```bash
# Manually trigger sync via CLI
argocd app sync belay-portage-gitlab-example-app --server localhost:4243 --insecure

# Check sync completed
argocd app get belay-portage-gitlab-example-app --server localhost:4243 --insecure
```

Expected:
- Sync Status: **Synced** (should change from OutOfSync to Synced)
- Health Status: **Healthy**
- Pods in `belay-example-app` namespace should have restarted (if manifest changed)

✅ **SUCCESS**: Manual sync works

### Test 3: Verify API Sync Works with Token

```bash
# Use the token you generated earlier
export ARGOCD_TOKEN='<your-token-here>'

# Trigger sync via API
curl -X POST https://localhost:4243/api/v1/applications/belay-portage-gitlab-example-app/sync \
  -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
  -H "Content-Type: application/json" \
  -k \
  -d '{
    "revision": "HEAD",
    "prune": true,
    "dryRun": false
  }'
```

Expected: JSON response with application details and sync status.

✅ **SUCCESS**: API sync works with token

---

## Step 4: Configure Belay API (Future Step)

Once all validations pass, the Belay API team needs to integrate with ArgoCD. Reference guide:

📄 **Integration Guide**: `docs/belay-argocd-integration.md`

**Belay Team Checklist**:
- [ ] Add ArgoCD API endpoint to Belay config: `https://localhost:4243`
- [ ] Add ArgoCD API token to Belay secrets (from vault: `argocd_belay_api_token`)
- [ ] Implement sync trigger in Belay webhook handler (after validation passes)
- [ ] Add error handling and retry logic
- [ ] Log all sync requests and responses
- [ ] Test end-to-end: Portage CD → Belay → ArgoCD → Kubernetes

---

## Troubleshooting

### Issue: "already has token with id 'belay-webhook-token'"
**Cause**: Token was already generated in a previous run

**Solutions**:

**Option 1: Use the automated script** (handles this automatically):
```bash
./scripts/generate-argocd-token.sh
# Script will prompt you to delete and regenerate
```

**Option 2: Manually delete and regenerate**:
```bash
# Delete existing token (token ID is positional, not --id)
argocd account delete-token --account belay-webhook belay-webhook-token --server localhost:4243 --insecure

# Generate new token
argocd account generate-token --account belay-webhook --id belay-webhook-token --server localhost:4243 --insecure
```

**Option 3: Skip if token already in vault and working**:
```bash
# Check if token is in vault
ansible-vault view ansible/vars/vault.yml | grep -A1 argocd_belay_api_token

# If token exists, proceed to Step 2 (Deploy Configuration)
```

### Issue: "no session information" error
**Solution**: Run `argocd login localhost:4243 --username admin --password '<password>' --insecure`

### Issue: "account 'belay-webhook' not found"
**Solution**:
```bash
# Verify account in ConfigMap
kubectl get configmap argocd-cm -n argocd -o jsonpath='{.data}' | grep belay-webhook

# If missing, re-apply:
kubectl patch configmap argocd-cm -n argocd --type merge \
  -p '{"data":{"accounts.belay-webhook":"apiKey"}}'
kubectl rollout restart deployment argocd-server -n argocd
```

### Issue: "permission denied" when generating token
**Solution**: Check RBAC policy:
```bash
kubectl get configmap argocd-rbac-cm -n argocd -o yaml

# Should contain:
# p, role:belay-webhook, applications, sync, */*, allow
# p, role:belay-webhook, applications, get, */*, allow
# g, belay-webhook, role:belay-webhook
```

### Issue: Ansible playbook fails
**Solution**:
1. Check vault password is correct
2. Verify you're in the correct directory
3. Check Kubernetes context: `kubectl config current-context` (should be docker-desktop)

---

## Quick Reference Commands

```bash
# Login to ArgoCD
argocd login localhost:4243 --username admin --password '<from-vault>' --insecure

# List accounts
argocd account list --server localhost:4243 --insecure

# Generate token
argocd account generate-token --account belay-webhook --id belay-webhook-token --server localhost:4243 --insecure

# Encrypt for vault
ansible-vault encrypt_string '<token>' --name 'argocd_belay_api_token'

# Edit vault
ansible-vault edit ansible/vars/vault.yml

# Deploy configuration
ansible-playbook ansible/playbooks/argocd-setup.yml --ask-vault-pass

# Check application
argocd app get belay-portage-gitlab-example-app --server localhost:4243 --insecure

# Manual sync
argocd app sync belay-portage-gitlab-example-app --server localhost:4243 --insecure

# API sync
curl -X POST https://localhost:4243/api/v1/applications/belay-portage-gitlab-example-app/sync \
  -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
  -H "Content-Type: application/json" \
  -k -d '{"revision":"HEAD","prune":true,"dryRun":false}'
```

---

## Documentation References

- **Implementation Tracking**: `docs/implementation-argocd-webhook-sync.md`
- **Belay Integration Guide**: `docs/belay-argocd-integration.md`
- **Token Generation Script**: `scripts/generate-argocd-token.sh`
- **ArgoCD API Docs**: https://argo-cd.readthedocs.io/en/stable/developer-guide/api-docs/
