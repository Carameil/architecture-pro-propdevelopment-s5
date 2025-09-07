#!/usr/bin/env bash
set -euo pipefail

echo "Applying namespace with PodSecurity restricted..."
kubectl apply -f Task7/01-create-namespace.yaml

echo "Testing insecure manifests (should be denied by PodSecurity/Gatekeeper)..."
set +e
kubectl apply -f Task7/insecure-manifests/01-privileged-pod.yaml && echo "ERROR: privileged allowed" || echo "OK: privileged denied"
kubectl apply -f Task7/insecure-manifests/02-hostpath-pod.yaml && echo "ERROR: hostPath allowed" || echo "OK: hostPath denied"
kubectl apply -f Task7/insecure-manifests/03-root-user-pod.yaml && echo "ERROR: root user allowed" || echo "OK: root user denied"
set -e

echo "Done."
