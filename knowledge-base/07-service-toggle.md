# Service Toggle — Bat/Tat UI Noi Bo

## Muc dich

Tat cac giao dien quan tri khi khong dung de tiet kiem RAM (~1.15Gi).
Kafbat (Kafka UI) da bi remove khoi pipeline (xem `infras/k8s-yaml/03-kafka.yaml` Phan 2).

## Services co the toggle

| Service | Namespace | RAM Limit | Khi nao can |
|---------|-----------|-----------|-------------|
| phpMyAdmin | management | 128Mi | Debug database |
| Kibana | monitoring | 512Mi | Xem logs, dieu tra su co |
| Grafana | monitoring | 512Mi | Xem metrics, dashboards |
| ~~Kafbat (Kafka UI)~~ | ~~management~~ | ~~128Mi~~ | (removed) |

## Script su dung

```bash
# Xem trang thai hien tai
./scripts/toggle-internal-ui.sh status

# Tat tat ca UI noi bo
./scripts/toggle-internal-ui.sh off

# Bat chi phpMyAdmin
./scripts/toggle-internal-ui.sh on phpmyadmin

# Bat chi Kibana + Grafana
./scripts/toggle-internal-ui.sh on kibana grafana

# Bat tat ca
./scripts/toggle-internal-ui.sh on
```

## RAM tiet kiem

| Kich ban | Tiet kiem |
|----------|----------|
| Tat tat ca 3 UI | ~1.15Gi |
| Tat chi Kibana + Grafana | ~1Gi |
| Tat chi phpMyAdmin | ~128Mi |

## Goi y

- **Khi deploy/debug**: bat phpMyAdmin + Kibana
- **Khi demo/bao ve**: bat Grafana + Kibana (screenshot dashboards)
- **Khi khong dung**: tat het → tiet kiem ~1.15Gi cho Laravel services
- **Mac dinh khi deploy**: nen tat phpMyAdmin (script 02 co the them flag)
