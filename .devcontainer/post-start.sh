#!/bin/bash

echo "post-start start" >> ~/status

# this runs in background each time the container starts

kind delete cluster --name argocd-keptn
kind create cluster --config kind-cluster.yaml
kubectl apply -k argocd

kubectl wait deployment -n argocd --all --for=condition=Available=True --timeout=90s
ARGOCD_ADMIN_PASSWORD="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
echo "${ARGOCD_ADMIN_PASSWORD}" > ~/argo-cd-admin-password.txt

kubectl apply -f apps.yaml

echo "post-start complete" >> ~/status