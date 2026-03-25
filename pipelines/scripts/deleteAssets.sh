#!/bin/bash

#############################################################################
#                                                                           #
# replicateProject.sh : Publish & Deploy Project to maintain same id        #
#                                                                           #
#############################################################################

LOCAL_DEV_URL=$1
X_INSTANCE_API_KEY=$2  # Gen-2: Changed from admin_user
repoName=$3
assetID=$4
assetType=$5
deleteProject=$6
debug=${@: -1}

    if [ -z "$LOCAL_DEV_URL" ]; then
      echo "Missing template parameter LOCAL_DEV_URL"
      exit 1
    fi
    
    if [ -z "$X_INSTANCE_API_KEY" ]; then
      echo "Missing template parameter X_INSTANCE_API_KEY"  # Gen-2: Changed validation
      exit 1
    fi

    if [ -z "$repoName" ]; then
      echo "Missing template parameter repoName"
      exit 1
    fi
    if [ -z "$assetType" ]; then
      echo "Missing template parameter assetType"
      exit 1
    fi    
    if [ -z "$deleteProject" ]; then
      echo "Missing template parameter deleteProject"
      exit 1
    fi
    if [ -z "$assetID" ]; then
      echo "Missing template parameter destEnv"
      exit 1
    fi
 if [ "$debug" == "debug" ]; then
    echo "......Running in Debug mode ......"
  fi


function echod(){
  
  if [ "$debug" == "debug" ]; then
    echo $1
    set -x
  fi

}

function deleteAsset(){

  LOCAL_DEV_URL=$1
  X_INSTANCE_API_KEY=$2  # Gen-2: Changed from admin_user
  repoName=$3
  assetID=$4
  assetType=$5
  

 
  if [[ $assetType = workflow* ]]; then
    echod $assetType
    DELETE_URL=${LOCAL_DEV_URL}/apis/v1/rest/projects/${repoName}/workflows/${assetID}
    echod "Workflow Delete:" ${DELETE_URL}
  else
    if [[ $assetType = flowservice* ]]; then
      DELETE_URL=${LOCAL_DEV_URL}/apis/v1/rest/projects/${repoName}/flows/${assetID}
      echod "Flowservice Delete:" ${DELETE_URL}
    else
      if [[ $assetType = account* ]]; then
        echod "account delete Process is Start"
        ../self/pipelines/scripts/deleteAccount.sh "$LOCAL_DEV_URL" "$X_INSTANCE_API_KEY" "$HOME_DIR" "$repoName" "$assetID"  # Gen-2: Updated script call
        echod "ACCOUNT delete Process is End"
      else
        if [[ $assetType = project_parameter* ]]; then
          echod "project_parameter delete Process is Start"
          ../self/pipelines/scripts/deleteProjectParameter.sh "$LOCAL_DEV_URL" "$X_INSTANCE_API_KEY" "$HOME_DIR" "$repoName" "$assetID"  # Gen-2: Updated script call
          echod "PROJECT_PARAMETER delete Process is End"
        fi

        if [[ $assetType = referenceData* ]]; then
          echod "referenceData delete Process is Start"
          ../self/pipelines/scripts/deleteReferenceData.sh "$LOCAL_DEV_URL" "$X_INSTANCE_API_KEY" "$HOME_DIR" "$repoName" "$assetID"  # Gen-2: Updated script call
          echod "REFERENCE_DATA delete Process is End"
        fi

        if [[ $assetType = Scheduler* ]]; then
          echod "Scheduler delete Process is Start"
          ../self/pipelines/scripts/deleteScheduler.sh "$LOCAL_DEV_URL" "$X_INSTANCE_API_KEY" "$HOME_DIR" "$repoName" "$assetID"  # Gen-2: Updated script call
          echod "SCHEDULER delete Process is End"
        fi

        if [[ $assetType = vault_variables* ]]; then
          echod "Vault Variables delete Process is Start"
          ../self/pipelines/scripts/deleteVaultVariablesList.sh "$LOCAL_DEV_URL" "$X_INSTANCE_API_KEY" "$HOME_DIR" "$repoName" "$assetID"  # Gen-2: Updated script call
          echod "VAULT_VARIABLES delete Process is End"
        fi
      fi
    fi
  fi

  echo "Deleting "${assetType}" in project: "${repoName}

  # Gen-2: Changed to header-based API key authentication
  deleteJson=$(curl  --location --request DELETE ${DELETE_URL} \
      --header 'Content-Type: application/json' \
      --header 'Accept: application/json' \
      --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}" | jq -r '.output.message // empty')
  
  echod ${deleteJson}

}


if [ ${deleteProject} == true ]; then
  echo "Listing All Assets"

  PROJECT_LIST_URL=${LOCAL_DEV_URL}/apis/v1/rest/projects/${repoName}/assets
  echo "Listing assets in project ... "

  # Gen-2: Changed to header-based API key authentication
  projectListJson=$(curl --location --request GET ${PROJECT_LIST_URL} \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json' \
  --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}")

  echod ${projectListJson}


 # Deleting Workflows
  for item in $(jq  -c -r '.output.workflows[]' <<< "$projectListJson"); do
    echod "Inside Workflow Loop"
    assetID=$item
    assetType=workflow
    echod $assetID
    deleteAsset ${LOCAL_DEV_URL} ${X_INSTANCE_API_KEY} ${repoName} ${assetID} workflow  # Gen-2: Updated function call
  done

  echo "Listing assets in project ... "
  # Gen-2: Changed to header-based API key authentication
  projectListJson=$(curl --location --request GET ${PROJECT_LIST_URL} \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json' \
  --header "X-INSTANCE-API-KEY: ${X_INSTANCE_API_KEY}")

  echod ${projectListJson}

  # Deleting Flows
  for item in $(jq  -c -r '.output.flows[]' <<< "$projectListJson"); do
    echod "Inside FS Loop"
    assetID=$item
    assetType=flowservice
    echod $assetID
    deleteAsset ${LOCAL_DEV_URL} ${X_INSTANCE_API_KEY} ${repoName} ${assetID} flowservice  # Gen-2: Updated function call
  done
else
  echod "Single asset delete ..."
  deleteAsset ${LOCAL_DEV_URL} ${X_INSTANCE_API_KEY} ${repoName} ${assetID} ${assetType}  # Gen-2: Updated function call
fi


set +x


