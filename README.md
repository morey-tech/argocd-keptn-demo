# Argo CD and Keptn Demo

## Bootstrapping Argo CD
```
kind create cluster --config kind-cluster.yaml
kubectl apply -k argocd
kubectl apply -f apps.yaml
```

This example includes a `devcontainer` configuration, allowing you to automatically create an environment for testing using the VSCode Dev Containers extension or GitHub Codespaces.

## Accessing the UI
Navigate to [https://localhost:8080/](https://localhost:8080/) on the machine with the `kind` cluster running.

Get the generated `admin` password.
```
argocd admin initial-password -n argocd
```

## Clean Up
```
kind delete cluster --name argocd-keptn
```

## Examples

> Keptn has created a resource called a KeptnApp to track your application. The name of which is 
based on the part-of label.

```
$ kubectl -n demo get keptnapp
NAME           AGE
keptndemoapp   3m20s
```