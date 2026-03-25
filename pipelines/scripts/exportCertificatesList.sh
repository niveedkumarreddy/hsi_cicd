#!/bin/bash

#################################################################################################################################################################
# Script Name: exportCertificatesList.sh                                                                                                                          #
# Summary    : Exports all Certificates or a single Certificate configuration from                                                                                  #
#              a given webMethods.io project repository using REST APIs.                                                                                        #
#                                                                                                                                                               #
# Usage      : ./exportCertificatesList.sh <LOCAL_DEV_URL> <X_INSTANCE_API_KEY> <repoName> <HOME_DIR> <assetID>                                 # Gen-2 #
#                                                                                                                                                               #
# Mandatory Fields:                                                                                                                                             #
#   LOCAL_DEV_URL   - The base URL of the target webMethods.io environment                                                                                      #
#   X_INSTANCE_API_KEY - API key for authentication                                                                                                 # Gen-2 #
#   repoName        - Repository (project) name in webMethods.io                                                                                                #
#   HOME_DIR        - Local home directory path for storing exports                                                                                             #
#   assetID         - service name of the Certificate                                                                            #
#                                                                                                                                                               #
# Example:                                                                                                                                                      #
#   ./exportCertificatesList.sh "https://mytenant.webmethods.io" "your-api-key" "MyRepo" "/home/user/projects" true                                     # Gen-2 #
#                                                                                                                                                               #
#################################################################################################################################################################


set -euo pipefail
set -x

echo "Starting exportCertificatesList.sh"
echo "Arguments: $@"

exportCertificatesList() {
    LOCAL_DEV_URL=$1
    X_INSTANCE_API_KEY=$2 # Gen-2: Changed from admin_user
    repoName=$3
    HOME_DIR=$4
    assetID=$5
    #CERT_TYPE=$7

    echo "Running exportCertificatesList with parameters:"
    echo "LOCAL_DEV_URL=$LOCAL_DEV_URL"
    echo "X_INSTANCE_API_KEY=****" # Gen-2: Changed from admin_user
    echo "repoName=$repoName"
    echo "HOME_DIR=$HOME_DIR"
    echo "assetID=$assetID"
    #echo "CERT_TYPE=$CERT_TYPE"
    echo "---------------------------------------------"

    cd "${HOME_DIR}/${repoName}" || exit 1

    if [ -z "$assetID" ] || [ "$assetID" = "null" ] || [ "$assetID" = "NA" ]; then
        Certificates_GET_LIST_URL="${LOCAL_DEV_URL}/apis/v1/rest/projects/${repoName}/configurations/certificates"

        CertificatesListJson=$(curl --silent --location --request GET "$Certificates_GET_LIST_URL" \
            --header 'Content-Type: application/json' \
            --header 'Accept: application/json' \
            --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}") # Gen-2: Changed from basic auth

        CertificatesList_file="./assets/projectConfigs/Certificates/CertificatesList.json"
        mkdir -p ./assets/projectConfigs/Certificates

        if [ -z "$CertificatesListJson" ] || [ "$CertificatesListJson" = "null" ]; then
            echo "❌ No Certificates retrieved."
            return 1
        fi

        echo "$CertificatesListJson" | jq '.' > "$CertificatesList_file"
        echo "✅ Certificates List saved to: $CertificatesList_file"

       # Extract and iterate over certificates from "output" array
        jq -r '.output[]
            | [.certificateType,
            (if .certificateType == "PARTNER_CERTIFICATE" then .name
            elif .certificateType == "KEY_STORE" then .keyStoreName
            elif .certificateType == "TRUST_STORE" then .TrustStoreName
            else empty end)
            ]
            | @tsv' "$CertificatesList_file" | while IFS=$'\t' read -r CERT_TYPE CERT_NAME; do

            if [[ -n "$CERT_NAME" && -n "$CERT_TYPE" ]]; then
                echo "🔹 Exporting certificate: $CERT_NAME  (Type: $CERT_TYPE)"
                exportSingleCertificate "$LOCAL_DEV_URL" "$X_INSTANCE_API_KEY" "$repoName" "$CERT_NAME" "$CERT_TYPE" # Gen-2: Updated function call
            else
                echo "⚠️ Skipping invalid certificate entry (missing name or type)"
            fi
        done
    else
        echo "🔹 Exporting single certificate: $assetID  (Type: $CERT_TYPE)"
        exportSingleCertificate "$LOCAL_DEV_URL" "$X_INSTANCE_API_KEY" "$repoName" "$assetID" "$CERT_TYPE" # Gen-2: Updated function call
    fi
}


function exportSingleCertificate() {
    LOCAL_DEV_URL=$1
    X_INSTANCE_API_KEY=$2 # Gen-2: Changed from admin_user
    repoName=$3
    assetID=$4
    CERT_TYPE=$5

    echo "Running exportSingleCertificate with parameters:"
    echo "LOCAL_DEV_URL=$LOCAL_DEV_URL"
    echo "X_INSTANCE_API_KEY=****" # Gen-2: Changed from admin_user
    echo "repoName=$repoName"
    echo "assetID=$assetID"
    echo "CERT_TYPE=$CERT_TYPE"
    
    SINGLE_Certificates_GET_URL="${LOCAL_DEV_URL}/apis/v1/rest/projects/${repoName}/configurations/certificates/${assetID}?certificateType=${CERT_TYPE}"

    singleCertificateJson=$(curl --silent --location --request GET "$SINGLE_Certificates_GET_URL" \
        --header 'Content-Type: application/json' \
        --header 'Accept: application/json' \
        --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}") # Gen-2: Changed from basic auth

    if [ -z "$singleCertificateJson" ] || [ "$singleCertificateJson" = "null" ]; then
        echo "⚠️ Skipping: No data for $assetID"
        return
    fi

    if echo "$singleCertificateJson" | jq empty 2>/dev/null; then
        output_dir="./assets/projectConfigs/Certificates"
        mkdir -p "$output_dir"

        individual_file="$output_dir/${assetID}_Certificate.json"
        echo "$singleCertificateJson" | jq '.' > "$individual_file"
        echo "✅ Saved: $individual_file"
    else
        echo "⚠️ Skipping invalid JSON for assetID: $assetID"
    fi
}


# Start execution
exportCertificatesList "$@"
