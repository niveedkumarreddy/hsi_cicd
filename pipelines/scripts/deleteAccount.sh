#!/bin/bash

####################################################################################################################################################################
#                                                                                                                                                                  #
#  deleteAccount.sh : Delete accounts from a project in a webMethods.io Project                                                                                    #
#                                                                                                                                                                  #
#  FUNCTIONS:                                                                                                                                                      #
#   - deleteAccount       : Deletes a single account by UID (unique identifier).                                                                                   #
#   - extractaccount_uids : Batch-deletes accounts by reading account UIDs from a file (line by line).                                                             #
#                                                                                                                                                                  #
#  MANDATORY PARAMETERS:                                                                                                                                           #
#   LOCAL_DEV_URL       : Base URL of the Tenant (e.g., http://localhost:5555)                                                                                     #
#   X_INSTANCE_API_KEY  : API Key for authentication (Gen-2)                                                                                                       #
#   account_uid         : The unique identifier of the account to delete (used in single delete)                                                                   #
#   repo_name           : Name of the project/repository where accounts exist                                                                                      #
#   account_delete_file : File containing a list of account UIDs (one per line, used in batch delete)                                                              #
#                                                                                                                                                                  #
#  USAGE EXAMPLES:                                                                                                                                                 #
#   Delete a single account:                                                                                                                                       #
#     ./deleteAccount.sh "http://localhost:5555" "admin" "password" "account123" "MyRepo"                                                                          #
#                                                                                                                                                                  #
#   Delete multiple accounts from file:                                                                                                                            #
#     ./deleteAccount.sh "http://localhost:5555" "admin" "password" "./accounts.txt" "MyRepo"                                                                      #
#                                                                                                                                                                  #
####################################################################################################################################################################


# Debug echo
function echod() {
  echo "[DEBUG] $@"
}

# Function to delete a single Account entry
function deleteAccount() {
  LOCAL_DEV_URL=$1
  X_INSTANCE_API_KEY=$2  # Gen-2: Changed from admin_user
  assetID=$3
  repo_name=$4

  if [ -z "$account_uid" ]; then
    echo "❌ Account UID not provided!"
    exit 1
  fi

  ACCOUNT_DELETE_URL="${LOCAL_DEV_URL}/apis/v1/rest/projects/${repo_name}/accounts/${assetID}"
  echod "Deleting Account: $assetID"
  echod "API URL: $ACCOUNT_DELETE_URL"

  # Gen-2: Changed to header-based API key authentication
  response=$(curl --silent --location --request DELETE "$ACCOUNT_DELETE_URL" \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json' \
    --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}")

  message=$(echo "$response" | jq -r '.output.message // empty')
  echo "✅ Account UID '$account_uid' '$message'"

}

# Function to read Project Parameter names from a file and delete them
function extractaccount_uids() {
  LOCAL_DEV_URL=$1
  X_INSTANCE_API_KEY=$2  # Gen-2: Changed from admin_user
  account_delete_file=$3
  repo_name=$4
  assetID=$5

  # If account_delete_file is provided, read from file
  if [ -n "$account_delete_file" ] && [ -f "$account_delete_file" ]; then
    echo "📄 Reading Account ID's from file: $account_delete_file"
    while IFS= read -r account_uid || [ -n "$account_uid" ]; do
      # Skip empty lines or comments
      if [[ -n "$account_uid" && ! "$account_uid" =~ ^# ]]; then
        deleteAccount "$LOCAL_DEV_URL" "$X_INSTANCE_API_KEY" "$account_uid" "$repo_name"  # Gen-2: Updated function call
      fi
    done < "$account_delete_file"
  # Otherwise, check if assetID is provided and use it directly
  elif [ -n "$assetID" ]; then
    deleteAccount "$LOCAL_DEV_URL" "$X_INSTANCE_API_KEY" "$assetID" "$repo_name"  # Gen-2: Updated function call
  else
    echo "❌ Either account_delete_file or assetID must be provided!"
    return 1
  fi
}

deleteAccount "$@"
