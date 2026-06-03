#!/bin/bash
# =========================================================================
# STEP 3E: Revert identity-service + job-service drift do Agent k8s-edit
# Cách: copy spec.template từ communication-service (đã clean) → patch
# substitute tên+image+labels cho identity/job. Webhook tự inject vault-agent.
# Tránh helmfile sync vì Sigstore CIP fail-on-resolve tag image.
# =========================================================================
set -u
 
BACKUP_DIR="${HOME}/vault-recovery-backups/$(date +%Y%m%d-%H%M%S)-step3e"
mkdir -p "$BACKUP_DIR"
echo "Backup dir: $BACKUP_DIR"
 
# Lấy template từ communication-service (đã 4/4 Running, đúng chart shape)
kubectl get deploy communication-service -n job7189-apps -o yaml > "$BACKUP_DIR/template-communication.yaml"
 
for SVC in identity-service job-service; do
  echo
  echo "===== Fix $SVC ====="
 
  # Backup current deployment + extract current app image (digest format)
  kubectl get deploy "$SVC" -n job7189-apps -o yaml > "$BACKUP_DIR/before-$SVC.yaml"
  APP_IMG=$(kubectl get deploy "$SVC" -n job7189-apps -o jsonpath='{.spec.template.spec.containers[?(@.name=="app")].image}')
  if [ -z "$APP_IMG" ]; then
    APP_IMG=$(kubectl get pod -n job7189-apps -l app="$SVC" -o jsonpath='{.items[0].spec.containers[?(@.name=="app")].image}')
  fi
  echo "  Current $SVC app image: $APP_IMG"
 
  # Build new spec.template từ communication-service template, substitute tên + image
  python3 - <<PYEOF
import yaml, sys, json
 
with open("$BACKUP_DIR/template-communication.yaml") as f:
    tmpl = yaml.safe_load(f)
with open("$BACKUP_DIR/before-$SVC.yaml") as f:
    cur = yaml.safe_load(f)
 
SVC = "$SVC"
APP_IMG = "$APP_IMG"
 
new_template = tmpl["spec"]["template"]
 
# Substitute communication-service → $SVC trong toàn bộ template (labels, configmap, serviceAccount)
s = yaml.dump(new_template)
s = s.replace("communication-service", SVC)
new_template = yaml.safe_load(s)
 
# Set app container image về digest của $SVC
for c in new_template["spec"]["containers"]:
    if c["name"] == "app":
        c["image"] = APP_IMG
 
# Loại bỏ webhook-injected fields trong template (vault-agent container + vault-agent-init initContainer)
# để webhook tự inject lại đúng dựa trên annotation
new_template["spec"]["containers"] = [c for c in new_template["spec"]["containers"] if c["name"] != "vault-agent"]
new_template["spec"]["initContainers"] = [c for c in new_template["spec"]["initContainers"] if c["name"] != "vault-agent-init"]
new_template["spec"]["volumes"] = [v for v in new_template["spec"]["volumes"] if v["name"] not in ("vault-secrets","home")]
 
# Loại bỏ annotation/labels do webhook inject ra
ann = new_template.get("metadata",{}).get("annotations",{})
for k in list(ann.keys()):
    if k.startswith("vault.hashicorp.com/log-") or k.startswith("vault.hashicorp.com/preserve-"):
        del ann[k]
 
# Apply spec.template lên deployment hiện tại (giữ nguyên metadata, replicas, strategy)
cur["spec"]["template"] = new_template
 
# Cleanup status + managedFields + resourceVersion
cur.pop("status", None)
cur["metadata"].pop("managedFields", None)
cur["metadata"].pop("resourceVersion", None)
cur["metadata"].pop("uid", None)
cur["metadata"].pop("creationTimestamp", None)
cur["metadata"].pop("generation", None)
 
with open("$BACKUP_DIR/new-$SVC.yaml","w") as f:
    yaml.dump(cur, f, default_flow_style=False)
print(f"  Wrote $BACKUP_DIR/new-$SVC.yaml")
PYEOF
 
  # Apply
  kubectl apply -f "$BACKUP_DIR/new-$SVC.yaml"
done
 
echo
echo "===== Wait + verify ====="
for SVC in identity-service job-service; do
  kubectl rollout status deployment "$SVC" -n job7189-apps --timeout=180s &
done
wait
 
echo
echo "===== Tổng kết ====="
kubectl get pod -n job7189-apps -o wide | grep -E "(identity|job)-service"
echo
echo "Container annotations + init containers (kỳ vọng inject=true + 3 init + 4 main):"
for SVC in identity-service job-service; do
  POD=$(kubectl get pod -n job7189-apps -l app="$SVC" -o jsonpath='{.items[0].metadata.name}')
  INJECT=$(kubectl get deploy "$SVC" -n job7189-apps -o jsonpath='{.spec.template.metadata.annotations.vault\.hashicorp\.com/agent-inject}')
  INIT=$(kubectl get pod -n job7189-apps "$POD" -o jsonpath='{range .spec.initContainers[*]}{.name}{","}{end}')
  MAIN=$(kubectl get pod -n job7189-apps "$POD" -o jsonpath='{range .spec.containers[*]}{.name}{","}{end}')
  READY=$(kubectl get pod -n job7189-apps "$POD" -o jsonpath='{range .status.containerStatuses[?(@.ready==true)]}{.name}{","}{end}')
  echo "  $SVC ($POD): inject=$INJECT | INIT=$INIT | MAIN=$MAIN | READY=$READY"
done
 
echo
echo "===== Backup tại: $BACKUP_DIR ====="
ls -la "$BACKUP_DIR"
echo "===== DONE ====="
 
