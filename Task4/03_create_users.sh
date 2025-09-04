#!/usr/bin/env bash
set -euo pipefail

echo "=== Создание пользователей (ServiceAccounts) для PropDevelopment RBAC ==="

# 1) Убедиться, что Minikube запущен
echo "Проверка статуса Minikube..."
minikube status >/dev/null 2>&1 || {
    echo "Minikube не запущен. Запускаем..."
    minikube start
}
echo "✓ Minikube активен"

# 2) Создание namespace по доменам компании
echo "Создание namespace по доменам PropDevelopment..."
NS_LIST=(sales owners data finance platform)
for ns in "${NS_LIST[@]}"; do
    if kubectl get ns "$ns" >/dev/null 2>&1; then
        echo "  Namespace $ns уже существует"
    else
        kubectl create ns "$ns"
        echo "  ✓ Создан namespace: $ns"
    fi
done

# 3) Создание ServiceAccounts как "пользователей"
echo "Создание ServiceAccounts..."

# Sales domain (продажи)
kubectl -n sales create sa viewer-sales --dry-run=client -o yaml | kubectl apply -f -
kubectl -n sales create sa configurator-sales --dry-run=client -o yaml | kubectl apply -f -
kubectl -n sales create sa secviewer-sales --dry-run=client -o yaml | kubectl apply -f -
echo "  ✓ ServiceAccounts для домена sales созданы"

# Owners domain (ЖКУ)
kubectl -n owners create sa viewer-owners --dry-run=client -o yaml | kubectl apply -f -
kubectl -n owners create sa configurator-owners --dry-run=client -o yaml | kubectl apply -f -
kubectl -n owners create sa secviewer-owners --dry-run=client -o yaml | kubectl apply -f -
echo "  ✓ ServiceAccounts для домена owners созданы"

# Data domain (аналитика)
kubectl -n data create sa viewer-data --dry-run=client -o yaml | kubectl apply -f -
kubectl -n data create sa configurator-data --dry-run=client -o yaml | kubectl apply -f -
kubectl -n data create sa secviewer-data --dry-run=client -o yaml | kubectl apply -f -
echo "  ✓ ServiceAccounts для домена data созданы"

# Platform domain (SRE)
kubectl -n platform create sa sre-readonly --dry-run=client -o yaml | kubectl apply -f -
echo "  ✓ ServiceAccounts для домена platform созданы"

# 4) Создание kubeconfig контекстов для каждого SA
echo "Создание kubeconfig контекстов..."
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
APISERVER_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

make_ctx () {
    local ns="$1" sa="$2" ctx="$3" user="$4"
    
    # Попытка создать token (K8s >=1.24)
    if kubectl -n "$ns" create token "$sa" --duration=8760h >/tmp/token-"$sa".txt 2>/dev/null; then
        TOKEN=$(cat /tmp/token-"$sa".txt)
        rm -f /tmp/token-"$sa".txt
    else
        # Fallback: legacy secret-based token
        kubectl -n "$ns" create secret generic "${sa}-token" \
            --type kubernetes.io/service-account-token \
            --from-literal=placeholder=1 >/dev/null 2>&1 || true
        kubectl -n "$ns" patch sa "$sa" \
            -p '{"secrets":[{"name":"'"${sa}-token"'"}]}' >/dev/null 2>&1 || true
        
        # Ждём появления токена
        sleep 2
        SECRET=$(kubectl -n "$ns" get sa "$sa" -o jsonpath='{.secrets[0].name}' 2>/dev/null || echo "${sa}-token")
        TOKEN=$(kubectl -n "$ns" get secret "$SECRET" -o jsonpath='{.data.token}' 2>/dev/null | base64 -d)
    fi

    # Создание kubeconfig контекста
    kubectl config set-credentials "$user" --token="$TOKEN" >/dev/null
    kubectl config set-context "$ctx" --cluster="$CLUSTER_NAME" --user="$user" --namespace="$ns" >/dev/null
    echo "  ✓ Создан контекст: $ctx для SA $ns/$sa"
}

# Sales domain contexts
make_ctx sales viewer-sales viewer-sales user-viewer-sales
make_ctx sales configurator-sales configurator-sales user-configurator-sales  
make_ctx sales secviewer-sales secviewer-sales user-secviewer-sales

# Owners domain contexts
make_ctx owners viewer-owners viewer-owners user-viewer-owners
make_ctx owners configurator-owners configurator-owners user-configurator-owners
make_ctx owners secviewer-owners secviewer-owners user-secviewer-owners

# Data domain contexts  
make_ctx data viewer-data viewer-data user-viewer-data
make_ctx data configurator-data configurator-data user-configurator-data

# Platform domain contexts
make_ctx platform sre-readonly sre-readonly user-sre-readonly

echo ""
echo "=== Пользователи и контексты созданы ==="
echo "Примеры команд для проверки:"
echo "  kubectl --context viewer-sales -n sales get pods"
echo "  kubectl --context configurator-owners -n owners get deployments"
echo "  kubectl --context sre-readonly get nodes"
echo ""
