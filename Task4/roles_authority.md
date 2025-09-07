# Роли и полномочия для Kubernetes RBAC в PropDevelopment

## Namespace-план по доменам компании:
- **sales** — витрина продаж, туры, онлайн-сделки  
- **owners** — сервисы ЖКУ для собственников
- **data** — хранилище данных и аналитика
- **finance** — бухгалтерский учёт
- **platform** — кластерные операции (SRE/DevOps)

| Роль | Права роли | Группы пользователей |
| --- | --- | --- |
| **namespace-viewer** | **Scope**: Namespace<br/>**Verbs**: get, list, watch<br/>**Resources**: pods, pods/log, services, endpoints, ingresses, configmaps, events, deployments, replicasets, statefulsets, jobs, cronjobs, horizontalpodautoscalers | **Аудиторы** — просмотр ресурсов в своих доменах<br/>**Бизнес-аналитики** — мониторинг состояния приложений<br/>**Менеджеры** — контроль развёртываний (только чтение) |
| **namespace-configurator** | **Scope**: Namespace<br/>**Verbs**: get, list, watch, create, update, patch, delete<br/>**Resources**: deployments, replicasets, statefulsets, daemonsets, services, endpoints, ingresses, configmaps, jobs, cronjobs, horizontalpodautoscalers, poddisruptionbudgets<br/>**Исключения**: НЕТ доступа к secrets | **Разработчики** — развёртывание приложений в своих доменах<br/>**DevOps-инженеры** — настройка сервисов (без секретов)<br/>**Инженеры по эксплуатации** — управление рабочими нагрузками |
| **namespace-secret-viewer** | **Scope**: Namespace<br/>**Verbs**: get, list<br/>**Resources**: secrets | **Специалисты по ИБ** — доступ к секретам для аудита<br/>**Старшие DevOps-инженеры** — ограниченный доступ к секретам при отладке<br/>**Владельцы продуктов** — просмотр конфигураций (по согласованию) |
| **cluster-readonly** | **Scope**: Cluster-wide<br/>**Verbs**: get, list, watch<br/>**Resources**: nodes, namespaces, pods, services, deployments, persistentvolumes, storageclasses, events, roles, rolebindings, clusterroles, clusterrolebindings, customresourcedefinitions | **SRE/NOC** — мониторинг всего кластера<br/>**Системные администраторы** — обзор инфраструктуры<br/>**Архитекторы** — анализ состояния кластера |
