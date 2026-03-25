#!/bin/bash

#############################################################################
#                                                                           #
# deleteProjectSecrets.sh : Deletes all secrets for a project from Azure    #
# Key Vault, with optional purge & retry for soft-deleted secrets.          #
#                                                                           #
#############################################################################

# Usage: ./deleteProjectSecrets.sh <vault_name> <project_name> [--purge]

VAULT_NAME="$1"
PROJECT_NAME="$2"
PURGE=false

if [[ "$3" == "--purge" ]]; then
  PURGE=true
fi

if [[ -z "$VAULT_NAME" || -z "$PROJECT_NAME" ]]; then
  echo "Usage: ./deleteProjectSecrets.sh <vault_name> <project_name> [--purge]"
  exit 1
fi

# Retry settings for purge
MAX_RETRIES=10
SLEEP_SECONDS=5

echo "🔍 Fetching secrets for project: $PROJECT_NAME from vault: $VAULT_NAME..."
[[ "$PURGE" == "true" ]] && echo "⚠️  Purge enabled: secrets will be permanently removed."

SEARCH_PATTERN=$(echo "$PROJECT_NAME" | sed 's/_/-/g')

# ===== ACTIVE SECRETS DELETION =====
secret_names=$(az keyvault secret list --vault-name "$VAULT_NAME" --query "[].name" -o tsv)

found=0
while IFS= read -r secret_name; do
  if [[ "$secret_name" == *"$SEARCH_PATTERN"* ]]; then
    found=1
    echo "🗑️  Deleting secret: $secret_name"
    az keyvault secret delete --vault-name "$VAULT_NAME" --name "$secret_name"

    if [[ "$PURGE" == "true" ]]; then
      echo "🔥 Purging deleted secret: $secret_name"

      attempt=1
      while true; do
        if az keyvault secret purge --vault-name "$VAULT_NAME" --name "$secret_name"; then
          echo "✅ Purged secret: $secret_name"
          break
        else
          if [ "$attempt" -ge "$MAX_RETRIES" ]; then
            echo "❌ Failed to purge $secret_name after $MAX_RETRIES attempts."
            break
          fi
          echo "⏳ Secret '$secret_name' still being deleted... Retrying in $SLEEP_SECONDS seconds (Attempt $attempt/$MAX_RETRIES)"
          sleep "$SLEEP_SECONDS"
          ((attempt++))
        fi
      done

    fi
  fi
done <<< "$secret_names"

if [[ $found -eq 0 ]]; then
  echo "ℹ️  No active secrets found matching pattern: $SEARCH_PATTERN"
fi

# ===== PURGE ORPHANED SOFT-DELETED SECRETS =====
if [[ "$PURGE" == "true" ]]; then
  echo "🛠️  Checking for soft-deleted secrets to purge..."

  deleted_secrets=$(az keyvault secret list-deleted --vault-name "$VAULT_NAME" --query "[].name" -o tsv)

  while IFS= read -r deleted_secret; do
    if [[ "$deleted_secret" == *"$SEARCH_PATTERN"* ]]; then
      echo "🔥 Purging soft-deleted secret: $deleted_secret"

      attempt=1
      while true; do
        if az keyvault secret purge --vault-name "$VAULT_NAME" --name "$deleted_secret"; then
          echo "✅ Purged soft-deleted secret: $deleted_secret"
          break
        else
          if [ "$attempt" -ge "$MAX_RETRIES" ]; then
            echo "❌ Failed to purge $deleted_secret after $MAX_RETRIES attempts."
            break
          fi
          echo "⏳ Soft-deleted secret '$deleted_secret' still being deleted... Retrying in $SLEEP_SECONDS seconds (Attempt $attempt/$MAX_RETRIES)"
          sleep "$SLEEP_SECONDS"
          ((attempt++))
        fi
      done

    fi
  done <<< "$deleted_secrets"

  echo "✅ Purging of soft-deleted secrets complete."
fi

echo "✅ Completed cleanup for project: $PROJECT_NAME"
