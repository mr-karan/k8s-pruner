# k8s-pruner
Cleanup unused Configmaps in a Kubernetes namespace

## Why

For folks using Kustomize, the configmaps are prefixed with a random hash. Whenever you change the config, the hash is changed which signals the Deployment to rollout new Pods with new configmap and kill the old ones. The problem seems to be that the old ConfigMaps are not garbage collected and seems to be stored in the etcd cluster forever.

## Features

- Runs inside Kubernetes cluster, no need to setup any external systems/bastions.
- Depends on K8s native RBAC and ServiceAccount for authentication/authorization.
- Executed as a CronJob

## Deployment

TODO.

## Known Limitations

If you've scaled down a deployment in a namespace, the configmaps will be deleted.