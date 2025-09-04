#!/usr/bin/env bash
set -euo pipefail

echo "=== Связывание пользователей с ролями (PropDevelopment RBAC) ==="

# Sales domain bindings
echo "Создание RoleBinding для домена sales..."
kubectl -n sales apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: 
  name: rb-viewer-sales
  namespace: sales
subjects:
- kind: ServiceAccount
  name: viewer-sales
  namespace: sales
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-viewer
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: 
  name: rb-configurator-sales
  namespace: sales
subjects:
- kind: ServiceAccount
  name: configurator-sales
  namespace: sales
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-configurator
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: 
  name: rb-secviewer-sales
  namespace: sales
subjects:
- kind: ServiceAccount
  name: secviewer-sales
  namespace: sales
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-secret-viewer
YAML

# Owners domain bindings
echo "Создание RoleBinding для домена owners..."
kubectl -n owners apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: 
  name: rb-viewer-owners
  namespace: owners
subjects:
- kind: ServiceAccount
  name: viewer-owners
  namespace: owners
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-viewer
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: 
  name: rb-configurator-owners
  namespace: owners
subjects:
- kind: ServiceAccount
  name: configurator-owners
  namespace: owners
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-configurator
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: 
  name: rb-secviewer-owners
  namespace: owners
subjects:
- kind: ServiceAccount
  name: secviewer-owners
  namespace: owners
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-secret-viewer
YAML

# Data domain bindings
echo "Создание RoleBinding для домена data..."
kubectl -n data apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: 
  name: rb-viewer-data
  namespace: data
subjects:
- kind: ServiceAccount
  name: viewer-data
  namespace: data
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-viewer
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: 
  name: rb-configurator-data
  namespace: data
subjects:
- kind: ServiceAccount
  name: configurator-data
  namespace: data
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-configurator
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: 
  name: rb-secviewer-data
  namespace: data
subjects:
- kind: ServiceAccount
  name: secviewer-data
  namespace: data
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-secret-viewer
YAML

# Cluster-wide binding для SRE
echo "Создание ClusterRoleBinding для SRE..."
kubectl apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: 
  name: crb-sre-readonly
subjects:
- kind: ServiceAccount
  name: sre-readonly
  namespace: platform
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-readonly
YAML

echo ""
echo "=== RoleBinding и ClusterRoleBinding созданы ==="
echo "Проверка привязок:"
echo "  kubectl get rolebindings --all-namespaces"
echo "  kubectl get clusterrolebindings | grep -E '(sre-readonly|platform-admin)'"
echo ""
echo "=== Тестирование доступа ==="
echo "1. Viewer может читать pods, но НЕ может читать secrets:"
echo "   kubectl --context viewer-sales -n sales get pods"
echo "   kubectl --context viewer-sales -n sales get secrets  # должно быть forbidden"
echo ""
echo "2. Configurator может создавать deployments, но НЕ может читать secrets:"
echo "   kubectl --context configurator-owners -n owners create deploy test --image=nginx --dry-run=client -o yaml"
echo "   kubectl --context configurator-owners -n owners get secrets  # должно быть forbidden"
echo ""
echo "3. Secret-viewer может читать secrets:"
echo "   kubectl --context secviewer-sales -n sales get secrets"
echo ""
echo "4. SRE может читать всё в кластере:"
echo "   kubectl --context sre-readonly get nodes"
echo "   kubectl --context sre-readonly get pods -A"
echo ""
