# Evidence & Screenshot Checklist (Chapter3)

Muc tieu: Dien cac placeholder con thieu trong `chapter3.tex`.

## A. Placeholder can dien

| # | Placeholder | Vi tri | Can thu thap |
|---|-------------|--------|--------------|
| 1 | HINH 3.1 — Kien truc 5 tang namespace | Muc 3.2 overview | So do kien truc |
| 2 | HINH 3.7 — Attacker vs allowed-client | Muc 3.5 microseg | 2 screenshot terminal: attacker timeout + allowed 200 |
| 3 | HINH 3.9 — Grafana security dashboard | Muc 3.6 observability | Panel: dropped/forwarded, vault leases, pod cpu/mem |
| 4 | HINH 3.10 — Tetragon eBPF hook | Muc 3.6 runtime | So do (chua trien khai, ghi ro du kien) |
| 5 | HINH 3.11 — Vault rotation no-downtime | Muc 3.7 verification | lease_duration 300, revoke prefix, service 200 OK |
| 6 | HINH 3.12 — Pod status final | Muc 3.7 verification | `kubectl get pods -A` o trang thai on dinh |
| 7 | HINH 3.13 — Deployment pipeline | Muc 3.8 pipeline | So do 01→02→03→04→05 + ZTA checkpoints |

## B. Lenh thu thap

```bash
# 1. Pod health
kubectl get pods -A -o wide

# 2. Hubble flow
hubble observe -n job7189-apps --verdict DROPPED --last 20
hubble observe -n job7189-apps --verdict FORWARDED --last 20

# 3. Vault lease
kubectl exec -n vault vault-0 -- vault list sys/leases/lookup/database/creds/

# 4. Rotation test
bash infras/k8s-yaml/vault-scripts/run-vault-rotation-job.sh

# 5. Kong JWT gate
curl -s http://api.job7189.com/api/recruiters/profile       # → 401
TOKEN=$(curl -s -X POST http://auth.job7189.local/realms/job7189/...)
curl -s -H "Authorization: Bearer $TOKEN" http://api.job7189.com/api/recruiters/profile  # → 200
```

## C. Rule tranh overclaim

- Neu chua deploy Prometheus/Grafana trong script chain → khong claim "tu dong full stack"
- Neu chua implement AppRole cho script 05 → khong claim "seed DB qua AppRole"
- Tetragon/Alertmanager chua co → giu nhan "du kien/chua trien khai"

## D. Luu artifact

Nen luu output vao `k8s-management/operational/evidence/chapter3/`:
- `pods-status.txt`
- `hubble-dropped.txt`
- `hubble-forwarded.txt`
- `vault-leases.txt`
- `rotation-job.log`
- `jwt-401-200.log`
