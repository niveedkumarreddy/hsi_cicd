#!/bin/bash
set -euo pipefail

#################################################################################################################################################################
# Script Name: importCertificate.sh                                                                                                                              #
#                                                                                                                                                               #
# Summary:                                                                                                                                                      #
#   This script imports Certificate configurations (single or bulk) into a                                                                                        #
#   webMethods.io project environment. It can handle both individual                                                                                            #
#   Certificate imports (from `CertificatesKeyList.json`) and bulk imports                                                                                          #
#   (from `CertificatesList.json`).                                                                                                                               #
#                                                                                                                                                               #
# Usage:                                                                                                                                                        #
#   ./importCertificate.sh <LOCAL_DEV_URL> <X_INSTANCE_API_KEY> <repoName> <HOME_DIR> <assetID>                                                # Gen-2 #
#                                                                                                                                                               #
# Example:                                                                                                                                                      #
#   ./importCertificate.sh \                                                                                                                                     #
#     "http://localhost:5555" \                                                                                                                                 #
#     "your-api-key" \                                                                                                                                         # Gen-2 #
#     "myProjectRepo" \                                                                                                                                         #
#     "/home/user/projects" \                                                                                                                                   #
#     "dwd"                                                                                                                                                    #
#                                                                                                                                                               #
# Mandatory Fields:                                                                                                                                             #
#   LOCAL_DEV_URL      - Base URL of the local dev environment (e.g. http://localhost:5555)                                                                     #
#   X_INSTANCE_API_KEY - API key for authentication                                                                                              # Gen-2 #
#   repoName           - Name of the repository/project in HOME_DIR                                                                                             #
#   HOME_DIR           - Base directory containing the repo and assets                                                                                          #
#   assetID            - service name of the Certificate                                                                              #
#################################################################################################################################################################

function echod() {
  echo "[DEBUG] $@"
}


# Import all Certificate configurations in bulk
function importCertificate() {
  LOCAL_DEV_URL=$1
  X_INSTANCE_API_KEY=$2 # Gen-2: Changed from admin_user
  repoName=$3
  HOME_DIR=$4

  cd "${HOME_DIR}/${repoName}" || exit 1

    output_dir="./assets/projectConfigs/Certificates"
    mkdir -p "$output_dir"

    individual_file="$output_dir/${assetID}_Certificate.json"

  if [ -f "$individual_file" ]; then
    echod "✅ Certificate list found at: ${individual_file}"

    IMPORT_PROJECT_VARIABLES_URL="${LOCAL_DEV_URL}/apis/v1/rest/projects/${repoName}/configurations/certificates"

    # Read JSON payload for import
    CertificateJSON=$(jq -c '.output' "$individual_file")

    echod "📦 Certificate JSON Payload: $CertificateJSON"

    # Perform the import via POST request
    CertificatesImportJson=$(curl --silent --location --request POST "$IMPORT_PROJECT_VARIABLES_URL" \
      --header 'Content-Type: application/json' \
      --header 'Accept: application/json' \
      --data-raw "$CertificateJSON" \
      --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}") # Gen-2: Changed from basic auth

    CertificatesImportCreatedJson=$(echo "$CertificatesImportJson" | jq -r '.output // empty')

    if [ -z "$CertificatesImportCreatedJson" ]; then
      echo "❌ Certificate import failed. Response:"
      echo "CertificatesImportCreatedJson"
      return 1
    else
      echo "✅ Successfully imported Certificates."
      echo "$CertificatesImportCreatedJson"
    fi
  else
    echo "❌ Missing Certificate file: ${individual_file}"
    return 1
  fi
}



# Start execution
importCertificate "$@"
