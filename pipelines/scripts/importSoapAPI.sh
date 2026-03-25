################################################################################################################################################################
# Summary:
#   Imports a SOAP API asset (or recipe) into a given project repository by uploading the corresponding ZIP file to the platform.
#   It supports conditional handling for SOAP APIs and other asset types, including validation of the import status.
#
# Usage:
#   importSOAPAsset <LOCAL_DEV_URL> <X_INSTANCE_API_KEY> <repoName> <assetID> <assetType> <HOME_DIR>  # Gen-2
#
# Mandatory Fields:
#   LOCAL_DEV_URL   - Base URL of the local dev environment (e.g., http://localhost:5555)
#   X_INSTANCE_API_KEY - API key for authentication  # Gen-2
#   repoName        - Name of the repository/project where the asset will be imported
#   assetID         - ID of the asset to be imported (corresponds to the ZIP filename)
#   assetType       - Type of the asset (e.g., soap_api, recipe)
#   HOME_DIR        - Path to the base working directory
################################################################################################################################################################



function importSOAPAsset() {
  LOCAL_DEV_URL=$1
  X_INSTANCE_API_KEY=$2 # Gen-2: Changed from admin_user
  repoName=$3
  assetID=$4
  assetType=$5
  HOME_DIR=$6

  echo "Current directory: $(pwd)"
  ls -ltr
  echo "AssetType: $assetType"

  if [[ $assetType = soap_api* ]]; then
    IMPORT_URL=${LOCAL_DEV_URL}/apis/v1/rest/project-import
    cd ${HOME_DIR}/${repoName}/assets/soap_api
    echo "SOAP API Import: ${IMPORT_URL}"
    ls -ltr
  fi

  echo "Import URL: ${IMPORT_URL}"
  echo "Working Dir: ${PWD}"

  FILE=./${assetID}.zip
  if [[ $assetType = soap_api* ]]; then
    formKey="project=@${FILE}"
  else
    formKey="recipe=@${FILE}"
  fi

  overwriteKey="overwrite=true"
  echo "Form key: ${formKey}"

  if [ -f "$FILE" ]; then
    echo "$FILE exists. Importing ..."
    importedName=$(curl --location --request POST ${IMPORT_URL} \
      --header 'Content-Type: multipart/form-data' \
      --header 'Accept: application/json' \
      --form ${formKey} --form ${overwriteKey} \
      --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}") # Gen-2: Changed from basic auth

    if [[ $assetType = soap_api* ]]; then
      name=$(echo "$importedName" | jq -r '.output.message // empty')
      success="IMPORT_SUCCESS"
      if [ "$name" == "$success" ]; then
        echo "Import Succeeded: ${importedName}"
      else
        echo "Import Failed: ${importedName}"
      fi
    else
      name=$(echo "$importedName" | jq -r '.output.name // empty')
      if [ -z "$name" ]; then
        echo "Import failed: ${importedName}"
      else
        echo "Import Succeeded: ${importedName}"
      fi
    fi
  else
    echo "$FILE does not exist, Nothing to import"
  fi

  cd ${HOME_DIR}/${repoName}
}
