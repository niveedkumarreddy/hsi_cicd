#!/bin/bash

#############################################################################
#                                                                           #
# createProject.sh : Creates Project if does not exists                     #
#                                                                           #
#############################################################################

LOCAL_DEV_URL="$1"
X_INSTANCE_API_KEY="$2"  # Gen-2: Changed from admin_user
repoName="$3"
inuid="$4"
debug="${@: -1}"

# Validate required inputs
[ -z "$LOCAL_DEV_URL" ] && echo "Missing template parameter LOCAL_DEV_URL" >&2 && exit 1
[ -z "$X_INSTANCE_API_KEY" ] && echo "Missing template parameter X_INSTANCE_API_KEY" >&2 && exit 1  # Gen-2: Changed validation
[ -z "$repoName" ] && echo "Missing template parameter repoName" >&2 && exit 1

# Debug mode
if [ "$debug" == "debug" ]; then
  echo "......Running in Debug mode ......" >&2
  set -x
fi

function echod() {
  echo "$@" >&2
}

PROJECT_URL="${LOCAL_DEV_URL}/apis/v1/rest/projects/${repoName}"

echod "Checking if project exists..."
# Gen-2: Changed to header-based API key authentication
response=$(curl --silent --location --request GET "$PROJECT_URL" \
  --header 'Accept: application/json' \
  --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}")

uid=$(echo "$response" | jq -r '.output.uid // empty')
name=$(echo "$response" | jq -r '.output.name // empty')
        

if [ -n "$inuid" ]; then
  if [[ "$uid" == "$inuid" ]]; then
    echod "Project with "$uid "already exists"
  else
    if [ -n "$uid" ]; then
      echod "Project "$name" exists with different uid: "$uid
      exit 1
    fi
  fi
fi


if [ -z "$uid" ]; then
    echod "Project does not exist. Creating..."  
    CREATE_URL="${LOCAL_DEV_URL}/apis/v1/rest/projects"

    if [ -n "$inuid" ]; then
      echod "Creating with name & uid..."
      json='{ "name": "'"${repoName}"'", "uid": "'"${inuid}"'", "description": "Created by Automated CI for feature branch"}'
    else
      echod "Creating with only name..."
      json='{ "name": "'"${repoName}"'", "description": "Created by Automated CI for feature branch"}'
    fi

    # Gen-2: Changed to header-based API key authentication
    projectCreateResp=$(curl --silent --location --request POST "$CREATE_URL" \
      --header 'Content-Type: application/json' \
      --header 'Accept: application/json' \
      --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}" \
      --data-raw "$json")

    uidcreated=$(echo "$projectCreateResp" | jq -r '.output.uid // empty')

    if [ -n "$uidcreated" ]; then
        echod "Project "$repoName "created successfully with uid: $uidcreated"
        echo "$uidcreated"   # ✅ Output only the name to stdout
    else
        echod "Project creation failed:"
        echod "$projectCreateResp"
        exit 1
    fi
else
    echod "Project already exists with name: $name"
    echo "$uid"  # ✅ Still echo the name if already exists
fi
