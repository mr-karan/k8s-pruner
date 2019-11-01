#!/usr/bin/env bash

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions

function error() {
    JOB="$0"              # job name
    LASTLINE="$1"         # line of error occurrence
    LASTERR="$2"          # error code
    echo "ERROR in ${JOB} : line ${LASTLINE} with exit code ${LASTERR}"
    exit 1
}
trap 'error ${LINENO} ${?}' ERR

function getAllNamespaces() {
    echo "Fetching all namespaces"
    KUBE_NAMESPACES=( $(kubectl get ns -o json | jq -r '.items[].metadata.name' | grep -v 'kube') )
}

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

for ns in "${KUBE_NAMESPACES[@]}"
do
    getAllConfigMaps $ns
    getActiveConfigMaps $ns
    getInactiveConfigMaps
    pruneInactiveConfigMaps $ns
done
