#!/bin/bash 

#################################################################################################################################################################
# Script Name   : exportVaultVariablesList.sh                                                                                                                   #
# Summary       : Exports Vault Variables from webMethods.io to local repository.                                                                               #
#                 - Retrieves all vault variable keys.                                                                                                          #
#                 - Saves keys list to a file.                                                                                                                  #
#                 - Exports individual vault variable definitions into separate JSON files.                                                                     #
#                 - Generates a combined full JSON export of all vault variables.                                                                               #
#                                                                                                                                                               #
# Usage         : ./exportVaultVariablesList.sh <LOCAL_DEV_URL> <X_INSTANCE_API_KEY> <REPO_NAME> <HOME_DIR>                                            # Gen-2 #
#                                                                                                                                                               #
# Example       : ./exportVaultVariablesList.sh "http://localhost:5555" "your-api-key" "myRepo" "/opt/softwareag"                                         # Gen-2 #
#                                                                                                                                                               #
# Mandatory Fields:                                                                                                                                             #
#   1. LOCAL_DEV_URL   - Base URL of local webMethods.io / Integration Server instance (e.g. http://localhost:5555).                                            #
#   2. X_INSTANCE_API_KEY - API key for authentication.                                                                                                     # Gen-2 #
#   3. REPO_NAME       - Repository name where configurations will be exported.                                                                                 #
#   4. HOME_DIR        - Path to the local home directory of the repository.                                                                                    #
#################################################################################################################################################################

set -x
echo "Starting exportVaultVariablesList.sh"
echo "Arguments: $@"

function exportVaultVariablesList() {

    LOCAL_DEV_URL=$1
    X_INSTANCE_API_KEY=$2 # Gen-2: Changed from admin_user
    repoName=$3
    HOME_DIR=$4

echo "Running exportVaultVariablesList with parameters:"
echo "LOCAL_DEV_URL=$1"
echo "X_INSTANCE_API_KEY=****" # Gen-2: Changed from admin_user
echo "repoName=$3"
echo "HOME_DIR=$4"


    cd "${HOME_DIR}/${repoName}" || exit

    VAULT_VARIABLES_GET_LIST_URL="${LOCAL_DEV_URL}/apis/v2/rest/configurations/variables"

    # Call API to get vault variable list
    vaultVariablesListJson=$(curl --silent --location --request GET "${VAULT_VARIABLES_GET_LIST_URL}" \
        --header 'Content-Type: application/json' \
        --header 'Accept: application/json' \
        --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}") # Gen-2: Changed from basic auth

    vaultVariablesListExport=$(echo "$vaultVariablesListJson" | jq '.')


    extract_keys_file="./assets/projectConfigs/vaultVariables/vaultVariables_keys.txt"

    if [ -z "$vaultVariablesListExport" ] || [ "$vaultVariablesListExport" == "null" ]; then
        echo "❌ No Vault Variables retrieved."
        echo "$vaultVariablesListJson"
    else
        mkdir -p ./assets/projectConfigs/vaultVariables
        echo "$vaultVariablesListExport" | jq -r '.[].key' > "$extract_keys_file"
        echo "✅ Vault variable keys saved to: $extract_keys_file"
    fi

    exportVaultVariables "$LOCAL_DEV_URL" "$X_INSTANCE_API_KEY" "$extract_keys_file" # Gen-2: Updated function call

    cd "${HOME_DIR}/${repoName}" || exit
}

function exportVaultVariables() {

    LOCAL_DEV_URL=$1
    X_INSTANCE_API_KEY=$2 # Gen-2: Changed from admin_user
    extract_keys_file=$3

echo "Running exportVaultVariables with parameters:"
echo "LOCAL_DEV_URL=$1"
echo "X_INSTANCE_API_KEY=****" # Gen-2: Changed from admin_user
echo "extract_keys_file=$3"


        output_dir="./assets/projectConfigs/vaultVariables"
        output_file="$output_dir/vaultVariables_full.json"
    
    vault_variables_array="[]"

    mkdir -p ./assets/projectConfigs/vaultVariables

    while IFS= read -r key; do
        if [ -z "$key" ]; then
            continue
        fi

        echo "Fetching variable: $key"
        VAULT_VARIABLES_GET_URL="${LOCAL_DEV_URL}/apis/v2/rest/configurations/variables/${key}"

        variableJson=$(curl --silent --location --request GET "${VAULT_VARIABLES_GET_URL}" \
            --header 'Content-Type: application/json' \
            --header 'Accept: application/json' \
            --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}") # Gen-2: Changed from basic auth

       
vaultVariablesExport=$(echo "$variableJson" | jq '.')

        if [ -z "$vaultVariablesExport" ] || [ "$vaultVariablesExport" == "null" ]; then
            echo "⚠️ Skipping: No data for $key"
            continue
        fi

        # Append to array
        vault_variables_array=$(echo "$vault_variables_array" | jq --argjson newItem "$vaultVariablesExport" '. + $newItem')
        # Save individual file
                individual_file="$output_dir/${key}_key.json"
                echo "$vaultVariablesExport" | jq '.' > "$individual_file"
                echo "✅ Saved: $individual_file"

    done < "$extract_keys_file"

    echo "$vault_variables_array" | jq '.' > "$output_file"
    echo "✅ Full vault variables JSON written to: $output_file"
}
                                                                                                                              
exportVaultVariablesList "$@"

