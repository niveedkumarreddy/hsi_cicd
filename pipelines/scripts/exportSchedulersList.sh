#!/bin/bash

#################################################################################################################################################################
# Script Name: exportSchedulersList.sh                                                                                                                          #
# Summary    : Exports all schedulers or a single scheduler configuration from                                                                                  #
#              a given webMethods.io project repository using REST APIs.                                                                                        #
#                                                                                                                                                               #
# Usage      : ./exportSchedulersList.sh <LOCAL_DEV_URL> <X_INSTANCE_API_KEY> <repoName> <HOME_DIR> <SINGLE_SCHEDULER>                                 # Gen-2 #
#                                                                                                                                                               #
# Mandatory Fields:                                                                                                                                             #
#   LOCAL_DEV_URL   - The base URL of the target webMethods.io environment                                                                                      #
#   X_INSTANCE_API_KEY - API key for authentication                                                                                                 # Gen-2 #
#   repoName        - Repository (project) name in webMethods.io                                                                                                #
#   HOME_DIR        - Local home directory path for storing exports                                                                                             #
#   SINGLE_SCHEDULER - true/false; when "true", exports individual scheduler configs                                                                            #
#                                                                                                                                                               #
# Example:                                                                                                                                                      #
#   ./exportSchedulersList.sh "https://mytenant.webmethods.io" "your-api-key" "MyRepo" "/home/user/projects" true                                     # Gen-2 #
#                                                                                                                                                               #
#################################################################################################################################################################


set -euo pipefail
set -x

echo "Starting exportSchedulersList.sh"
echo "Arguments: $@"

function exportSchedulersList() {
    LOCAL_DEV_URL=$1
    X_INSTANCE_API_KEY=$2 # Gen-2: Changed from admin_user
    repoName=$3
    HOME_DIR=$4
    SINGLE_SCHEDULER=$5

    echo "Running exportSingleScheduler with parameters:"
    echo "LOCAL_DEV_URL=$LOCAL_DEV_URL"
    echo "X_INSTANCE_API_KEY=****" # Gen-2: Changed from admin_user
    echo "repoName=$repoName"
    echo "HOME_DIR=$HOME_DIR"
    echo "SINGLE_SCHEDULER=$SINGLE_SCHEDULER"

    cd "${HOME_DIR}/${repoName}" || exit 1

    SCHEDULERS_GET_LIST_URL="${LOCAL_DEV_URL}/apis/v1/rest/projects/${repoName}/configurations/schedulers"

    # Call API to get scheduler list
    SchedulersListJson=$(curl --silent --location --request GET "$SCHEDULERS_GET_LIST_URL" \
        --header 'Content-Type: application/json' \
        --header 'Accept: application/json' \
        --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}") # Gen-2: Changed from basic auth

    SchedulersListExport=$(echo "$SchedulersListJson" | jq '.')

    SchedulersList_file="./assets/projectConfigs/Schedulers/SchedulersList.json"
    SchedulersKeyList_file="./assets/projectConfigs/Schedulers/SchedulersKeyList.json"

    if [ -z "$SchedulersListExport" ] || [ "$SchedulersListExport" == "null" ]; then
        echo "❌ No schedulers retrieved."
        echo "$SchedulersListJson"
    else
        mkdir -p ./assets/projectConfigs/Schedulers
        echo "$SchedulersListExport" | jq '.' > "$SchedulersList_file"
        echo "✅ Schedulers List saved to: $SchedulersList_file"
        echo "$SchedulersListJson" | jq -r '.output[].serviceName' > "$SchedulersKeyList_file"
        echo "✅ Scheduler keys saved to: $SchedulersKeyList_file"

        # echo "SINGLE_SCHEDULER = $SINGLE_SCHEDULER"
        # if [ "$SINGLE_SCHEDULER" == "true" ]; then
        #     echo "$SchedulersListJson" | jq -r '.output[].serviceName' > "$SchedulersKeyList_file"
        #     echo "✅ Scheduler keys saved to: $SchedulersKeyList_file"
        # fi
    fi

     exportSingleScheduler "$LOCAL_DEV_URL" "$X_INSTANCE_API_KEY" "$repoName" "$SchedulersKeyList_file" "$SINGLE_SCHEDULER" # Gen-2: Updated function call

    cd "${HOME_DIR}/${repoName}" || exit 1
}

function exportSingleScheduler() {
    LOCAL_DEV_URL=$1
    X_INSTANCE_API_KEY=$2 # Gen-2: Changed from admin_user
    repoName=$3
    SchedulersKeyList_file=$4
    SINGLE_SCHEDULER=$5

    echo "Running exportSingleScheduler with parameters:"
    echo "LOCAL_DEV_URL=$LOCAL_DEV_URL"
    echo "X_INSTANCE_API_KEY=****" # Gen-2: Changed from admin_user
    echo "repoName=$repoName"
    echo "SchedulersKeyList_file=$SchedulersKeyList_file"
    echo "SINGLE_SCHEDULER=$SINGLE_SCHEDULER"

    # if [ "$SINGLE_SCHEDULER" == "true" ]; then
        output_dir="./assets/projectConfigs/Schedulers"
        output_file="$output_dir/Single_Schedulers_file.json"
        single_schedule_array="[]"

        mkdir -p "$output_dir"

        while IFS= read -r serviceName; do
            if [ -z "$serviceName" ]; then
                continue
            fi

            echo "Fetching Service Name: $serviceName"
            SINGLE_SCHEDULERS_GET_URL="${LOCAL_DEV_URL}/apis/v1/rest/projects/${repoName}/configurations/schedulers/${serviceName}"

            singleSchedulerJson=$(curl --silent --location --request GET "$SINGLE_SCHEDULERS_GET_URL" \
                --header 'Content-Type: application/json' \
                --header 'Accept: application/json' \
                --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}") # Gen-2: Changed from basic auth

            singleScheduleExport=$(echo "$singleSchedulerJson" | jq '.')

            if [ -z "$singleScheduleExport" ] || [ "$singleScheduleExport" == "null" ]; then
                echo "⚠️ Skipping: No data for $serviceName"
                continue
            fi

            if echo "$singleScheduleExport" | jq empty 2>/dev/null; then
                # Append to single array (optional)
                single_schedule_array=$(echo "$single_schedule_array" | jq --argjson newItem "$singleScheduleExport" '. + [$newItem]')

                # Save individual file
                individual_file="$output_dir/${serviceName}_scheduler.json"
                echo "$singleScheduleExport" | jq '.' > "$individual_file"
                echo "✅ Saved: $individual_file"
            else
                echo "⚠️ Skipping invalid JSON for service: $serviceName"
            fi

        done < "$SchedulersKeyList_file"

        echo "$single_schedule_array" | jq '.' > "$output_file"
        echo "✅ Full scheduler config written to: $output_file"
   #  fi
}

# Start execution
exportSchedulersList "$@"
