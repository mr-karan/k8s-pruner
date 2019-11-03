# k8s-pruner
Cleanup unused Configmaps in a Kubernetes namespace

## Why

For folks using Kustomize, the configmaps are prefixed with a random hash. Whenever you change the config, the hash is changed which signals the Deployment to rollout new Pods with new configmap and kill the old ones. The problem seems to be that the old ConfigMaps are not garbage collected and seems to be stored in the etcd cluster forever.

There is a [KEP](https://github.com/kubernetes/community/pull/2287) for garbage collection of unused resources but I've tested it with `1.14` cluster version and the issue still seems to persist.

## Features

- Runs inside Kubernetes cluster, no need to setup any external systems/bastions.
- Depends on K8s native RBAC and ServiceAccount for authentication/authorization.
- Executed as a CronJob

## Deployment

- Checkout the manifests present at: `cd deployment/kubernetes/`
- `kubectl apply -f manifests/`

By default, the CronJob is scheduled to run at 1AM every night, you can modify this according to your cluster configurations.

## Known Limitations

- If you've scaled down a deployment in a namespace, the configmaps will be deleted.
- If you want to rollback a deployment, with `kubectl rollout undo` this won't be possible (since the old configmap is deleted), however if you follow the `GitOps` way of deploying manifests, a simple `git revert` can help you. 

> NOTE: I am planning to port this shell script to a Golang binary with more bells and whistles and trying to overcome the above limitations, not recommended to use in Production as of yet.