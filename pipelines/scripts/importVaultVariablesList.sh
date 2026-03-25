#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

##############################################################################################################################################
# Script: importVaultVariables.sh                                                                                                            #
#                                                                                                                                            #
# Summary:                                                                                                                                   #
#   This script imports vault variables into a webMethods.io environment                                                                     #
#   from JSON configuration files. It reads keys from                                                                                        #
#   `vaultVariables_keys.txt` and imports corresponding vault variables                                                                      #
#   into the provided environment. Optionally, it synchronizes them                                                                          #
#   across referenced projects if defined in the configuration.                                                                              #
#                                                                                                                                            #
# Usage:                                                                                                                                     #
#   ./importVaultVariables.sh <LOCAL_DEV_URL> <X_INSTANCE_API_KEY> <repoName> <HOME_DIR> <synchProject>                             # Gen-2 #
#                                                                                                                                            #
# Mandatory Fields:                                                                                                                          #
#   LOCAL_DEV_URL   - Base URL of the webMethods.io tenant (e.g., http://localhost:5555)                                                     #
#   X_INSTANCE_API_KEY - API key for authentication                                                                                # Gen-2 #
#   repoName        - Repository name (folder where assets are stored)                                                                       #
#   HOME_DIR        - Base home directory path                                                                                               #
#   synchProject    - Project ID or name to sync vault variables against                                                                     #
#                                                                                                                                            #
# Example:                                                                                                                                   #
#   ./importVaultVariables.sh http://localhost:5555 your-api-key repo1 /opt/softwareag true                                          # Gen-2 #
#                                                                                                                                            #
##############################################################################################################################################

# Debug echo function
function echod() {
  echo "[DEBUG] $*"
}

# Import vault variables from JSON files listed in vaultVariables_keys.txt
function importVaultVariables() {
  local LOCAL_DEV_URL=$1
  local X_INSTANCE_API_KEY=$2 # Gen-2: Changed from admin_user
  local repoName=$3
  local HOME_DIR=$4
  local synchProject=$5

  local vault_dir="${HOME_DIR}/${repoName}/assets/projectConfigs/vaultVariables"
  local vault_file="${vault_dir}/vaultVariables_keys.txt"

  if [ ! -f "$vault_file" ]; then
    echo "❌ Missing file: ${vault_file}"
    return 1
  fi

  echod "Vault Variables file found: ${vault_file}"

  # Read keys from JSON array or plain text file
  local keys=()
  if jq empty "$vault_file" 2>/dev/null; then
    mapfile -t keys < <(jq -r '.[]' "$vault_file")
  else
    mapfile -t keys < "$vault_file"
  fi

  if [ ${#keys[@]} -eq 0 ]; then
    echo "❌ No vault variable keys found in $vault_file"
    return 1
  fi

  for vaultVariablesKey in "${keys[@]}"; do
    echod "Processing vault variable: $vaultVariablesKey"

    local single_key_file="${vault_dir}/${vaultVariablesKey}_key.json"
    if [ ! -f "$single_key_file" ]; then
      echo "❌ Vault variable config not found: $single_key_file"
      continue
    fi

    # Extract first object from JSON array or object itself
    vaultVariablesJSON=$(jq -c 'if type=="array" then .[0] else . end' "$single_key_file" 2>/dev/null) || {
      echo "❌ Invalid JSON in $single_key_file"
      continue
    }

    echod "Creating vault variable with payload: $vaultVariablesJSON"

    local response
    response=$(curl -sS --location --request POST \
      "${LOCAL_DEV_URL}/apis/v2/rest/configurations/variables" \
      --header 'Content-Type: application/json' \
      --header 'Accept: application/json' \
      --data-raw "$vaultVariablesJSON" \
      --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}") # Gen-2: Changed from basic auth

    local createdId
    createdId=$(echo "$response" | jq -r '.output.code // empty')

    if [ "$createdId" == "201" ]; then
      echo "✅ Created vault variable: $vaultVariablesKey (Code: $createdId)"

      # Extract referenced projects from this variable's config for syncing
      local list_of_projects
      list_of_projects=$(jq -r '.references | keys? // [] | join(",")' "$single_key_file")

      if [ -n "$list_of_projects" ]; then
        local sync_url="${LOCAL_DEV_URL}/apis/v2/rest/configurations/variables/${vaultVariablesKey}/sync?projects=${list_of_projects}"
        echod "Syncing vault variable $vaultVariablesKey to projects: $list_of_projects"

        local sync_resp
        sync_resp=$(curl -sS --location --request PUT "$sync_url" \
          --header 'Content-Type: application/json' \
          --header 'Accept: application/json' \
          --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}") # Gen-2: Changed from basic auth

        local sync_code
        sync_code=$(echo "$sync_resp" | jq -r '.output.code // empty')

        if [ -n "$sync_code" ]; then
          echo "✅ Sync successful for $vaultVariablesKey (Code: $sync_code)"
        else
          echo "❌ Sync failed for $vaultVariablesKey — Response: $sync_resp"
        fi
      else
        echod "No references found for $vaultVariablesKey, skipping sync."
      fi
    else
      echo "❌ Failed to create vault variable: $vaultVariablesKey — Response: $response"
      continue
    fi
  done
}

# Main project-level vault variable importer
function projectImportVaultVariables() {
  local LOCAL_DEV_URL=$1
  local X_INSTANCE_API_KEY=$2 # Gen-2: Changed from admin_user
  local repoName=$3
  local HOME_DIR=$4
  local synchProject=$5

  local base_vault_dir="${HOME_DIR}/${repoName}/assets/projectConfigs/vaultVariables"

  if [ ! -d "$base_vault_dir" ]; then
    echo "❌ Vault variables directory not found at: $base_vault_dir"
    return 1
  fi

  cd "$base_vault_dir" || exit 1

  # Assuming you want to import for the main repo, not per subdirectory
  importVaultVariables "$LOCAL_DEV_URL" "$X_INSTANCE_API_KEY" "$repoName" "$HOME_DIR" "$synchProject" # Gen-2: Updated function call

  cd "${HOME_DIR}/${repoName}" || exit 1
}

# Start execution with passed args
projectImportVaultVariables "$@"
