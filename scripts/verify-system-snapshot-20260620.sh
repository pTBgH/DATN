#!/usr/bin/env bash
set -Eeuo pipefail

KUBECTL="${KUBECTL:-kubectl}"
REGISTRY_URL="${REGISTRY_URL:-}"
NODES=(7189srv01 7189srv02 7189srv03 7189srv05)

section() {
  printf '\n== %s ==\n' "$1"
}

run() {
  printf '+ %s\n' "$*"
  "$@" || true
}

jsonpath() {
  local label="$1"
  local path="$2"
  shift 2
  printf '+ %s\n' "$label"
  "$KUBECTL" "$@" -o "jsonpath=${path}" || true
  printf '\n'
}

section "Cluster nodes"
run "$KUBECTL" get nodes -o wide

section "Node OS versions"
printf 'kubectl node OS summary is authoritative enough for KB snapshot; SSH check is optional.\n'
if [[ "${CHECK_NODE_OS:-0}" == "1" ]]; then
  for node in "${NODES[@]}"; do
    printf '\n-- %s --\n' "$node"
    run ssh "$node" 'cat /etc/os-release'
  done
else
  printf 'Set CHECK_NODE_OS=1 to run: ssh <node> cat /etc/os-release\n'
  printf 'Known from migration/02-target-architecture.md: 7189srv05 = Ubuntu 24.04 LTS\n'
fi

section "Tetragon v1.7.0 DaemonSet and policies"
run "$KUBECTL" -n kube-system get ds tetragon -o wide
jsonpath "tetragon ready/desired" '{.status.numberReady}/{.status.desiredNumberScheduled}' -n kube-system get ds tetragon
run "$KUBECTL" get tracingpolicynamespaced -A
printf '+ tracing policy actions\n'
"$KUBECTL" get tracingpolicynamespaced -A -o yaml | grep -E 'name: block-suspicious-exec|action: (Sigkill|Post)|namespace:' || true

section "Cilium mTLS and WireGuard"
jsonpath "mesh-auth-enabled" '{.data.mesh-auth-enabled}' -n kube-system get cm cilium-config
jsonpath "enable-wireguard" '{.data.enable-wireguard}' -n kube-system get cm cilium-config

section "Threat intel"
run "$KUBECTL" -n security-cdm get cronjob threat-intel-refresh
printf '+ threat-intel CIDR count\n'
"$KUBECTL" get ciliumcidrgroup threat-intel-firehol \
  -o jsonpath='{range .spec.externalCIDRs[*]}{.}{"\n"}{end}' | wc -l || true
run "$KUBECTL" get ccnp cnp-threat-intel-egress-deny -o yaml

section "PDP and low-trust Vault CNP"
run "$KUBECTL" -n security get deploy,pod,svc -l app=zta-pdp
run "$KUBECTL" get ns pdp-system
jsonpath "zta-pdp env" '{.spec.template.spec.containers[0].env}' -n security get deploy zta-pdp
run "$KUBECTL" get cnp -A
run "$KUBECTL" -n vault get cnp cnp-block-low-trust-to-vault -o yaml

section "Trivy Operator"
run "$KUBECTL" -n security-cdm get deploy,pod
run "$KUBECTL" get vulnerabilityreport -A

section "Cosign ClusterImagePolicy"
run "$KUBECTL" get clusterimagepolicy
jsonpath "ClusterImagePolicy modes" '{range .items[*]}{.metadata.name}{" mode="}{.spec.mode}{"\n"}{end}' get clusterimagepolicy

section "Gatekeeper enforcementAction"
for kind in k8sblocklatesttag k8simagedigestrequired k8ssignedimageannotation ztablockhostmounts ztarequiredlabels ztarestrictprivileged; do
  printf '\n-- %s --\n' "$kind"
  run "$KUBECTL" get "$kind"
  jsonpath "${kind} enforcementAction" '{range .items[*]}{.metadata.name}{" enforcementAction="}{.spec.enforcementAction}{"\n"}{end}' get "$kind"
done

section "SPIRE/SPIFFE"
run "$KUBECTL" get clusterspiffeid
run "$KUBECTL" -n spire get pod

section "Host-level Docker Registry"
run "$KUBECTL" -n registry get pod,svc,deploy,sts,ds,job,cronjob
if [[ -n "$REGISTRY_URL" ]]; then
  run curl -kfsS "${REGISTRY_URL%/}/v2/_catalog"
else
  printf 'Set REGISTRY_URL=https://<registry-host>:5443 to check host-level registry catalog.\n'
fi
