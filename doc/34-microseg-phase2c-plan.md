# Microsegmentation Phase 2C — Extend CNP coverage to infrastructure namespaces

**Status:** Draft (this PR).
**Owner:** Bao (DATN), assisted by Devin.
**Reference:** `doc/20-5w1h-policy-matrix.md`, `doc/33-zta-gap-analysis.md`,
`doc/18-daas-classification.md`.

---

## 1. Background

After Session 1 + 2, the cluster has:

- `cilium-policies/00-default-deny.yaml` valid on `job7189-apps` (PR #13).
- Per-ns CNP YAML authored for `data`, `vault`, `security`, `monitoring`,
  `gateway`, `management`, `registry` — files 10–16 in
  `infras/k8s-yaml/cilium-policies/namespaces/`.
- `trivy-operator/02-cnp.yaml` for the `security-cdm` namespace (Trivy +
  threat-intel).

What is **still missing** is per-ns CNP for the infrastructure namespaces
shipped by 3rd-party Helm charts:

| Namespace | Owner workload | Risk |
|-----------|----------------|------|
| `kube-system` | CoreDNS, Cilium, kube-proxy, control-plane static pods | **T0 — highest** |
| `cert-manager` | cert-manager (issuer), webhook, cainjector | T2 |
| `cosign-system` | sigstore policy-controller (image verification) | T2 |
| `gatekeeper-system` | OPA Gatekeeper controller-manager + audit | T2 |
| `ingress-nginx` | ingress-nginx-controller | T2 |
| `spire` | spire-server (StatefulSet), spire-agent (DaemonSet) | T1 |
| `local-path-storage` | local-path-provisioner (Rancher) | T3 |

This PR adds **draft YAML** for each of these namespaces. The label
"draft" is deliberate: the policies are based on the well-known traffic
patterns of each chart, not on observed Hubble flow data — operator
must validate before applying.

---

## 2. Where the drafts live

| File | Namespace | Default-deny? | Notes |
|------|-----------|---------------|-------|
| `namespaces/17-cert-manager.yaml` | `cert-manager` | Yes (ns-wide) | apiserver + webhook callback + Prom scrape |
| `namespaces/18-cosign-system.yaml` | `cosign-system` | Yes (ns-wide) | apiserver + admission webhook + signature pull from registry |
| `namespaces/19-gatekeeper-system.yaml` | `gatekeeper-system` | Yes (ns-wide) | apiserver + admission webhook + kubelet probes |
| `namespaces/20-ingress-nginx.yaml` | `ingress-nginx` | Yes (ns-wide) | world ingress 80/443 + apiserver + per-upstream egress |
| `namespaces/21-spire.yaml` | `spire` | Yes (ns-wide) | agent↔server :8081 + apiserver + Prom scrape |
| `namespaces/22-local-path-storage.yaml` | `local-path-storage` | Yes (ns-wide) | apiserver only |
| `namespaces/23-kube-system.yaml` | `kube-system` | **NO ns-wide deny** | CoreDNS allow-only — see §5 |

All drafts use the **same default-deny pattern** as files 10–16:

```yaml
spec:
  endpointSelector: {}
  ingress:
  - fromEndpoints: [matchLabels: {cilium.zta/marker: umbrella-deny}]
  egress:
  - toEndpoints: [matchLabels: {cilium.zta/marker: umbrella-deny}]
```

(The "umbrella-deny" marker label intentionally never matches any real
pod — Cilium schema-validates the rule as VALID=True but the rule's
allow list is empty, so the net effect is namespace-wide default-deny.)

---

## 3. Validation workflow

### Step 0: capture current flow baseline

```bash
bash zta-microseg-step1-flow-capture.sh        # 10 min default
# Outputs to ~/zta-microseg/<TS>/
```

### Step 1: dry-run + drop-flow inventory

```bash
bash scripts/zta-microseg-step2-validate.sh
# Outputs to ~/zta-microseg-validate/<TS>/
```

The validator script is **100% read-only**. It produces:

- `01-ns-inventory.md` — actual pods + labels per ns (verify against
  draft selectors).
- `02-existing-cnp.md` — CNP already in each ns.
- `03-dry-run-apply.md` — `kubectl apply --dry-run=server` for every
  draft file (catches schema bugs).
- `04-recent-hubble-drops.md` — DROPPED flows in last 30 min, grouped
  by namespace (identifies legitimate flows we'd block).
- `05-policy-vs-pods.md` — heuristic match of draft selectors against
  live pod labels (catches label drift).
- `06-recommendation.md` — per-ns wave-based apply order with risk tier.

### Step 2: review + patch

For every DROPPED flow that is legitimate (e.g. Prometheus scrape that
already works today), add an allow rule to the corresponding draft YAML.
Re-run the validator. Iterate until `04-recent-hubble-drops.md` only
shows expected denies (attacker probes, leftover misconfig).

### Step 3: apply wave by wave

```bash
# Wave 1 (lowest risk first)
bash infras/k8s-yaml/cilium-policies/namespaces/apply-zta-namespace-policies.sh \
  --namespace=local-path-storage --apply
# Wait 30 min, watch Hubble. Then:
bash infras/k8s-yaml/cilium-policies/namespaces/apply-zta-namespace-policies.sh \
  --namespace=registry --apply
# ... continue per ORDER in apply-zta-namespace-policies.sh
```

The script verifies pod health after each apply and surfaces any
CrashLoopBackOff. If anything breaks, rollback immediately:

```bash
bash apply-zta-namespace-policies.sh --namespace=<ns> --rollback
```

---

## 4. Assumptions baked into each draft

The drafts assume **stock Helm chart label conventions**. If your
deployment customised any of these, the draft selectors won't match and
the corresponding allow rule will silently no-op.

| Workload | Selector used | Stock chart? |
|----------|---------------|--------------|
| cert-manager controller | `app.kubernetes.io/name=cert-manager` | jetstack/cert-manager |
| cert-manager webhook | `app.kubernetes.io/name=webhook` | jetstack/cert-manager |
| cert-manager cainjector | `app.kubernetes.io/name=cainjector` | jetstack/cert-manager |
| sigstore policy-controller | `app.kubernetes.io/name=policy-controller` | sigstore/policy-controller |
| Gatekeeper controller | `control-plane=controller-manager` | open-policy-agent/gatekeeper |
| Gatekeeper audit | `control-plane=audit-controller` | open-policy-agent/gatekeeper |
| ingress-nginx | `app.kubernetes.io/name=ingress-nginx` | kubernetes/ingress-nginx |
| SPIRE server | `app.kubernetes.io/name=server` | spiffe/helm-charts-hardened |
| SPIRE agent | `app.kubernetes.io/name=agent` | spiffe/helm-charts-hardened |
| SPIRE controller-manager | `app.kubernetes.io/name=controller-manager` | spiffe/helm-charts-hardened |
| local-path-provisioner | `app=local-path-provisioner` | rancher/local-path-provisioner |
| CoreDNS | `k8s-app=kube-dns` | kubernetes/dns |

If any pod fails to match in the validator output (`05-policy-vs-pods.md`
shows mismatch), update the selector in the YAML to the actual label.

---

## 5. Why `kube-system` doesn't get namespace-wide default-deny

Applying `default-deny-kube-system` would break, at minimum:

- CoreDNS ingress on :53 from every namespace (DNS lookup fails
  cluster-wide).
- Admission webhook callbacks from apiserver → every webhook tenant in
  cluster (cosign, gatekeeper, cert-manager, ingress-nginx, spire).
- Cilium agent ↔ Cilium operator ↔ Hubble relay (most run with
  `hostNetwork: true`, but agent has special semantics).
- Health probes from kubelet to anything in kube-system.

**Therefore `23-kube-system.yaml` only adds per-workload allow rules:**

1. `allow-coredns-ingress` — every pod can resolve via CoreDNS :53.
2. `allow-coredns-egress-apiserver` — CoreDNS can list Service/Endpoints.
3. `allow-prometheus-scrape-coredns` — monitoring/prometheus scrapes
   :9153.

These three rules each select only `k8s-app=kube-dns`, so the impact is
bounded to CoreDNS pods. Other pods in kube-system (kube-proxy, etcd,
controller-manager, Cilium agent) are unaffected because they run in
`hostNetwork` mode and bypass Cilium endpoint policy.

**Adding namespace-wide default-deny in kube-system requires a separate
PR with explicit ramp-up:** at minimum 24h of green Hubble flow,
verified Webhook reachability from apiserver, verified kubelet probe
reachability, and a one-click rollback runbook.

---

## 6. What this PR does NOT do

- It does NOT apply anything to the live cluster — files are checked
  into git only.
- It does NOT modify CNPs for the 7 namespaces already covered (files
  10–16). They remain untouched.
- It does NOT add L7 (HTTP method/path) rules for the new namespaces.
  Phase 2D will iterate from L4 → L7 once the L4 baseline is validated
  for ≥1 week.

---

## 7. Open items / follow-ups

1. **PR #13 YAML not yet applied** — `00-default-deny.yaml`,
   `04-allow-internal-redis.yaml`, `block-suspicious-exec*.yaml` exist in
   git but live cluster still runs old versions. Run Phase 2A apply
   block from the handover before this Phase 2C work hits production.

2. **Trivy ns named `security-cdm`, not `trivy-system`** — handover
   listed `trivy-system` as a missing ns. The actual ns deployed is
   `security-cdm` and it already has CNP coverage
   (`infras/k8s-yaml/trivy-operator/02-cnp.yaml`). No work needed here.

3. **Persistent token-reviewer SA** — fix from session 2
   (`zta-fix-vault-auth-and-finish-startup.sh`) should be baked into
   `infras/k8s-yaml/vault-scripts/` so reboots don't re-trigger the 403
   loop. Separate PR.

4. **`zta-startup.sh` known bugs** — wrong Sigstore selector,
   vault-0/Keycloak wait timeouts. Separate PR.

5. **kube-system namespace-wide default-deny** — separate PR with audit
   evidence (≥24h Hubble green).

6. **L7 CNP for new namespaces** — Phase 2D, dependent on this PR
   landing + 1 week observation.
