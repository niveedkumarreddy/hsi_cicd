####################################################################################################################################################################
#                                                                                                                                                                  #
#  exportSOAPAsset : Export SOAP API assets from a given project/repository in webMethods.io Tenant.                                     #
#                                                                                                                                                                  #
#  FUNCTION BEHAVIOR:                                                                                                                                              #
#   - If assetType starts with "soap_api*" → retrieves the Project ID for the repo.                                                                           #
#   - Else → exports SOAP API assets, generates a download link, and saves the .zip file under ./assets/soap_api in the repo home directory.                       #
#                                                                                                                                                                  #
#  MANDATORY PARAMETERS:                                                                                                                                           #
#   1. LOCAL_DEV_URL   : Base URL of the Tenant (e.g., http://localhost:5555)                                                                                      #
#   2. X_INSTANCE_API_KEY : API key for authentication                                                                                                         # Gen-2 #
#   3. repoName        : Repository (Project) name from which assets should be exported                                                                            #
#   4. assetID         : Unique Asset ID of the SOAP API to be exported                                                                                            #
#   5. assetType       : Asset type (e.g., soap_api)                                                                                               #
#   6. HOME_DIR        : Local home directory path where export files should be stored                                                                             #
#                                                                                                                                                                  #
#  USAGE EXAMPLES:                                                                                                                                                 #
#   Export a SOAP API Asset:                                                                                                                                        #
#     ./exportSoapAPI.sh "http://localhost:5555" "your-api-key" "MyRepo" "MySOAPAssetID" "soap_api" "/opt/softwareag/projects"                                     # Gen-2 #
#                                                                                                                                                                  #
#                                                                                                                                                                  #
####################################################################################################################################################################


function exportSOAPAsset() {
  LOCAL_DEV_URL=$1
  X_INSTANCE_API_KEY=$2 # Gen-2: Changed from admin_user
  repoName=$3
  assetID=$4
  assetType=$5
  HOME_DIR=$6

  # Single assetType
  if [[ $assetType = soap_api* ]]; then
    PROJECT_ID_URL=${LOCAL_DEV_URL}/apis/v1/rest/projects/${repoName}

    projectJson=$(curl --location --request GET ${PROJECT_ID_URL} \
      --header 'Content-Type: application/json' \
      --header 'Accept: application/json' \
      --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}") # Gen-2: Changed from basic auth

    projectID=$(echo "$projectJson" | jq -r -c '.output.uid // empty')

    if [ -z "$projectID" ]; then
      echo "Incorrect Project/Repo name"
      exit 1
    fi

    echo "ProjectID: ${projectID}"
  
  else
    EXPORT_URL=${LOCAL_DEV_URL}/apis/v1/rest/projects/${repoName}/export
    soap_api_json="{\"soap_api\": [\"${assetID}\"]}"

    cd ${HOME_DIR}/${repoName}
    mkdir -p ./assets/soap_api
    cd ./assets/soap_api

    echo "soap_api Export: ${EXPORT_URL} with JSON: ${soap_api_json}"
    ls -ltr

    linkJson=$(curl --location --request POST ${EXPORT_URL} \
      --header 'Content-Type: application/json' \
      --header 'Accept: application/json' \
      --data-raw "$soap_api_json" \
      --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}") # Gen-2: Changed from basic auth

    downloadURL=$(echo "$linkJson" | jq -r '.output.download_link')

    regex='(https?|ftp|file)://[-[:alnum:]\+&@#/%?=~_|!:,.;]*[-[:alnum:]\+&@#/%=~_|]'
    if [[ $downloadURL =~ $regex ]]; then
      echo "Valid Download link retrieved: ${downloadURL}"
    else
      echo "Download link retrieval Failed: ${linkJson}"
      exit 1
    fi

    curl --location --request GET "${downloadURL}" --output ${assetID}.zip

    FILE=./${assetID}.zip
    if [ -f "$FILE" ]; then
      echo "Download succeeded:"
      ls -ltr ./${assetID}.zip
    else
      echo "Download failed"
    fi
  fi

  cd ${HOME_DIR}/${repoName}
}
