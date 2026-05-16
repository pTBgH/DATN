# 36 — OPA user-authz PDP (Phase 5.B.2)

> Workload trust (Phase 5.B.1) answered: **"is this pod allowed to run?"**.
> User trust (this phase) answers: **"is this user allowed to call this API path?"**.
> Both layers are independent: a high-trust pod still rejects a low-privilege user.

## 1. Scope & rationale

The platform already has Kong as the gateway with the `jwt` plugin verifying
Keycloak-issued tokens, but `jwt` only proves that **the token is genuine** —
it does not look at the realm-roles claim and does not gate access to
business resources. Without an authorization layer, any logged-in user can
hit `POST /api/admin/jobs` and create a job — which violates least-privilege.

The thesis closes this gap by deploying OPA as a **user-authz Policy Decision
Point (PDP)** in front of every protected upstream service. Kong delegates
each request to OPA, which evaluates the user's realm-roles against
declarative Rego rules and returns `allow` / `deny`.

| Concern | Phase 5.B.1 workload-trust | Phase 5.B.2 user-authz |
|---|---|---|
| Subject | Pod | Authenticated user (JWT) |
| Trust input | Labels, CVEs, runtime evidence | Keycloak realm-roles |
| Decision point | `security/zta-pdp` kopf operator | `security/opa` (this doc) |
| Enforcement point | Cilium network policy + annotations | Kong pre-function plugin |
| Update frequency | Reconciled per pod event (~seconds) | Per HTTP request (~ms) |

## 2. Architecture

```
                                  ┌─────────────────────────┐
                          (1) JWT │ Keycloak (security ns)  │
                          ───────►│  realm: job7189         │
                                  │  realm-roles: admin/... │
                                  └────────────┬────────────┘
                                               │ (signed JWT)
                                               ▼
   ┌──────────┐  /api/jobs   ┌──────────────────────────────┐  POST /v1/data/zta/authz/allow  ┌─────────────┐
   │  user    │ ───────────► │ Kong gateway (gateway ns)    │ ──────────────────────────────► │ OPA         │
   │ (browser │              │   1. plugin `jwt` (verify)   │                                 │ (security)  │
   │ /curl)   │              │   2. plugin `pre-function`   │ ◄────────────── {allow=T/F} ─── │  policies:  │
   └──────────┘              │      → calls OPA             │                                 │  default,   │
                             │   3. forward to upstream     │                                 │  jobs,      │
                             └──────────────┬───────────────┘                                 │  candidates,│
                                            │ (if allow=T)                                    │  workspace, │
                                            ▼                                                 │  interviews │
                              ┌─────────────────────────────┐                                 └─────────────┘
                              │ job-service (job7189-apps)  │
                              └─────────────────────────────┘
```

Sequence:
1. User authenticates at Keycloak, gets a signed JWT with `realm_access.roles`.
2. Browser/curl sends `Authorization: Bearer <jwt>` to Kong.
3. Kong's existing per-route `jwt` plugin verifies the token signature against
   the Keycloak public key (`http://keycloak.security.svc.cluster.local:8080/realms/job7189`).
4. Kong's new **global** `pre-function` plugin re-decodes the JWT payload
   (signature already verified — just need the claims) and POSTs:
   ```json
   { "input": { "method": "GET", "path": "/api/jobs",
                "jwt": { "preferred_username": "admin1",
                         "realm_access": { "roles": ["admin"] } } } }
   ```
   to `http://opa.security.svc.cluster.local:8181/v1/data/zta/authz/allow`.
5. OPA evaluates `default.rego` → delegates to the matching resource
   policy (`jobs.rego`, `candidates.rego`, …) → returns
   `{"result": true|false}`.
6. If `allow=false`, the pre-function plugin terminates the request with
   `HTTP 403 {"message": "forbidden", "reason": "OPA denied user-authz",
   "user": "...", "roles": [...]}`. Otherwise it falls through and Kong
   proxies to the upstream microservice as normal.

### Why a separate plugin (and not the Kong `opa` plugin)?

Kong's enterprise `opa` plugin is paywalled. The OSS `pre-function` plugin
ships with every Kong image and runs Lua in the `access` phase — exactly
where we need to gate the request. Bonus: keeping the integration in our
own `kong.yml` makes the OPA call site fully visible in the repo (one
place to read), which matters for the thesis defence.

## 3. Deployment

### 3.1. Keycloak — business roles + test users

Source-of-truth script:
[`infras/keycloak/scripts/add-app-roles.sh`](../infras/keycloak/scripts/add-app-roles.sh)

```bash
export KUBECONFIG=~/.kube/config-job7189
bash infras/keycloak/scripts/add-app-roles.sh
```

Effect (idempotent, safe to rerun):

| Realm `job7189` | Before | After |
|---|---|---|
| Realm roles | 3 defaults (`default-roles-job7189`, `uma_authorization`, `offline_access`) | 3 defaults + **8 business** (`admin`, `rec_ops`, `recruiter`, `sourcer`, `coordinator`, `hiring_manager`, `interviewer`, `member`) |
| Users | 0 | **3 test users**: `admin1` (admin), `recruiter1` (recruiter), `member1` (member) — password `dev1234` |

Verify in Keycloak Admin Console (`http://auth.job7189.local`, realm
`job7189`) or via kcadm:

```bash
KC_POD=$(kubectl -n security get pod -l app=keycloak -o jsonpath='{.items[0].metadata.name}')
kubectl -n security exec "$KC_POD" -- \
  /opt/keycloak/bin/kcadm.sh get roles -r job7189 --fields name | head -20
```

> **Security caveat.** `dev1234` is a literal thesis-demo password — these
> three users exist solely for the OPA sequence diagram and the 3-curl demo.
> Remove them before any production cut-over: `bash add-app-roles.sh --remove`.

### 3.2. OPA Helm chart

Helm values: [`infras/k8s-yaml/opa/values.yaml`](../infras/k8s-yaml/opa/values.yaml)
Deploy script: [`scripts/zta-deploy-opa.sh`](../scripts/zta-deploy-opa.sh)

```bash
bash scripts/zta-deploy-opa.sh
```

What it does:
1. `helm repo add open-policy-agent https://open-policy-agent.github.io/kube-mgmt/charts`
2. Creates `ConfigMap security/opa-policies` from the 5 `.rego` files in
   `infras/k8s-yaml/opa/policies/`. The ConfigMap carries the label
   `openpolicyagent.org/policy=rego` so the kube-mgmt sidecar finds it.
3. `helm upgrade --install opa open-policy-agent/opa-kube-mgmt
   -f infras/k8s-yaml/opa/values.yaml -n security`
4. Waits for rollout, then smoke-tests the `/v1/data/zta/authz/allow`
   endpoint with a synthetic `admin1` GET `/api/jobs` input (expects `true`).

Resource budget per pod (verified at deploy):

| Container | CPU request | CPU limit | Mem request | Mem limit |
|---|---|---|---|---|
| `opa`     | 50m  | 200m | 64Mi | 192Mi |
| `mgmt`    | 20m  | 100m | 32Mi | 96Mi  |
| **total** | 70m  | 300m | 96Mi | 288Mi |

Reload model: kube-mgmt watches `security/opa-policies` ConfigMap → pushes
updated Rego into OPA's policy store within ~1 second. To rotate a policy:

```bash
# Edit a .rego file
$EDITOR infras/k8s-yaml/opa/policies/jobs.rego
# Re-apply only the ConfigMap (no pod restart needed)
bash scripts/zta-deploy-opa.sh --policies-only
# Watch the reload event
kubectl -n security logs -l app=opa -c mgmt --tail=20 | grep -i policy
```

### 3.3. Kong — pre-function plugin wiring

Patch lives in [`infras/kong/kong.yml`](../infras/kong/kong.yml) under the
global `plugins:` block. Kong's ConfigMap is `gateway/kong-declarative-config`
(created by `infras/kong/01_setup_kong_config.sh`) and the gateway runs with
`KONG_WATCH_CONFIG=on`, so a `kubectl apply` of the regenerated ConfigMap
hot-reloads the config without restarting the pod:

```bash
bash infras/kong/01_setup_kong_config.sh
# Force-reload (only needed if the watch didn't pick up the change)
kubectl -n gateway rollout restart deploy/kong-gateway
```

Failure-mode toggle: the Lua script reads `ZTA_OPA_FAIL_CLOSED`. Default
is **fail-open** so a 503 from OPA does not 503 every API call. To flip:

```bash
kubectl -n gateway set env deploy/kong-gateway ZTA_OPA_FAIL_CLOSED=1
```

### 3.4. Cilium network policy

Two new CNPs unlock the new traffic flow:

- [`namespaces/14-gateway.yaml`](../infras/k8s-yaml/cilium-policies/namespaces/14-gateway.yaml)
  rule **5b**: `allow-kong-egress-opa` — kong-gateway → `security/opa:8181`
- [`namespaces/12-security.yaml`](../infras/k8s-yaml/cilium-policies/namespaces/12-security.yaml)
  rule **8**: `allow-kong-ingress-opa` — accept from `gateway/kong-gateway`
- [`namespaces/12-security.yaml`](../infras/k8s-yaml/cilium-policies/namespaces/12-security.yaml)
  rule **9**: `allow-opa-egress-apiserver` — kube-mgmt sidecar → kube-apiserver
- Rule 7 was extended to also scrape `:8181/metrics` from Prometheus.

Apply after editing:

```bash
bash infras/k8s-yaml/cilium-policies/apply-zta-microsegmentation.sh
```

## 4. Rego policy catalogue

Each `.rego` file in `infras/k8s-yaml/opa/policies/` corresponds to one
microservice domain. All policies live under the package `zta.authz.*`
and feed the single decision rule `data.zta.authz.allow`.

| File | Package | Guards |
|---|---|---|
| `default.rego` | `zta.authz` | Aggregates all sub-policies, default deny |
| `public.rego` | `zta.authz.public` | Health probes, `/api/public/jobs`, `/api/jobs/*/apply` |
| `jobs.rego` | `zta.authz.jobs` | `/api/jobs`, `/api/admin/jobs`, `/api/admin/categories` |
| `candidates.rego` | `zta.authz.candidates` | `/api/candidates/profile`, `/api/resumes`, `/api/applications`, `/api/board` |
| `workspace.rego` | `zta.authz.workspace` | `/api/workspaces`, `/api/invitations` |
| `interviews.rego` | `zta.authz.interviews` | `/api/interviews`, `/api/pipelines`, `/api/scorecards` |

Role-to-resource matrix (the source-of-truth view for the thesis chapter):

| Action | admin | rec_ops | recruiter | sourcer | coordinator | hiring_manager | interviewer | member |
|---|---|---|---|---|---|---|---|---|
| List jobs (GET /api/jobs)        | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Create job (POST /api/jobs)      | ✓ | ✓ | ✓ |   |   |   |   |   |
| /api/admin/jobs                  | ✓ | ✓ |   |   |   |   |   |   |
| /api/resumes                     | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |   |   |
| POST /api/applications           | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| GET /api/applications            | ✓ | ✓ | ✓ |   | ✓ |   |   |   |
| POST /api/workspaces             | ✓ | ✓ |   |   |   |   |   |   |
| POST /api/invitations            | ✓ | ✓ | ✓ |   |   |   |   |   |
| POST /api/scorecards             | ✓ |   |   |   |   | ✓ | ✓ |   |
| GET /api/scorecards              | ✓ | ✓ | ✓ |   |   | ✓ |   |   |
| POST /api/interviews             | ✓ | ✓ | ✓ |   | ✓ |   |   |   |
| POST /api/pipelines              | ✓ | ✓ | ✓ |   |   |   |   |   |

## 5. Demo — 3 curls + log evidence

To be filled with **live** evidence after deploy. The expected sequence:

```bash
# 0. Resolve hostname (assumes /etc/hosts maps auth.job7189.local + api.job7189.local
#    to the cluster Kong + Keycloak; or run kubectl port-forward)
KC_URL="http://auth.job7189.local"
API_URL="http://api.job7189.local"

# 1. Mint tokens
ADMIN_TOKEN=$(curl -s -X POST \
  -d 'client_id=candidate-app-dev' \
  -d 'username=admin1' -d 'password=dev1234' \
  -d 'grant_type=password' \
  "$KC_URL/realms/job7189/protocol/openid-connect/token" | jq -r .access_token)

RECRUITER_TOKEN=$(curl -s -X POST \
  -d 'client_id=candidate-app-dev' \
  -d 'username=recruiter1' -d 'password=dev1234' \
  -d 'grant_type=password' \
  "$KC_URL/realms/job7189/protocol/openid-connect/token" | jq -r .access_token)

MEMBER_TOKEN=$(curl -s -X POST \
  -d 'client_id=candidate-app-dev' \
  -d 'username=member1' -d 'password=dev1234' \
  -d 'grant_type=password' \
  "$KC_URL/realms/job7189/protocol/openid-connect/token" | jq -r .access_token)

# 2. Three behavioural cases
#    a) admin1 → /api/admin/jobs    → 200 (admin role matches admin.rego)
curl -i -H "Authorization: Bearer $ADMIN_TOKEN" "$API_URL/api/admin/jobs"

#    b) recruiter1 → /api/admin/jobs → 403 (recruiter not in {rec_ops, admin})
curl -i -H "Authorization: Bearer $RECRUITER_TOKEN" "$API_URL/api/admin/jobs"

#    c) recruiter1 → POST /api/jobs → 200 (recruiter in jobs.rego allowlist)
curl -i -X POST -H "Authorization: Bearer $RECRUITER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"thesis-demo-job"}' \
  "$API_URL/api/jobs"

#    d) member1 → POST /api/jobs    → 403 (member not in jobs allowlist)
curl -i -X POST -H "Authorization: Bearer $MEMBER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"thesis-demo-job"}' \
  "$API_URL/api/jobs"
```

Expected OPA decision log (visible via `kubectl -n security logs deploy/opa
-c opa --tail=20 | jq -c 'select(.msg=="Decision Log")'`):

```json
{ "msg": "Decision Log", "path": "zta/authz/allow", "result": true,
  "input": { "method": "GET", "path": "/api/admin/jobs",
             "jwt": { "preferred_username": "admin1",
                      "realm_access": { "roles": ["admin", ...] } } } }
```

## 6. Verification commands

```bash
export KUBECONFIG=~/.kube/config-job7189

# 6.1. OPA pod up + policies loaded
kubectl -n security get pod -l app=opa -o wide
kubectl -n security logs -l app=opa -c mgmt --tail=20 | grep -i 'loaded\|reloaded'

# 6.2. Policies registered with OPA
kubectl -n security port-forward svc/opa 8181:8181 &
PF=$!
curl -s http://localhost:8181/v1/policies | jq 'keys'
# Expected: ["candidates.rego", "default.rego", "interviews.rego",
#            "jobs.rego", "public.rego", "workspace.rego"]
kill $PF

# 6.3. End-to-end decision via Kong (with a real token)
ADMIN_TOKEN=$(... # see §5)
curl -i -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://api.job7189.local/api/jobs

# 6.4. Hubble flow for the OPA call site
hubble observe --namespace gateway --to-namespace security \
  --label app=kong-gateway --port 8181 -o compact -f
```

## 7. Operational notes

- **Decision logs** are written to stdout in JSON (`opa.logFormat=json` in
  `values.yaml`) so Filebeat (Phase 4) ships them straight to Elasticsearch
  for later auditing. The thesis chapter cites these as the evidence trail
  for "who tried to call what, with which roles".
- **Policy revision** is monotonic — kube-mgmt logs `policy reloaded:
  opa-policies/jobs.rego` every time the ConfigMap changes. Roll back by
  reverting the file and `bash scripts/zta-deploy-opa.sh --policies-only`.
- **Latency budget**: the pre-function plugin times out the OPA call at 1
  second (`TIMEOUT_MS = 1000`). Realistic p99 in this cluster is ~5–15 ms.
- **Header echo for audit**: the Lua script does NOT mutate the request
  forwarded to upstream — it only short-circuits on deny. The upstream
  service therefore still relies on Kong's existing `jwt` plugin to inject
  the verified claims into `X-Consumer-*` headers.

## 8. Open items / FU backlog

| ID | Item | Owner | Notes |
|---|---|---|---|
| FU-5.B.2-1 | Replace `dev1234` with Vault-issued passwords | thesis-after | After Vault dynamic-secret flow is set up |
| FU-5.B.2-2 | Add per-route OPA bypass for `/api/health` (instead of relying on `public.rego`) | thesis-after | Reduces OPA load on liveness probes |
| FU-5.B.2-3 | Wire OPA decision logs into the Grafana evidence dashboard | thesis-after | Mirror the `pdp_*` metric pattern from Phase 5.B.1 |
| FU-5.B.2-4 | Add OPA SLO panel (decision latency p99 < 50 ms) | thesis-after | |
| FU-5.B.2-5 | Bundle realm-export with new roles into the custom Keycloak image (currently kcadm at run-time) | thesis-after | Removes the "rerun add-app-roles.sh after cluster rebuild" step |
