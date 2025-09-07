#!/usr/bin/env bash
set -euo pipefail

echo "=== Создание ролей для PropDevelopment RBAC ==="

# Функция для применения namespace-роли
apply_ns_role () {
    local ns="$1" name="$2" yaml="$3"
    echo "Применение роли $name в namespace $ns"
    sed "s/PLACEHOLDER_NS/${ns}/g" <<<"$yaml" | kubectl apply -f -
}

# Роль: namespace-viewer (только чтение в namespace)
ROLE_VIEWER_YAML='
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: 
  name: namespace-viewer
  namespace: PLACEHOLDER_NS
rules:
- apiGroups: ["", "apps", "batch", "autoscaling", "networking.k8s.io"]
  resources: 
    - pods
    - pods/log
    - services
    - endpoints
    - ingresses
    - configmaps
    - events
    - deployments
    - replicasets
    - statefulsets
    - jobs
    - cronjobs
    - horizontalpodautoscalers
  verbs: ["get", "list", "watch"]
'

# Роль: namespace-configurator (настройка приложений, без секретов)
ROLE_CONFIGURATOR_YAML='
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: 
  name: namespace-configurator
  namespace: PLACEHOLDER_NS
rules:
- apiGroups: ["", "apps", "batch", "autoscaling", "policy", "networking.k8s.io"]
  resources: 
    - deployments
    - replicasets
    - statefulsets
    - daemonsets
    - services
    - endpoints
    - ingresses
    - configmaps
    - jobs
    - cronjobs
    - horizontalpodautoscalers
    - poddisruptionbudgets
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
'

# Роль: namespace-secret-viewer (доступ к секретам в namespace)
ROLE_SECRET_VIEWER_YAML='
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: 
  name: namespace-secret-viewer
  namespace: PLACEHOLDER_NS
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
'

# ClusterRole: cluster-readonly (чтение всего кластера)
CLUSTERROLE_READONLY_YAML='
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata: 
  name: cluster-readonly
rules:
- apiGroups: ["", "apps", "batch", "storage.k8s.io", "rbac.authorization.k8s.io", 
              "networking.k8s.io", "apiextensions.k8s.io", "autoscaling"]
  resources: 
    - nodes
    - namespaces
    - pods
    - pods/log
    - services
    - endpoints
    - ingresses
    - deployments
    - replicasets
    - statefulsets
    - daemonsets
    - jobs
    - cronjobs
    - persistentvolumes
    - persistentvolumeclaims
    - storageclasses
    - events
    - roles
    - rolebindings
    - clusterroles
    - clusterrolebindings
    - customresourcedefinitions
  verbs: ["get", "list", "watch"]
'

# Применение namespace-ролей для всех доменов
echo "Создание namespace-ролей..."
for ns in sales owners data finance; do
    apply_ns_role "$ns" namespace-viewer "$ROLE_VIEWER_YAML"
    apply_ns_role "$ns" namespace-configurator "$ROLE_CONFIGURATOR_YAML"
    apply_ns_role "$ns" namespace-secret-viewer "$ROLE_SECRET_VIEWER_YAML"
done

# Применение cluster-роли
echo "Создание cluster-роли..."
kubectl apply -f <(echo "$CLUSTERROLE_READONLY_YAML")

echo ""
echo "=== Роли созданы ==="
echo "Проверка созданных ролей:"
echo "  kubectl get roles --all-namespaces"
echo "  kubectl get clusterroles | grep cluster-readonly"
echo ""
