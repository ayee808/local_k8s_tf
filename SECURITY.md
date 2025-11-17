# Security Notes

## Password Management

### Historical Issue (RESOLVED)

**Issue**: The original configuration had a hardcoded ArgoCD admin password in `argocd-values.yaml`:
```yaml
# ARGOCD admin pwd: 7Kw8MofeW15nK7uz%
```

**Resolution**: Password removed from all Terraform files. ArgoCD now auto-generates initial password.

### Current Approach

1. **Terraform** (Infrastructure Layer):
   - Does NOT manage passwords
   - ArgoCD auto-generates initial admin password on install
   - Password stored in Kubernetes secret: `argocd-initial-admin-secret`
   - Retrievable via: `terraform output argocd_initial_password`

2. **Ansible** (Configuration Layer):
   - Retrieves auto-generated password from Kubernetes
   - Sets new secure password (encrypted with ansible-vault)
   - Password never stored in Terraform state
   - See: `docs/implementation-argocd-gitlab-app.md`

### Security Benefits

✅ **No passwords in Terraform files**
✅ **No passwords in Terraform state**
✅ **No passwords in git history** (for new deployments)
✅ **Passwords encrypted with ansible-vault**
✅ **Separation of infrastructure and configuration**

## Git History Note

If you cloned this repository before the security fix, the old hardcoded password (`7Kw8MofeW15nK7uz%`) may exist in git history. This password is:

- **NOT used** in current deployments (ArgoCD generates new password)
- **Historical only** - exists in commit history but not in current files
- **Rotated** - Ansible sets new password after initial deployment

### Remediation Options

**Option 1: Rotate Password** (Recommended for most users)
- The auto-generated password is different from the old hardcoded one
- Ansible changes it to a new secure password
- No action needed - the old password is not used

**Option 2: Rewrite Git History** (Advanced)
```bash
# Remove password from all commits (WARNING: rewrites history)
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch argocd-values.yaml' \
  --prune-empty --tag-name-filter cat -- --all

# Force push to remote
git push --force --all
```

⚠️ **Warning**: Rewriting history affects all collaborators and forks.

**Option 3: Document as Known Issue**
- Add note to README that old password exists in git history
- Emphasize it's not used in current deployments
- Document password rotation via Ansible

## gitignore Protection

The following files are gitignored to prevent accidental commits of sensitive data:

- `terraform.tfvars` - User-specific variable values
- `*.tfstate` - Terraform state (may contain sensitive outputs)
- `.terraform/` - Cached provider files and modules

**Always verify before committing**:
```bash
# Check what will be committed
git status

# Verify sensitive files are ignored
git check-ignore terraform.tfvars
git check-ignore terraform.tfstate
```

## Best Practices

1. **Never commit secrets**
   - Use `terraform.tfvars.example` as template
   - Keep actual `terraform.tfvars` gitignored

2. **Rotate passwords regularly**
   - Use Ansible to update ArgoCD admin password
   - Don't reuse passwords across environments

3. **Use encryption for secrets**
   - Ansible-vault for Ansible secrets
   - Kubernetes secrets for runtime credentials

4. **Review before committing**
   ```bash
   git diff --cached  # Review staged changes
   git status         # Check for untracked files
   ```

5. **Separate infrastructure and configuration**
   - Terraform manages infrastructure only
   - Ansible manages passwords and configuration
   - Never mix the two

## Incident Response

If you accidentally commit a password:

1. **Immediately rotate** the exposed password
2. **Remove from git history** (if not pushed)
   ```bash
   git reset HEAD~1  # Undo last commit (if not pushed)
   ```
3. **If already pushed**, rewrite history or invalidate the password
4. **Audit** who may have accessed the exposed credential
5. **Update procedures** to prevent recurrence

## Contact

For security concerns, see repository maintainers.

---

**Last Updated**: 2025-11-16
**Security Review**: Terraform/Ansible password split implemented
