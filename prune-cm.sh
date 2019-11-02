#!/usr/bin/env bash

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions


function alertOnFailure(){
    if [ ! -z "$ALERT_WEBHOOK_URL" ]; then
        echo "I am set"
        curl --header "Content-Type: application/json" --request POST --data '{"text":"Error while pruning unused configmaps"}' $ALERT_WEBHOOK_URL
    fi
}

function error() {
    JOB="$0"              # job name
    LASTLINE="$1"         # line of error occurrence
    LASTERR="$2"          # error code
    echo "ERROR in ${JOB} : line ${LASTLINE} with exit code ${LASTERR}"
    alertOnFailure
    exit 1
}
trap 'error ${LINENO} ${?}' ERR


a_flag=''
b_flag=''
files=''
verbose='false'

print_usage() {
  printf "Usage: ..."
}

while getopts 'abf:v' flag; do
  case "${flag}" in
    a) a_flag='true' ;;
    b) b_flag='true' ;;
    f) files="${OPTARG}" ;;
    v) verbose='true' ;;
    *) print_usage
       exit 1 ;;
  esac
done


function getAllNamespaces() {
    echo "Fetching all namespaces"
    # Filter out all kube* namespaces since they are actually not managed by end users.
    ALL_NAMESPACES=( $(kubectl get ns -o json |jq -r '.items[].metadata | select(.name | contains("kube") | not) | .name') )
}

# function filterNamespaces() {

# }

function getAllConfigMaps() {
    echo "Fetching all configmaps listed in namespace $1"
    ALL_CONFIGMAPS=( $(kubectl get cm -n $1 -o json | jq -r '.items[].metadata.name') )
}

function getActiveConfigMaps() {
    echo "Fetching only active configmaps listed in namespace $1"
    USED_CONFIGMAPS=( $(kubectl get pods -n $1 -o json | jq -r '.items[].spec.volumes[]?.configMap.name' | grep -v null || true | sort | uniq) )
}

function getInactiveConfigMaps() {
    UNUSED_CONFIGMAPS=(`echo ${ALL_CONFIGMAPS[@]} ${USED_CONFIGMAPS[@]} | tr ' ' '\n' | sort | uniq -u`)
}

function pruneInactiveConfigMaps() {
    for cm in "${UNUSED_CONFIGMAPS[@]}"
    do
        echo "Deleting unused configmap $cm present in namespace $1"
        # kubectl delete configmap $cm -n $1
    done
}
 
# fetch list of namespaces
getAllNamespaces
# filterNamespaces

for ns in "${ALL_NAMESPACES[@]}"
do
    getAllConfigMaps $ns
    getActiveConfigMaps $ns
    getInactiveConfigMaps
    pruneInactiveConfigMaps $ns
done
