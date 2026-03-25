#!/bin/bash

####################################################################################################################################################################
#                                                                                                                                                                  #
#  deleteProjectParameter.sh : Delete project parameters from a webMethods.io Project                                                                              #
#                                                                                                                                                                  #
#  FUNCTIONS:                                                                                                                                                      #
#   - deleteProjectParameter : Deletes a single project parameter by name.                                                                                         #
#   - extractProjectParameters : Batch-deletes project parameters by reading them from a file (line by line).                                                      #
#                                                                                                                                                                  #
#  MANDATORY PARAMETERS:                                                                                                                                           #
#   LOCAL_DEV_URL          : Base URL of the Tenant (e.g., http://localhost:5555)                                                                                  #
#   X_INSTANCE_API_KEY     : API Key for authentication (Gen-2)                                                                                                    #
#   projectParameter       : The project parameter name to delete (used in single delete)                                                                          #
#   repo_name              : Name of the project/repository where parameters exist                                                                                 #
#   project_param_file     : File containing a list of project parameter names (one per line, used in batch delete)                                                 #
#                                                                                                                                                                  #
#  USAGE EXAMPLES:                                                                                                                                                 #
#   Delete a single project parameter:                                                                                                                             #
#     ./deleteProjectParameter.sh "http://localhost:5555" "admin" "password" "ParamName" "MyRepo"                                                                  #
#                                                                                                                                                                  #
#   Delete multiple project parameters from file:                                                                                                                  #
#     ./deleteProjectParameter.sh "http://localhost:5555" "admin" "password" "./projectParams.txt" "MyRepo"                                                        #
#                                                                                                                                                                  #
####################################################################################################################################################################


# Debug echo
function echod() {
  echo "[DEBUG] $@"
}

# Function to delete a single Project Parameter entry
function deleteProjectParameter() {
  LOCAL_DEV_URL=$1
  X_INSTANCE_API_KEY=$2  # Gen-2: Changed from admin_user
  assetID=$3
  repo_name=$4

  if [ -z "$assetID" ]; then
    echo "❌ Project Parameter name not provided!"
    exit 1
  fi

  PROJECT_PARAMETER_DELETE_URL="${LOCAL_DEV_URL}/apis/v1/rest/projects/${repo_name}/projectParameter/${assetID}"
  echod "Deleting Project Parameter: $assetID"
  echod "API URL: $PROJECT_PARAMETER_DELETE_URL"

  # Gen-2: Changed to header-based API key authentication
  response=$(curl --silent --location --request DELETE "$PROJECT_PARAMETER_DELETE_URL" \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json' \
    --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}")

  status=$(echo "$response" | jq -r '.output.code // empty')

  if [ "$status" == "SUCCESS" ]; then
    echo "✅ Project Parameter '$projectParameter' deleted successfully."
  else
    echo "❌ Failed to delete Project Parameter '$projectParameter'"
    echo "Response: $response"
  fi
}

# Function to read Project Parameter names from a file and delete them
function extractProjectParameters() {
  LOCAL_DEV_URL=$1
  X_INSTANCE_API_KEY=$2  # Gen-2: Changed from admin_user
  project_param_file=$3
  repo_name=$4
  assetID=$5

  # If project_param_file is provided, read from file
  if [ -n "$project_param_file" ] && [ -f "$project_param_file" ]; then
    echo "📄 Reading Project Parameters from file: $project_param_file"
    while IFS= read -r projectParameter || [ -n "$projectParameter" ]; do
      # Skip empty lines or comments
      if [[ -n "$projectParameter" && ! "$projectParameter" =~ ^# ]]; then
        deleteProjectParameter "$LOCAL_DEV_URL" "$X_INSTANCE_API_KEY" "$projectParameter" "$repo_name"  # Gen-2: Updated function call
      fi
    done < "$project_param_file"
  # Otherwise, check if assetID is provided and use it directly
  elif [ -n "$assetID" ]; then
    deleteProjectParameter "$LOCAL_DEV_URL" "$X_INSTANCE_API_KEY" "$assetID" "$repo_name"  # Gen-2: Updated function call
  else
    echo "❌ Either project_param_file or assetID must be provided!"
    return 1
  fi
}

deleteProjectParameter "$@"
