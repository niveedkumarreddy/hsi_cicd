#!/bin/bash

#################################################################################################################################################################
# Summary:                                                                                                                                                      #
#   Exports project variable details from a given repository in the local development environment.                                                         #
#   The script retrieves the project variable list via API and saves it locally in JSON files.                                                             #
#   It stores both the full export and specific sections (packages, variables, connections, certificates,                                                       #
#   schedules, alert rules, and version control accounts).                                                                                                      #
#                                                                                                                                                               #
# Usage:                                                                                                                                                        #
#   ./exportProjectVariable.sh <LOCAL_DEV_URL> <X_INSTANCE_API_KEY> <repoName> <HOME_DIR>                                                         # Gen-2 #
#                                                                                                                                                               #
# Mandatory Fields:                                                                                                                                             #
#   LOCAL_DEV_URL   - Base URL of the local dev environment (e.g., http://localhost:5555)                                                                       #
#   X_INSTANCE_API_KEY - API key for authentication                                                                                                         # Gen-2 #
#   repoName        - Name of the repository/project from which to export variables                                                                        #
#   HOME_DIR        - Path to the base working directory where exported files will be stored                                                                    #
#################################################################################################################################################################


set -x
echo "Starting exportProjectVariable.sh"
echo "Arguments: $@"

function exportProjectVariableList() {
    LOCAL_DEV_URL=$1
    X_INSTANCE_API_KEY=$2 # Gen-2: Changed from admin_user
    repoName=$3
    HOME_DIR=$4

    echo "Running exportProjectVariableList with parameters:"
    echo "LOCAL_DEV_URL=$LOCAL_DEV_URL"
    echo "X_INSTANCE_API_KEY=****" # Gen-2: Changed from admin_user
    echo "repoName=$repoName"
    echo "HOME_DIR=$HOME_DIR"

    cd "${HOME_DIR}/${repoName}" || exit 1

	if [ -z "$assetID" ] || [ "$assetID" = "null" ]; then
    PROJECT_VARIABLE_EXPORT_LIST_URL="${LOCAL_DEV_URL}/apis/v2/rest/projects/${repoName}/configurations/variables?type=ProjectVariable"

    # Call API to get Project variable list
    ProjectVariableListJson=$(curl --silent --location --request GET "${PROJECT_VARIABLE_EXPORT_LIST_URL}" \
        --header 'Content-Type: application/json' \
        --header 'Accept: application/json' \
        --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}") # Gen-2: Changed from basic auth

    # Validate response
    if [ -z "$ProjectVariableListJson" ] || [ "$ProjectVariableListJson" == "null" ]; then
        echo "❌ No Project variables retrieved."
        echo "$ProjectVariableListJson"
        return
    fi

    # Pretty print for local storage
    ProjectVariableListExport=$(echo "$ProjectVariableListJson" | jq '.')

    output_dir="./assets/projectConfigs/ProjectVariable"
    mkdir -p "$output_dir"

    # Save full export
    export_file="$output_dir/ProjectVariable_List_Full.json"
    echo "$ProjectVariableListExport" > "$export_file"
    echo "✅ Full project variable list saved to: $export_file"
    else
        exportProjectVariable "$LOCAL_DEV_URL" "$X_INSTANCE_API_KEY" "$repoName" "$assetID" # Gen-2: Updated function call
    fi 
}

function exportProjectVariable() {
    LOCAL_DEV_URL=$1
    X_INSTANCE_API_KEY=$2 # Gen-2: Changed from admin_user
    repoName=$3
    assetID=$4

    echo "Running exportProjectVariable with parameters:"
    echo "LOCAL_DEV_URL=$LOCAL_DEV_URL"
    echo "X_INSTANCE_API_KEY=****" # Gen-2: Changed from admin_user
    echo "repoName=$repoName"
    echo "assetID=$assetID"
    
    SINGLE_PROJECT_VARIABLE_GET_URL="${LOCAL_DEV_URL}/apis/v2/rest/projects/${repoName}/configurations/variables/${assetID}?type=projectVariable"

    ProjectVariableJson=$(curl --silent --location --request GET "$SINGLE_PROJECT_VARIABLE_GET_URL" \
        --header 'Content-Type: application/json' \
        --header 'Accept: application/json' \
        --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}") # Gen-2: Changed from basic auth

    if [ -z "$ProjectVariableJson" ] || [ "$ProjectVariableJson" = "null" ]; then
        echo "⚠️ Skipping: No data for $assetID"
        return
    fi

    if echo "$ProjectVariableJson" | jq empty 2>/dev/null; then
        output_dir="./assets/projectConfigs/ProjectVariable"
        mkdir -p "$output_dir"

        individual_file="$output_dir/${assetID}_ProjectVariable.json"
        echo "$ProjectVariableJson" | jq '.' > "$individual_file"
        echo "✅ Saved: $individual_file"
    else
        echo "⚠️ Skipping invalid JSON for assetID: $assetID"
    fi
}

exportProjectVariableList "$@"
