#!/bin/bash
#############################################################################
##                                                                           #
##exportAssetsWithFullBuild.sh : Export assets with full build option       #
##                                                                          #
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
envTypes=${10}
repoUser=${11}
PAT=${12}
provider=${13}
vaultName=${14}
resourceGroup=${15}
location=${16}
azure_tenant_id=${17}
sp_app_id=${18}
sp_password=${19}
access_object_id=${20}
fullBuild=${21}
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
[ -z "$envTypes" ] && echo "Missing template parameter envTypes" >&2 && exit 1
[ -z "$repoUser" ] && echo "Missing template parameter repoUser" >&2 && exit 1
[ -z "$PAT" ] && echo "Missing template parameter PAT" >&2 && exit 1
[ -z "$provider" ] && echo "Missing template parameter provider" >&2 && exit 1
[ -z "$vaultName" ] && echo "Missing template parameter vaultName" >&2 && exit 1
[ -z "$resourceGroup" ] && echo "Missing template parameter resourceGroup" >&2 && exit 1
[ -z "$location" ] && echo "Missing template parameter location" >&2 && exit 1
[ -z "$azure_tenant_id" ] && echo "Missing template parameter azure_tenant_id" >&2 && exit 1
[ -z "$sp_app_id" ] && echo "Missing template parameter sp_app_id" >&2 && exit 1
[ -z "$sp_password" ] && echo "Missing template parameter sp_password" >&2 && exit 1
[ -z "$access_object_id" ] && echo "Missing template parameter access_object_id" >&2 && exit 1

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
  echod "Full build mode enabled - exporting entire project"
  
  # Full build export URL
  EXPORT_URL=${LOCAL_DEV_URL}/apis/v1/rest/projects/${repoName}/export
  
  cd ${HOME_DIR}/${repoName}
  mkdir -p ./assets/fullbuild
  cd ./assets/fullbuild
  
  echod "Full Build Export URL: ${EXPORT_URL}"
  
  # Execute full project export
  linkJson=$(curl --location --request POST ${EXPORT_URL} \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json' \
    --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}") # Gen-2: Changed from basic auth
  
  if [ -n "$linkJson" ] && [ "$linkJson" != "null" ]; then
    downloadURL=$(echo "$linkJson" | jq -r '.output.download_link')
    
    regex='(https?|ftp|file)://[-[:alnum:]\+&@#/%?=~_|!:,.;]*[-[:alnum:]\+&@#/%=~_|]'
    
    if [[ $downloadURL =~ $regex ]]; then 
      echod "Valid Download link retrieved: ${downloadURL}"
    else
      echo "Download link retrieval Failed: ${linkJson}" >&2
      exit 1
    fi
    
    # Download the full project export
    downloadJson=$(curl --location --request GET "${downloadURL}" --output ${repoName}_fullbuild.zip)
    
    FILE=./${repoName}_fullbuild.zip
    if [ -f "$FILE" ]; then
      echo "Full build download succeeded: $(ls -ltr ./${repoName}_fullbuild.zip)"
    else
      echo "Full build download failed: ${downloadJson}" >&2
      exit 1
    fi
  else
    echo "Failed to get export link for full build: ${linkJson}" >&2
    exit 1
  fi
  
  cd ${HOME_DIR}/${repoName}
  echod "Full build export completed successfully"
  
else
  echod "Standard export mode - invoking exportAsset.sh"
  
  # Call the existing exportAsset.sh script with all variables unchanged
  ${HOME_DIR}/self/pipelines/scripts/exportAsset.sh \
    "$LOCAL_DEV_URL" \
    "$X_INSTANCE_API_KEY" \
    "$repoName" \
    "$assetIDList" \
    "$assetTypeList" \
    "$HOME_DIR" \
    "$synchProject" \
    "$source_type" \
    "$includeAllReferenceData" \
    "$envTypes" \
    "$repoUser" \
    "$PAT" \
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
    echod "Standard export completed successfully"
  else
    echo "Standard export failed" >&2
    exit 1
  fi
fi

echod "Export process completed"

# Made with Bob
