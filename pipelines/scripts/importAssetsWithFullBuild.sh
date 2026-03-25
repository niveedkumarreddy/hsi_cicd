#!/bin/bash

#############################################################################
#                                                                           #
# importAssetsWithFullBuild.sh : Import assets with full build option       #
#                                                                           #
#############################################################################

LOCAL_DEV_URL=$1
X_INSTANCE_API_KEY=$2 # Gen-2: Changed from admin_user
repoName=$3
assetIDList=$4
assetTypeList=$5
HOME_DIR=$6
synchProject=$7
source_type=$8
includeAllReferenceData=$9
provider=${10}
vaultName=${11}
resourceGroup=${12}
location=${13}
azure_tenant_id=${14}
sp_app_id=${15}
sp_password=${16}
access_object_id=${17}
fullBuild=${18}
environment=${19}
debug=${@: -1}

# Validate required inputs
[ -z "$LOCAL_DEV_URL" ] && echo "Missing template parameter LOCAL_DEV_URL" >&2 && exit 1
[ -z "$X_INSTANCE_API_KEY" ] && echo "Missing template parameter X_INSTANCE_API_KEY" >&2 && exit 1 # Gen-2: Changed from admin_user and admin_password
[ -z "$repoName" ] && echo "Missing template parameter repoName" >&2 && exit 1
[ -z "$assetIDList" ] && echo "Missing template parameter assetIDList" >&2 && exit 1
[ -z "$assetTypeList" ] && echo "Missing template parameter assetTypeList" >&2 && exit 1
[ -z "$HOME_DIR" ] && echo "Missing template parameter HOME_DIR" >&2 && exit 1
[ -z "$synchProject" ] && echo "Missing template parameter synchProject" >&2 && exit 1
[ -z "$source_type" ] && echo "Missing template parameter source_type" >&2 && exit 1
[ -z "$includeAllReferenceData" ] && echo "Missing template parameter includeAllReferenceData" >&2 && exit 1
[ -z "$provider" ] && echo "Missing template parameter provider" >&2 && exit 1
[ -z "$vaultName" ] && echo "Missing template parameter vaultName" >&2 && exit 1
[ -z "$resourceGroup" ] && echo "Missing template parameter resourceGroup" >&2 && exit 1
[ -z "$location" ] && echo "Missing template parameter location" >&2 && exit 1
[ -z "$azure_tenant_id" ] && echo "Missing template parameter azure_tenant_id" >&2 && exit 1
[ -z "$sp_app_id" ] && echo "Missing template parameter sp_app_id" >&2 && exit 1
[ -z "$sp_password" ] && echo "Missing template parameter sp_password" >&2 && exit 1
[ -z "$access_object_id" ] && echo "Missing template parameter access_object_id" >&2 && exit 1
[ -z "$environment" ] && environment="default" && echod "⚠️  Environment not specified, using 'default'"

# Debug mode
if [ "$debug" == "debug" ]; then
  echo "......Running in Debug mode ......" >&2
  set -x
fi

function echod() {
  echo "$@" >&2
}

# Main logic: Check if fullBuild flag is set
if [ "$fullBuild" == "true" ]; then
  echod "Full build mode enabled - importing entire project"
  
  # Full build import URL
  IMPORT_URL=${LOCAL_DEV_URL}/apis/v1/rest/project-import
  
  cd ${HOME_DIR}/${repoName}
  
  # Check if full build zip file exists
  FULLBUILD_DIR="./assets/fullbuild"
  if [ ! -d "$FULLBUILD_DIR" ]; then
    echo "Full build directory not found: ${FULLBUILD_DIR}" >&2
    exit 1
  fi
  
  cd ${FULLBUILD_DIR}
  
  # Find the full build zip file
  FULLBUILD_FILE=$(ls -1 ${repoName}_fullbuild.zip 2>/dev/null | head -n 1)
  
  if [ -z "$FULLBUILD_FILE" ]; then
    # Try to find any zip file in the directory
    FULLBUILD_FILE=$(ls -1 *.zip 2>/dev/null | head -n 1)
  fi
  
  if [ -z "$FULLBUILD_FILE" ]; then
    echo "Full build zip file not found in ${FULLBUILD_DIR}" >&2
    exit 1
  fi
  
  echod "Full Build Import URL: ${IMPORT_URL}"
  echod "Full Build File: ${FULLBUILD_FILE}"
  
  FILE="./${FULLBUILD_FILE}"
  if [ ! -f "$FILE" ]; then
    echo "Full build file does not exist: ${FILE}" >&2
    exit 1
  fi
  
  # Import the full project
  formKey="project=@${FILE}"
  overwriteKey="overwrite=true"
  
  echod "Importing full build: ${FILE}"
  
  importedName=$(curl --location --request POST ${IMPORT_URL} \
    --header 'Content-Type: multipart/form-data' \
    --header 'Accept: application/json' \
    --form ${formKey} \
    --form ${overwriteKey} \
    --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}") # Gen-2: Changed from basic auth
  
  # Check import result
  status=$(echo "$importedName" | jq -r '.output.status // empty')
  error_status=$(echo "$importedName" | jq -r '.error.status // empty')
  
  if [ "$status" == "IMPORT_SUCCESS" ]; then
    echod "✅ Full build import succeeded"
    echod "Response: ${importedName}"
    
    # Archive the successfully imported ZIP file with date stamp and environment
    ARCHIVE_DIR="${HOME_DIR}/${repoName}/assets/fullbuild/archive/${environment}"
    mkdir -p "${ARCHIVE_DIR}"
    
    # Get current date in YYYYMMDD_HHMMSS format
    DATE_STAMP=$(date +"%Y%m%d_%H%M%S")
    
    # Extract base name without extension
    BASE_NAME="${FULLBUILD_FILE%.zip}"
    ARCHIVED_FILE="${ARCHIVE_DIR}/${BASE_NAME}_${environment}_${DATE_STAMP}.zip"
    
    # Move the file to archive with environment and date stamp
    mv "${FILE}" "${ARCHIVED_FILE}"
    
    if [ $? -eq 0 ]; then
      echod "📦 Archived imported file to: ${ARCHIVED_FILE}"
      echod "   Environment: ${environment}"
      echod "   Timestamp: ${DATE_STAMP}"
    else
      echod "⚠️  Warning: Failed to archive file ${FILE}"
    fi
  elif [ -n "$status" ] && [ "$status" != "null" ] && [ "$status" != "empty" ]; then
    # Partial success or other status
    echod "⚠️  Full build import completed with status: ${status}"
    
    # Check for messaging issues
    messaging_issues=$(echo "$importedName" | jq -r '.output.messaging_issues // empty')
    if [ -n "$messaging_issues" ] && [ "$messaging_issues" != "null" ]; then
      issues=$(echo "$importedName" | jq -r '.output.messaging_issues.issues[]? // empty' | tr '\n' ', ')
      description=$(echo "$importedName" | jq -r '.output.messaging_issues.description // empty')
      echod "Issues: ${issues}"
      echod "Description: ${description}"
    fi
    
    echod "Full response: ${importedName}"
  elif [ -n "$error_status" ]; then
    # Error response
    error_message=$(echo "$importedName" | jq -r '.error.message // empty')
    error_code=$(echo "$importedName" | jq -r '.error.errorSource.errorCode // empty')
    request_id=$(echo "$importedName" | jq -r '.error.errorSource.requestID // empty')
    
    echo "❌ Full build import failed with status: ${error_status}" >&2
    echo "Error message: ${error_message}" >&2
    echo "Error code: ${error_code}" >&2
    echo "Request ID: ${request_id}" >&2
    echo "Full response: ${importedName}" >&2
    exit 1
  else
    echo "❌ Full build import failed - unexpected response format" >&2
    echo "Response: ${importedName}" >&2
    exit 1
  fi
  
  cd ${HOME_DIR}/${repoName}
  echod "Full build import completed successfully"
  
else
  echod "Standard import mode - invoking importAsset.sh"
  
  # Call the existing importAsset.sh script with all variables unchanged
  ${HOME_DIR}/self/pipelines/scripts/importAsset.sh \
    "$LOCAL_DEV_URL" \
    "$X_INSTANCE_API_KEY" \
    "$repoName" \
    "$assetIDList" \
    "$assetTypeList" \
    "$HOME_DIR" \
    "$synchProject" \
    "$source_type" \
    "$includeAllReferenceData" \
    "$provider" \
    "$vaultName" \
    "$resourceGroup" \
    "$location" \
    "$azure_tenant_id" \
    "$sp_app_id" \
    "$sp_password" \
    "$access_object_id" \
    "$debug" # Gen-2: Updated script call with new parameters
  
  # Check if the script executed successfully
  if [ $? -eq 0 ]; then
    echod "Standard import completed successfully"
  else
    echo "Standard import failed" >&2
    exit 1
  fi
fi

echod "Import process completed"

# Made with Bob
