#!/usr/bin/env bash
set -euo pipefail

AUDIT_LOG=${1:-/var/log/audit.log}
OUT_DIR=${2:-.}

mkdir -p "$OUT_DIR"

echo "Фильтрация подозрительных событий из: $AUDIT_LOG"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq не найден. Установите jq и повторите попытку." >&2
  exit 1
fi

SECRETS_JSON="$OUT_DIR/secrets_access.json"
EXEC_JSON="$OUT_DIR/exec_usage.json"
PRIV_PODS_JSON="$OUT_DIR/privileged_pods.json"
RBAC_ESC_JSON="$OUT_DIR/rbac_escalations.json"

jq 'select(.objectRef.resource=="secrets" and .verb=="get")' "$AUDIT_LOG" > "$SECRETS_JSON" || true
jq 'select(.verb=="create" and .objectRef.subresource=="exec")' "$AUDIT_LOG" > "$EXEC_JSON" || true
jq 'select(.objectRef.resource=="pods" and (.requestObject.spec.containers[]?.securityContext.privileged==true))' "$AUDIT_LOG" > "$PRIV_PODS_JSON" || true
jq 'select((.objectRef.resource=="rolebindings" or .objectRef.resource=="clusterrolebindings") and (.requestObject.roleRef.name=="cluster-admin"))' "$AUDIT_LOG" > "$RBAC_ESC_JSON" || true

echo "Готово:"
ls -lh "$SECRETS_JSON" "$EXEC_JSON" "$PRIV_PODS_JSON" "$RBAC_ESC_JSON" 2>/dev/null || true


