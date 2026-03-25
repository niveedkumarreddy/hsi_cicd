#!/bin/bash

#############################################################################
#                                                                           #
# createProject.sh : Creates Project if does not exists                     #
#                                                                           #
#############################################################################

LOCAL_DEV_URL=$1
X_INSTANCE_API_KEY=$2  # Gen-2: Changed from admin_user
aliasName=$3
visibility=$4
description=$5
debug=${@: -1}

    if [ -z "$LOCAL_DEV_URL" ]; then
      echo "Missing template parameter LOCAL_DEV_URL"
      exit 1
    fi
    
    if [ -z "$X_INSTANCE_API_KEY" ]; then
      echo "Missing template parameter X_INSTANCE_API_KEY"  # Gen-2: Changed validation
      exit 1
    fi

    if [ -z "$aliasName" ]; then
      echo "Missing template parameter repoName"
      exit 1
    fi

    if [ -z "$visibility" ]; then
      echo "Missing template parameter repoName"
      exit 1
    fi

    if [ "$debug" == "debug" ]; then
      echo "......Running in Debug mode ......"
      set -x
    fi


function echod(){
  
  if [ "$debug" == "debug" ]; then
    echo $1
  fi

}



RUNTIME_REGISTER_URL=${LOCAL_DEV_URL}/apis/v1/rest/control-plane/runtimes/
 runtime_json='{ "name": "'${aliasName}'", "description": "'${description}'", "visibility": "'${visibility}'" }'

  echo "Registering Runtime"
  # Gen-2: Changed to header-based API key authentication
  registerRuntimeJson=$(curl --location --request POST ${RUNTIME_REGISTER_URL} \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json' \
  --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}" \
  --data-raw "$runtime_json" -w ";-)%{http_code}")
  
  status=$(echo $registerRuntimeJson | awk '{split($0,a,";-)"); print a[2]}')
  body=$(echo $registerRuntimeJson | awk '{split($0,a,";-)"); print a[1]}')
  echo "Status:"$status  
  echo "Body:"$body  

if [ ${status} -ge 200 ] && [ ${status} -lt 300 ]; then
    name=$(echo "$body" | jq -r '.name')
    agentID=$(echo "$body" | jq -r '.agentID')
    echo "Registered "$name" with agentID "$agentID 
else
    message=$(echo "$body" | jq -r '.integration.message.description')
    echo "Failed with Status Code: "$status "and message: "$message
    exit 1
fi

RUNTIME_PAIR_URL=${LOCAL_DEV_URL}/apis/v1/rest/control-plane/runtimes/${aliasName}/instances/new-pairing-request

  echo "Pairing Runtime"
  # Gen-2: Changed to header-based API key authentication
  pairRuntimeJson=$(curl --location --request POST ${RUNTIME_PAIR_URL} \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json' \
  --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}" \
  -w ";-)%{http_code}")

    status=$(echo $pairRuntimeJson | awk '{split($0,a,";-)"); print a[2]}')
    body=$(echo $pairRuntimeJson | awk '{split($0,a,";-)"); print a[1]}')
    echo "Status:"$status  
    echo "Body:"$body  

if [ ${status} -ge 200 ] && [ ${status} -lt 300 ]; then
    agentName=$(echo "$body" | jq -r '.agentName')
    agentID=$(echo "$body" | jq -r '.agentId')

    echo $body > ./${aliasName}_Paired.json
    pwd
    ls -ltr
    echo "Paired "$agentName" with agentID "$agentID 
else
    message=$(echo "$body" | jq -r '.integration.message.description')
    echo "Failed with Status Code: "$status "and message: "$message
    exit 1
fi

