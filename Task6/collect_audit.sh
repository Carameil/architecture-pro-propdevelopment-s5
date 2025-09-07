#!/usr/bin/env bash
set -euo pipefail

OUT=${1:-audit.log}

echo "Сбор audit лога API-сервера в: $OUT"
APISERVER_POD=$(kubectl -n kube-system get pods -l component=kube-apiserver -o jsonpath='{.items[0].metadata.name}')
if [[ -z "$APISERVER_POD" ]]; then
  echo "Не найден pod kube-apiserver в kube-system" >&2
  exit 1
fi

kubectl -n kube-system logs "$APISERVER_POD" > "$OUT"
echo "OK: $OUT"


