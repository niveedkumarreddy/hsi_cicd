#!/bin/bash

####################################################################################################################################################################
#                                                                                                                                                                  #
#  deleteReferenceData.sh : Delete reference data entries from a webMethods.io Project                                                                             #
#                                                                                                                                                                  #
#  FUNCTIONS:                                                                                                                                                      #
#   - deleteReferenceData   : Deletes a single reference data entry by name.                                                                                       #
#   - extractReferenceData  : Batch-deletes reference data entries by reading them from a file (line by line).                                                     #
#                                                                                                                                                                  #
#  MANDATORY PARAMETERS:                                                                                                                                           #
#   LOCAL_DEV_URL           : Base URL of the Tenant (e.g., http://localhost:5555)                                                                                 #
#   X_INSTANCE_API_KEY      : API Key for authentication (Gen-2)                                                                                                   #
#   referenceData           : The reference data name to delete (used in single delete)                                                                            #
#   repo_name               : Name of the project/repository where reference data exists                                                                           #
#   reference_data_file     : File containing a list of reference data names (one per line, used in batch delete)                                                  #
#                                                                                                                                                                  #
#  USAGE EXAMPLES:                                                                                                                                                 #
#   Delete a single reference data entry:                                                                                                                          #
#     ./deleteReferenceData.sh "http://localhost:5555" "admin" "password" "RefDataName" "MyRepo"                                                                   #
#                                                                                                                                                                  #
#   Delete multiple reference data entries from file:                                                                                                              #
#     ./deleteReferenceData.sh "http://localhost:5555" "admin" "password" "./referenceDataList.txt" "MyRepo"                                                       #
#                                                                                                                                                                  #
####################################################################################################################################################################


# Debug echo
function echod() {
  echo "[DEBUG] $@"
}

# Function to delete a single Reference Data entry
function deleteReferenceData() {
  LOCAL_DEV_URL=$1
  X_INSTANCE_API_KEY=$2  # Gen-2: Changed from admin_user
  assetID=$3
  repo_name=$4

  if [ -z "$assetID" ]; then
    echo "❌ Reference data name not provided!"
    exit 1
  fi

  REFERENCEDATA_DELETE_URL="${LOCAL_DEV_URL}/apis/v1/rest/projects/${repo_name}/referencedata/${assetID}"
  echod "Deleting reference data: $assetID"
  echod "API URL: $REFERENCEDATA_DELETE_URL"

  # Gen-2: Changed to header-based API key authentication
  response=$(curl --silent --location --request DELETE "$REFERENCEDATA_DELETE_URL" \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json' \
    --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}")

  status=$(echo "$response" | jq -r '.output.code // empty')

  if [ "$status" == "SUCCESS" ]; then
    echo "✅ Reference Data '$assetID' deleted successfully."
  else
    echo "❌ Failed to delete reference data '$assetID'"
    echo "Response: $response"
  fi
}

# Function to read reference data names from a file and delete them
function extractReferenceData() {
  LOCAL_DEV_URL=$1
  X_INSTANCE_API_KEY=$2  # Gen-2: Changed from admin_user
  reference_data_file=$3
  repo_name=$4
  assetID=$5

  # If reference_data_file is provided, read from file
  if [ -n "$reference_data_file" ] && [ -f "$reference_data_file" ]; then
    echo "📄 Reading reference data names from file: $reference_data_file"
    while IFS= read -r referenceData || [ -n "$referenceData" ]; do
      # Skip empty lines or lines starting with #
      if [[ -n "$referenceData" && ! "$referenceData" =~ ^# ]]; then
        deleteReferenceData "$LOCAL_DEV_URL" "$X_INSTANCE_API_KEY" "$referenceData" "$repo_name"  # Gen-2: Updated function call
      fi
    done < "$reference_data_file"
  # Otherwise, check if assetID is provided and use it directly
  elif [ -n "$assetID" ]; then
    deleteReferenceData "$LOCAL_DEV_URL" "$X_INSTANCE_API_KEY" "$assetID" "$repo_name"  # Gen-2: Updated function call
  else
    echo "❌ Either reference_data_file or assetID must be provided!"
    return 1
  fi
}

deleteReferenceData "$@"
