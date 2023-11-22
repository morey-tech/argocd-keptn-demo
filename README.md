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
kind delete cluster --name argocd-v2-9-0-examples
```

## Examples

### Dynamically Re-Balance Clusters Across Shards
The Argo CD application controller can become overloaded when managing multiple remote clusters with many resources. The solution is to run multiple shards of the application controller, where each is responsible for one or more clusters (and each cluster can only belongs to one shard). However, adding new shards requires increasing the number of replicas on the `application-controller` `StatefulSet`. Previously, the shard count was set via the `ARGOCD_CONTROLLER_REPLICAS` environment variable, and changing it forced a restart of all `application-controller` pods. In 2.9, this **alpha feature** updates the `application-controller` to be a `Deployment` (instead of a `StatefulSet`). The `replicas` field is now used for the shard count, and when replicas are added or removed, the sharding algorithm is re-run to ensure that the clusters are distributed accordingly.

In [this example](./dynamic-shard-rebalance/), I take advantage of [Kustomize components](https://github.com/kubernetes-sigs/kustomize/blob/master/examples/components.md#components-example) to patch the `StatefulSet` to `0` replicas and create the `application-controller` `Deployment` with `2` replicas. The `ARGOCD_ENABLE_DYNAMIC_CLUSTER_DISTRIBUTION` environment variable must be set to `true` on the `Pod` for the `application-controller` to enable the cluster shard re-balancing functionality (currently, this breaks the pod due to [#16349](https://github.com/argoproj/argo-cd/issues/16349)).

The `application-controller` `Deployment` relies on a config map to track the mapping of replica (pod) to shard number, and the heartbeat from each shard. If the `argocd-app-controller-shard-cm` does not exist in the same namespace as the `application-controller`, it will create it. Then a shard number (`ShardNumber`) is associated with a `Pod` name (the `ControllerName`). Each shard will update it's heartbeat time (`HeartbeatTime`) when the `readinessProbe` on the `Pod` is called, which is every 10 seconds be default.

```json
% k get cm -n argocd argocd-app-controller-shard-cm -o "jsonpath={.data['shardControllerMapping']}" | jq
[
  {
    "ShardNumber": 0,
    "ControllerName": "argocd-application-controller-c5964bb48-4t7t4",
    "HeartbeatTime": "2023-11-15T16:04:58Z"
  },
  {
    "ShardNumber": 1,
    "ControllerName": "argocd-application-controller-c5964bb48-ss49f",
    "HeartbeatTime": "2023-11-15T16:04:58Z"
  }
]
```

Users of the default hash-based sharding algorithm won't see any improvements as clusters be roughly-balanced between shards. For users of the round-robin or other custom algorithms, a static assignment can lead to unbalanced shards when replicas are added or removed. So, the dynamic shard re-balancing functionality benefits users of custom shard assignment strategies the most.

Thanks, Ishita Sequeira (Red Hat), for writing the initial proposal and [implementing the whole feature](https://github.com/argoproj/argo-cd/pull/15036)!

https://argo-cd.readthedocs.io/en/latest/operator-manual/dynamic-cluster-distribution/

Open issues:
- https://github.com/argoproj/argo-cd/issues/16349

### Ignore ApplicationSet Differences
The `ApplicationSet` is a powerful feature that renders Argo CD `Applications` dynamically based on generators. However, there are situations where another process revises certain fields of an `Application` after the `ApplicationSet` creates it.

A common example is when using the Argo CD Image Updater with `Applications` managed by an `ApplicationSet`. When using the imperative write-back method, Image Updater changes the image tag using a parameter override (`argocd app set --parameter …`), which, if not ignored, would be overwritten by the `ApplicationSet`.

Or if you simply want to use `ApplicationSets` to create apps, but allow users to modify those `Applications` (e.g. disable auto-sync temporarily) without having their changes overwritten by the `ApplicationSet`.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: example
spec:
  ...
  ignoreApplicationDifferences:
  - jsonPointers:
    - /spec/source/targetRevision
  - name: guestbook-dev
    jqPathExpressions:
    - .spec.syncPolicy
```

This was one of the most voted proposals included in the v2.9.0 release. Thank you to Michael Crenshaw (Intuit) for all your interaction with the community on the issue, and for making this feature happen!

https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Controlling-Resource-Modification/#ignore-certain-changes-to-applications

### Support for Inline Kustomize Patches
Argo CD now supports the addition of in-line Kustomize patches in the `source.kustomize.pathces` field of `Applications`.

```yaml
spec:
  ...
  source:
    path: kustomize-guestbook
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: master
    kustomize:
      patches:
        - target:
            kind: Deployment
            name: guestbook-ui
          patch: |-
            - op: replace
              path: /spec/template/spec/containers/0/ports/0/containerPort
              value: 443
```

The inline kustomize patches work well with `ApplicationSets`, too. Instead of maintaining a patch or overlay for each cluster, patches can now be done in the `Application` template and utilize attributes from the generators. For example, with [`external-dns`](https://github.com/kubernetes-sigs/external-dns/) to set the [`txt-owner-id`](https://github.com/kubernetes-sigs/external-dns/blob/e1adc9079b12774cccac051966b2c6a3f18f7872/docs/registry/registry.md?plain=1#L6) to the cluster name.

In an ideal world, the `guestbook` path contains only plain Kubernetes manifests (no `kustomization.yaml`) but through the use of the `patches` field in the `Application`, you can use Kustomize to alter the `Deployment` manifest to use port `443`. However, a `kustomization.yaml` is still required ([#16352](https://github.com/argoproj/argo-cd/issues/16352))

With a `kustomization.yaml` file in the source, the patches from the `Application` will be merged with any existing patches.

Ref:
- https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/#patches
- https://github.com/argoproj/argo-cd/pull/14648
