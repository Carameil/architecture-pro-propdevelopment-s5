# Отчёт по результатам анализа Kubernetes Audit Log

## Подозрительные события

1. Доступ к секретам:
   - Кто: нет событий в audit.log
   - Где: —
   - Почему подозрительно: доступ к секретам относится к высоким рискам; отсутствие событий может означать отказ в доступе или недостаточную детализацию политики аудита.

2. Привилегированные поды:
   - Кто: нет событий в audit.log
   - Комментарий: создание привилегированного пода выполнялось в сценарии, но API‑событие с признаками privileged не зафиксировано (возможна нормализация requestObject провайдером/версией API или недостаточная глубина правил аудита).

3. Использование kubectl exec в чужом поде:
   - Кто: нет событий в audit.log
   - Что делал: попытки через kubectl debug/ephemeral containers; не отражены как exec/create в аудит‑логе (логировалось stdout apiserver, возможен другой subresource).

4. Создание RoleBinding с правами cluster-admin:
   - Кто: minikube-user | Где: namespace secure-ops | Что: create rolebindings/escalate-binding → roleRef=ClusterRole/cluster-admin | Код: 201
   - Кто: minikube-user | Где: namespace kube-system | Что: create rolebindings/escalate-binding-kube-system → roleRef=ClusterRole/cluster-admin | Код: 201
   - К чему привело: эскалация привилегий путём привязки SA monitoring к кластерной роли cluster-admin (риск полного админ‑доступа в ns secure-ops и kube-system).

5. Удаление audit-policy.yaml:
   - Кто: нет событий в audit.log
   - Возможные последствия: отключение/ослабление аудита; отсутствие записи объяснимо тем, что удаление выполнялось внутри привилегированного pod через файловую систему хоста (не API‑вызов).

## Вывод

- Зафиксированы события эскалации RBAC до cluster-admin в ns secure-ops и kube-system (minikube-user).
- Доступ к секретам, exec/ephemeral‑доступ и создание привилегированных pod’ов в текущем журнале не обнаружены.
- Рекомендации: ужесточить правила аудита (RequestResponse для pods/create с детекцией privileged, pods/exec и pods/ephemeralcontainers; логи писать в файл), запретить cluster-admin для сервис‑аккаунтов, включить alert’ы на создание RoleBinding/ClusterRoleBinding с roleRef=cluster-admin.