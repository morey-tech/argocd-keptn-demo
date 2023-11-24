# Argo CD and Keptn Demo

## Bootstrapping Argo CD
```
kind create cluster --config kind-cluster.yaml
kubectl apply -k argocd
kubectl apply -f apps.yaml
```

This example includes a `devcontainer` configuration, allowing you to automatically create an environment for testing using the VSCode Dev Containers extension or GitHub Codespaces.

## Accessing the Argo CD UI
Navigate to [https://localhost:8080/](https://localhost:8080/) on the machine with the `kind` cluster running.

Get the generated `admin` password.
```
argocd admin initial-password -n argocd
```

Or:
```
cat ~/argo-cd-admin-password.txt
```

## Accessing the Grafana UI
Navigate to [https://localhost:8082/](https://localhost:8082/) on the machine with the `kind` cluster running (the dev container also forwards this port).

The username and password are `admin`.

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

> Keptn also creates a new application version every time you increment the version label.
>
> The PHASE will change as the deployment progresses. A successful deployment is shown as PHASE=Completed

```
$ kubectl -n demo get keptnappversion
NAME                          APPNAME        VERSION   PHASE
keptndemoapp-0.0.1-6b86b273   keptndemoapp   0.0.1     Completed
keptndemoapp-0.0.2-d4735e3a   keptndemoapp   0.0.2     Completed
```

> Keptn is generating DORA metrics and OpenTelemetry traces for your deployments.
> 
> These metrics are exposed via the Keptn lifecycle operator /metrics endpoint on port 2222.
> 
> To see these raw metrics:

```
SERVICE=$(kubectl get svc -l control-plane=lifecycle-operator -A -ojsonpath="{.items[0].metadata.name}")
kubectl -n keptn-lifecycle-toolkit-system port-forward svc/$SERVICE 8081:2222
```

> Access metrics in Prometheus format on [http://localhost:8081/metrics](http://localhost:8081/metrics)
> 
> Look for metrics starting with keptn_

