#!/bin/bash


####################################################################################################################################################################
#                                                                                                                                                                  #
#  deleteScheduler.sh : Delete one or more schedulers from a webMethods.io Project                                                                                 #
#                                                                                                                                                                  #
#  FUNCTIONS:                                                                                                                                                      #
#   - deleteScheduler        : Deletes a single scheduler by flow service name.                                                                                    #
#   - extractDeleteSchedulers: Reads scheduler names from a file and deletes them in batch.                                                                        #
#                                                                                                                                                                  #
#  MANDATORY PARAMETERS:                                                                                                                                           #
#   LOCAL_DEV_URL            : Base URL of the Tenant (e.g., http://localhost:5555)                                                                                #
#   X_INSTANCE_API_KEY       : API Key for authentication (Gen-2)                                                                                                  #
#   flowServiceName          : Flow service name tied to the scheduler (used in single delete)                                                                     #
#   repo_name                : Name of the project/repository                                                                                                      #
#   scheduler_file           : File containing scheduler names (one per line, used for batch delete)                                                               #
#                                                                                                                                                                  #
#  USAGE EXAMPLES:                                                                                                                                                 #
#   Delete a single scheduler:                                                                                                                                     #
#     ./deleteScheduler.sh "http://localhost:5555" "admin" "password" "flowServiceName1" "MyRepo"                                                                  #
#                                                                                                                                                                  #
#   Delete multiple schedulers from a file:                                                                                                                        #
#     ./deleteScheduler.sh "http://localhost:5555" "admin" "password" "./schedulerList.txt" "MyRepo"                                                               #
#                                                                                                                                                                  #
####################################################################################################################################################################



# Debug echo
function echod() {
  echo "[DEBUG] $@"
}

# Function to delete a scheduler
function deleteScheduler() {
  LOCAL_DEV_URL=$1
  X_INSTANCE_API_KEY=$2  # Gen-2: Changed from admin_user
  assetID=$3
  repo_name=$4

  if [ -z "$assetID" ]; then
    echo "❌ flowServiceName not provided!"
    exit 1
  fi

  SCHEDULER_DELETE_URL="${LOCAL_DEV_URL}/apis/v1/rest/projects/${repo_name}/configurations/schedulers/${assetID}"
  echod "Deleting scheduler: $assetID"
  echod "API URL: $SCHEDULER_DELETE_URL"

  # Gen-2: Changed to header-based API key authentication
  response=$(curl --silent --location --request DELETE "$SCHEDULER_DELETE_URL" \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json' \
    --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}")

  status=$(echo "$response" | jq -r '.output.code // empty')

  if [ "$status" == "SUCCESS" ]; then
    echo "✅ Scheduler '$assetID' deleted successfully."
  else
    echo "❌ Failed to delete scheduler '$assetID'"
    echo "Response: $response"
  fi
}

# Function to extract scheduler names from file and delete them
function extractDeleteSchedulers() {
  LOCAL_DEV_URL=$1
  X_INSTANCE_API_KEY=$2  # Gen-2: Changed from admin_user
  scheduler_file=$3
  repo_name=$4
  assetID=$5

  # If scheduler_file is provided, read from file
  if [ -n "$scheduler_file" ] && [ -f "$scheduler_file" ]; then
    echo "📄 Reading scheduler names from file: $scheduler_file"
    while IFS= read -r serviceName || [ -n "$serviceName" ]; do
      # Skip empty lines or commented lines
      if [[ -n "$serviceName" && ! "$serviceName" =~ ^# ]]; then
        deleteScheduler "$LOCAL_DEV_URL" "$X_INSTANCE_API_KEY" "$serviceName" "$repo_name"  # Gen-2: Updated function call
      fi
    done < "$scheduler_file"
  # Otherwise, check if assetID is provided and use it directly
  elif [ -n "$assetID" ]; then
    deleteScheduler "$LOCAL_DEV_URL" "$X_INSTANCE_API_KEY" "$assetID" "$repo_name"  # Gen-2: Updated function call
  else
    echo "❌ Either scheduler_file or assetID must be provided!"
    return 1
  fi
}

deleteScheduler "$@"
