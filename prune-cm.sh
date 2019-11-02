#!/usr/bin/env bash

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions


dry_run=false
verbose=false
programname=$0

# display help text.
print_usage() {
    echo "usage: $programname [-dvh]"
    echo "  -d      enable dry run. Running it with dry run will only list the configmaps to be deleted, it won't actually delete them"
    echo "  -v      enable verbose logging"
    echo "  -h      display help (this page)"
    exit 1
}

# parse optional args and flags.
while getopts 'dvh' flag; do
  case "${flag}" in
    d) dry_run=true ;;
    v) verbose=true ;;
    *) print_usage
       exit 1 ;;
  esac
done

# sends a message to webhook URL with body `{text:...}` in case the script fails at any point.
function alertOnFailure(){
    if [ ! -z "$ALERT_WEBHOOK_URL" ]; then
        echo "I am set"
        curl --header "Content-Type: application/json" --request POST --data '{"text":"Error while pruning unused configmaps"}' $ALERT_WEBHOOK_URL
    fi
}

# error() is called everytime any command returns a non zero exit code.
function error() {
    JOB="$0"              # job name
    LASTLINE="$1"         # line of error occurrence
    LASTERR="$2"          # error code
    echo "ERROR in ${JOB} : line ${LASTLINE} with exit code ${LASTERR}"
    alertOnFailure
    exit 1
}
trap 'error ${LINENO} ${?}' ERR

# set default variables.
KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
KUBE_API_URL="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT/api"

# check if all required variables are set.
function checkRequiredVariables() {
    if [ -z "$KUBE_TOKEN" ]; then
        echo "Missing required value of KUBE_TOKEN"
        exit 1
    fi
}

# fetches all namespaces. Namespaces containing `kube*` are filtered out since they are usually not managed
# by the end user but system.
function getAllNamespaces() {
    echo "Fetching all namespaces"
    ALL_NAMESPACES=( $(curl -sSk -H "Authorization: Bearer $KUBE_TOKEN" --url "${KUBE_API_URL}/v1/namespaces"  |jq -r '.items[].metadata | select(.name | startswith("kube") | not) | .name') )
}

# given a namespace, it fetches all configmaps existing.
function getAllConfigMaps() {
    echo "Fetching all configmaps listed in namespace $1"
    ALL_CONFIGMAPS=( $(curl -sSk -H "Authorization: Bearer $KUBE_TOKEN" --url "${KUBE_API_URL}/v1/namespaces/${1}/configmaps" | jq -r '.items[].metadata.name') )
}

# given a namespace, it fetches all pods and currently used configmaps.
function getActiveConfigMaps() {
    echo "Fetching only active configmaps listed in namespace $1"
    USED_CONFIGMAPS=( $(curl -sSk -H "Authorization: Bearer $KUBE_TOKEN" --url "${KUBE_API_URL}/v1/namespaces/${1}/pods" | jq -r '.items[].spec.volumes[]?.configMap.name' | grep -v null || true | sort | uniq) )
}

# given an array of all configmaps and used configmaps it extracts the unused configmaps.
function getInactiveConfigMaps() {
    UNUSED_CONFIGMAPS=(`echo ${ALL_CONFIGMAPS[@]} ${USED_CONFIGMAPS[@]} | tr ' ' '\n' | sort | uniq -u`)
}

# given a configmap name it removes from the namespace
function pruneInactiveConfigMaps() {
    for cm in "${UNUSED_CONFIGMAPS[@]}"
    do
        echo "Deleting unused configmap $cm present in namespace $1"
        if [ "$dry_run" != true ] ; then
            kubectl delete configmap $cm -n $1
        fi
    done
}


checkRequiredVariables
getAllNamespaces

for ns in "${ALL_NAMESPACES[@]}"
do
    getAllConfigMaps $ns
    getActiveConfigMaps $ns
    getInactiveConfigMaps
    pruneInactiveConfigMaps $ns
done
