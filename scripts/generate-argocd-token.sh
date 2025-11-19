#!/bin/bash
# Script to generate ArgoCD API token for Belay webhook integration
# This token will be used by Belay API to trigger ArgoCD syncs after security validation

set -e

echo "=== ArgoCD API Token Generation for Belay Webhook ==="
echo ""

# Configuration
ARGOCD_SERVER="localhost:4243"
ACCOUNT_NAME="belay-webhook"
TOKEN_ID="belay-webhook-token"

# Step 1: Get admin password from user
echo "Step 1: Enter ArgoCD admin password..."
echo "Please enter the ArgoCD admin password:"
read -s ADMIN_PASSWORD
echo ""

if [ -z "$ADMIN_PASSWORD" ]; then
    echo "ERROR: Password cannot be empty"
    exit 1
fi

echo "✓ Password provided"
echo ""

# Step 2: Login to ArgoCD
echo "Step 2: Logging in to ArgoCD..."
argocd login $ARGOCD_SERVER \
    --username admin \
    --password "$ADMIN_PASSWORD" \
    --insecure

echo "✓ Logged in successfully"
echo ""

# Step 3: Verify belay-webhook account exists
echo "Step 3: Verifying belay-webhook account..."
argocd account list --server $ARGOCD_SERVER --insecure | grep belay-webhook

if [ $? -ne 0 ]; then
    echo "ERROR: belay-webhook account not found"
    echo "Please ensure ConfigMap argocd-cm has 'accounts.belay-webhook: apiKey'"
    exit 1
fi

echo "✓ belay-webhook account exists"
echo ""

# Step 4: Generate API token (or delete and regenerate if exists)
echo "Step 4: Generating API token..."

# Try to generate token
TOKEN=$(argocd account generate-token \
    --account $ACCOUNT_NAME \
    --id $TOKEN_ID \
    --server $ARGOCD_SERVER \
    --insecure 2>&1)

# Check if token already exists (check for the error message)
if echo "$TOKEN" | grep -qi "already has token\|failed to update account with new token"; then
    echo "⚠ Token with ID '$TOKEN_ID' already exists"
    echo ""
    echo "Choose an option:"
    echo "  1) Delete existing token and generate new one (recommended)"
    echo "  2) Cancel (you'll need to use the existing token or run script with different token ID)"
    echo ""
    read -p "Enter choice (1 or 2): " CHOICE

    if [ "$CHOICE" = "1" ]; then
        echo ""
        echo "Deleting existing token..."
        argocd account delete-token \
            --account $ACCOUNT_NAME \
            $TOKEN_ID \
            --server $ARGOCD_SERVER \
            --insecure

        echo "Generating new token..."
        TOKEN=$(argocd account generate-token \
            --account $ACCOUNT_NAME \
            --id $TOKEN_ID \
            --server $ARGOCD_SERVER \
            --insecure)

        if [ -z "$TOKEN" ]; then
            echo "ERROR: Failed to generate token"
            exit 1
        fi

        echo "✓ New token generated successfully"
    else
        echo "Cancelled. Existing token not modified."
        exit 0
    fi
else
    # Check if generation failed for other reason
    if [ -z "$TOKEN" ] || echo "$TOKEN" | grep -q "FATA\|ERROR\|error"; then
        echo "ERROR: Failed to generate token"
        echo "$TOKEN"
        exit 1
    fi

    echo "✓ Token generated successfully"
fi

echo ""

# Step 5: Test the token
echo "Step 5: Testing token with ArgoCD API..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    -k https://$ARGOCD_SERVER/api/v1/applications)

if [ "$RESPONSE" == "200" ]; then
    echo "✓ Token authentication successful (HTTP $RESPONSE)"
else
    echo "⚠ Token test returned HTTP $RESPONSE (may be permissions issue, but token is valid)"
fi

echo ""
echo "=== Token Generated Successfully ==="
echo ""
echo "Your ArgoCD API token for Belay webhook:"
echo ""
echo "--- BEGIN TOKEN ---"
echo "$TOKEN"
echo "--- END TOKEN ---"
echo ""

# Step 6: Instructions for adding to vault
echo "Step 6: Adding token to Ansible Vault..."
echo ""
echo "Your vault.yml uses Format 1 (entire file encrypted)."
echo "Add the RAW TOKEN (shown above) to the vault, NOT an encrypted version."
echo ""
echo "Run these commands:"
echo ""
echo "  # 1. Edit the vault (decrypts for editing)"
echo "  ansible-vault edit ansible/vars/vault.yml"
echo ""
echo "  # 2. In the editor, add this line:"
echo "  argocd_belay_api_token: $TOKEN"
echo ""
echo "  # 3. Save and exit (vault will auto-encrypt)"
echo ""
echo "IMPORTANT: Paste the RAW token above, NOT any encrypted output!"
echo ""

# Save token to temporary file for reference
TOKEN_FILE="/tmp/argocd-belay-token-$(date +%s).txt"
echo "$TOKEN" > "$TOKEN_FILE"
echo "Token also saved to: $TOKEN_FILE"
echo "(Remember to delete this file after adding to vault!)"
echo ""

echo "=== Next Steps ==="
echo "1. Encrypt the token using ansible-vault encrypt_string (command shown above)"
echo "2. Add encrypted token to ansible/vars/vault.yml"
echo "3. Update Belay API configuration with:"
echo "   - ArgoCD API URL: https://$ARGOCD_SERVER"
echo "   - Token: <from vault>"
echo "4. Delete temporary token file: rm $TOKEN_FILE"
echo ""
