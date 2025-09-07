#!/usr/bin/env bash
set -euo pipefail

echo "Applying Gatekeeper ConstraintTemplates..."
kubectl apply -f Task7/gatekeeper/constraint-templates/privileged.yaml
kubectl apply -f Task7/gatekeeper/constraint-templates/hostpath.yaml
kubectl apply -f Task7/gatekeeper/constraint-templates/runasnonroot.yaml

echo "Applying Gatekeeper Constraints..."
kubectl apply -f Task7/gatekeeper/constraints/privileged.yaml
kubectl apply -f Task7/gatekeeper/constraints/hostpath.yaml
kubectl apply -f Task7/gatekeeper/constraints/runasnonroot.yaml

echo "Validating secure manifests (should be admitted)..."
kubectl apply -f Task7/secure-manifests/01-secure.yaml
kubectl delete pod pod-secure-priv -n audit-zone --ignore-not-found
kubectl apply -f Task7/secure-manifests/02-secure.yaml
kubectl delete pod pod-secure-no-hostpath -n audit-zone --ignore-not-found
kubectl apply -f Task7/secure-manifests/03-secure.yaml
kubectl delete pod pod-secure-nonroot -n audit-zone --ignore-not-found

echo "OK."
