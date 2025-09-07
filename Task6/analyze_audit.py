#!/usr/bin/env python3
import json
import sys
import os
from typing import Any, Dict, List


def load_audit_events(audit_log_path: str) -> List[Dict[str, Any]]:
    events: List[Dict[str, Any]] = []
    with open(audit_log_path, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                evt = json.loads(line)
                if isinstance(evt, dict) and 'kind' in evt and evt.get('kind') == 'Event' or 'auditID' in evt:
                    events.append(evt)
            except Exception:
                # Skip non-JSON or unrelated log lines
                continue
    return events


def any_container_privileged(request_object: Dict[str, Any]) -> bool:
    try:
        spec = request_object.get('spec') or {}
        containers = spec.get('containers') or []
        for c in containers:
            sc = (c or {}).get('securityContext') or {}
            if sc.get('privileged') is True:
                return True
    except Exception:
        return False
    return False


def extract_suspicious(events: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    suspicious: List[Dict[str, Any]] = []
    for e in events:
        try:
            verb = e.get('verb')
            obj = e.get('objectRef') or {}
            ns = obj.get('namespace')
            resource = obj.get('resource')
            subresource = obj.get('subresource')
            req_obj = e.get('requestObject') or {}
            user = (e.get('user') or {}).get('username')
            user_agent = e.get('userAgent')
            stage = e.get('stage')
            uri = e.get('requestURI')
            source_ips = e.get('sourceIPs') or []
            status = (e.get('responseStatus') or {}).get('code')

            base = {
                'verb': verb,
                'namespace': ns,
                'resource': resource,
                'subresource': subresource,
                'objectRef': obj,
                'user': user,
                'userAgent': user_agent,
                'stage': stage,
                'requestURI': uri,
                'sourceIPs': source_ips,
                'responseCode': status,
            }

            # 1) Access to secrets
            if resource == 'secrets' and verb == 'get':
                suspicious.append({'category': 'secrets_access', **base})
                continue

            # 2) kubectl exec into pods
            if subresource == 'exec' and verb == 'create':
                # Detect attempts to remove audit policy via exec command
                cmd = (req_obj or {}).get('command') or []
                has_audit_keyword = any('audit-policy' in str(x) for x in cmd)
                suspicious.append({'category': 'exec_usage', 'command': cmd, 'touches_audit_policy': has_audit_keyword, **base})
                continue

            # 3) Privileged pod creation
            if resource == 'pods' and verb in {'create', 'update', 'patch'} and any_container_privileged(req_obj):
                suspicious.append({'category': 'privileged_pod', **base})
                continue

            # 4) RoleBinding/ClusterRoleBinding to cluster-admin
            if resource in {'rolebindings', 'clusterrolebindings'} and verb in {'create', 'update', 'patch'}:
                role_ref = (req_obj or {}).get('roleRef') or {}
                role_name = role_ref.get('name')
                if role_name == 'cluster-admin':
                    suspicious.append({'category': 'rolebinding_cluster_admin', 'roleRef': role_ref, **base})
                    continue

            # 5) Any explicit operations mentioning audit-policy
            if uri and 'audit-policy' in uri:
                suspicious.append({'category': 'audit_policy_change', **base})
                continue
        except Exception:
            # resilient parsing
            continue
    return suspicious


def write_json(path: str, data: Any) -> None:
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def generate_report(path: str, suspicious: List[Dict[str, Any]]) -> None:
    by_cat: Dict[str, List[Dict[str, Any]]] = {}
    for s in suspicious:
        by_cat.setdefault(s.get('category', 'unknown'), []).append(s)

    lines: List[str] = []
    lines.append('# Отчёт по результатам анализа Kubernetes Audit Log')
    lines.append('')
    lines.append('## Сводка по категориям')
    for cat in sorted(by_cat.keys()):
        lines.append(f'- {cat}: {len(by_cat[cat])}')
    lines.append('')
    lines.append('## Подозрительные события')
    lines.append('')

    # 1. Доступ к секретам
    lines.append('1. Доступ к секретам:')
    for s in by_cat.get('secrets_access', [])[:10]:
        lines.append(f'   - Кто: {s.get("user")} | Где: ns={s.get("namespace")} | URI: {s.get("requestURI")} | code={s.get("responseCode")}')
    if not by_cat.get('secrets_access'):
        lines.append('   - Событий не обнаружено')
    lines.append('')

    # 2. Привилегированные поды
    lines.append('2. Привилегированные поды:')
    for s in by_cat.get('privileged_pod', [])[:10]:
        lines.append(f'   - Кто: {s.get("user")} | ns={s.get("namespace")} | {s.get("verb")} {s.get("resource")} | code={s.get("responseCode")}')
    if not by_cat.get('privileged_pod'):
        lines.append('   - Событий не обнаружено')
    lines.append('')

    # 3. Использование kubectl exec
    lines.append('3. Использование kubectl exec в чужом поде:')
    for s in by_cat.get('exec_usage', [])[:10]:
        cmd = s.get('command')
        lines.append(f'   - Кто: {s.get("user")} | ns={s.get("namespace")} | cmd={cmd} | code={s.get("responseCode")}')
    if not by_cat.get('exec_usage'):
        lines.append('   - Событий не обнаружено')
    lines.append('')

    # 4. Создание RoleBinding с правами cluster-admin
    lines.append('4. Создание RoleBinding с правами cluster-admin:')
    for s in by_cat.get('rolebinding_cluster_admin', [])[:10]:
        lines.append(f'   - Кто: {s.get("user")} | ns={s.get("namespace")} | roleRef={s.get("roleRef")} | code={s.get("responseCode")}')
    if not by_cat.get('rolebinding_cluster_admin'):
        lines.append('   - Событий не обнаружено')
    lines.append('')

    # 5. Удаление/изменение audit-policy.yaml
    lines.append('5. Удаление/изменение audit-policy.yaml:')
    for s in by_cat.get('audit_policy_change', [])[:10]:
        lines.append(f'   - Кто: {s.get("user")} | URI: {s.get("requestURI")} | code={s.get("responseCode")}')
    if not by_cat.get('audit_policy_change'):
        lines.append('   - Событий не обнаружено (возможна попытка через exec, см. п.3)')
    lines.append('')

    lines.append('## Вывод')
    lines.append('Обнаружены и классифицированы ключевые события по аудиту. См. детали выше и полный JSON в audit-extract.json.')

    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')


def main() -> None:
    if len(sys.argv) < 2:
        print('Usage: analyze_audit.py <path_to_audit.log>')
        sys.exit(1)

    audit_log_path = sys.argv[1]
    events = load_audit_events(audit_log_path)
    suspicious = extract_suspicious(events)

    base_dir = os.path.dirname(os.path.abspath(audit_log_path))
    write_json(os.path.join(base_dir, 'audit-extract.json'), suspicious)
    generate_report(os.path.join(base_dir, 'analysis.md'), suspicious)
    print(f'Wrote: {os.path.join(base_dir, "audit-extract.json")}')
    print(f'Wrote: {os.path.join(base_dir, "analysis.md")}')


if __name__ == '__main__':
    main()


