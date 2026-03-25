#!/bin/bash
set -e
set -o pipefail

#####################################################################################################################################################################################
# Script: importProjectConfiguration.sh                                                                                                                                             #
#                                                                                                                                                                                   #
# Summary:                                                                                                                                                                          #
#   Imports project configuration into a webMethods.io project                                                                                                                      #
#   from previously exported JSON files (packages, variables,                                                                                                                       #
#   connections, certificates, schedules, alert rules, etc.).                                                                                                                       #
#                                                                                                                                                                                   #
# Usage:                                                                                                                                                                            #
#   ./importProjectConfiguration.sh <LOCAL_DEV_URL> <X_INSTANCE_API_KEY> <repoName> <HOME_DIR> <source_env_name> <project_id>                                              # Gen-2 #
#                                                                                                                                                                                   #
# Mandatory Fields:                                                                                                                                                                 #
#   LOCAL_DEV_URL     - Target environment base URL (example: https://tenant.webmethods.io)                                                                                         #
#   X_INSTANCE_API_KEY - API key for authentication                                                                                                              # Gen-2 #
#   repoName          - Repository name where project configs are stored                                                                                                            #
#   HOME_DIR          - Base directory path for local repo storage                                                                                                                  #
#   source_env_name   - Source environment name (for metadata tracking)                                                                                                             #
#   project_id        - Target Project ID in webMethods.io                                                                                                                          #
#####################################################################################################################################################################################

echo "Starting importProjectConfiguration.sh"
echo "Arguments: $@"

function importProjectConfiguration() {
    LOCAL_DEV_URL=$1
    X_INSTANCE_API_KEY=$2 # Gen-2: Changed from admin_user
    repoName=$3
    HOME_DIR=$4


    echo "Running importProjectConfiguration with parameters:"
    echo "LOCAL_DEV_URL=$LOCAL_DEV_URL"
    echo "X_INSTANCE_API_KEY=****" # Gen-2: Changed from admin_user
    echo "repoName=$repoName"
    echo "HOME_DIR=$HOME_DIR"

    cd "${HOME_DIR}/${repoName}" || exit 1

    PROJECT_CONFIGURATION_IMPORT_URL="${LOCAL_DEV_URL}/apis/v2/rest/projects/${repoName}/configurations"
    
    file_dir="${HOME_DIR}/${repoName}/assets/projectConfigs/ProjectConfiguration"
    # Timestamp
    generated_on=$(date +%s)

    # If you have split files, read and assemble them
    source_env_name=$(jq -r '.metadata.source' $file_dir/ProjectConfiguration_List_Full.json)
    project_id=$(jq -r '.metadata.project' $file_dir/ProjectConfiguration_List_Full.json)
    packages=$(jq '.' $file_dir/configurations_packages.json)
    variables=$(jq '.' $file_dir/configurations_variables.json)
    connections=$(jq '.' $file_dir/configurations_connections.json)
    certificates=$(jq '.' $file_dir/configurations_certificates.json)
    servicesSchedule=$(jq '.' $file_dir/configurations_servicesSchedule.json)
    alertRules=$(jq '.' $file_dir/globals_alertRules.json)
    versionControlAccounts=$(jq '.' $file_dir/globals_versionControlAccounts.json)

    # Build full payload dynamically
    payload=$(jq -n \
      --arg source "$source_env_name" \
      --arg project "$project_id" \
      --argjson generatedOn "$generated_on" \
      --argjson packages "$packages" \
      --argjson variables "$variables" \
      --argjson connections "$connections" \
      --argjson certificates "$certificates" \
      --argjson servicesSchedule "$servicesSchedule" \
      --argjson alertRules "$alertRules" \
      --argjson versionControlAccounts "$versionControlAccounts" \
      '{
        apiVersion: "1.0",
        metadata: {
          project: $project,
          generatedOn: $generatedOn
        },
        configurations: {
          packages: $packages,
          variables: $variables,
          connections: $connections,
          certificates: $certificates,
          servicesSchedule: $servicesSchedule
        },
        globals: {
          alertRules: $alertRules,
          versionControlAccounts: $versionControlAccounts
        }
      }'
    )

    # Call API to import
    echo "📤 Importing project configuration to $PROJECT_CONFIGURATION_IMPORT_URL"
    response=$(curl --silent --show-error --fail \
      --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}" \
      -H "Content-Type: application/json" \
      -X PUT \
      --data-raw "$payload" \
      "$PROJECT_CONFIGURATION_IMPORT_URL"
    ) # Gen-2: Changed from basic auth

    echo "✅ Import completed. Response:"
    echo "$response" | jq '.'
}

# Usage:

importProjectConfiguration "$@"
