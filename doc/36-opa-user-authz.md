# 36 — OPA user-authz PDP

> Workload trust (Phase 5.B.1) answered: **"is this pod allowed to run?"**.
> User trust (this phase) answers: **"is this request anonymous-OK, or does
> it need an authenticated session?"**.
> Both layers are independent: a high-trust pod still rejects a request that
> arrives without a valid JWT.

## 1. Scope & rationale

The platform already has Kong as the gateway with the `jwt` plugin verifying
Keycloak-issued tokens, but `jwt` only proves that **the token is genuine**.
It does not look at where the request is going and does not centralize the
public-path whitelist — without an extra check, the only way to mark a
specific path as public is to remove the `jwt` plugin from that route
individually, which is easy to get wrong and impossible to grep for in one
place.

The thesis deploys OPA as a **user-authz Policy Decision Point (PDP)** in
front of every upstream service. Kong delegates each request to OPA, which
evaluates two declarative Rego rules and returns `allow` / `deny`:

1. The path is in the public whitelist (`public.rego`), **or**
2. The JWT carries a non-empty `sub` claim (a valid authenticated session).

Everything else — "is this recruiter allowed to edit this job in this
workspace?", "is this user a platform admin?" — happens in the Laravel
application layer (`workspace_members` bitmask + `super.admin` Gate). Keeping
business roles in Keycloak realm-roles + Rego was a leaky abstraction:
the JWT carries a single global roles list, but the business model assigns
roles per `(user, workspace)`, so the global view could never be correct in
the first place.

| Concern | Phase 5.B.1 workload-trust | This phase user-authz |
|---|---|---|
| Subject | Pod | Authenticated user (JWT) |
| Trust input | Labels, CVEs, runtime evidence | JWT `sub` + request path |
| Decision point | `security/zta-pdp` kopf operator | `security/opa` (this doc) |
| Enforcement point | Cilium network policy + annotations | Kong pre-function plugin |
| Update frequency | Reconciled per pod event (~seconds) | Per HTTP request (~ms) |

## 2. Architecture

```
                                  ┌─────────────────────────┐
                          (1) JWT │ Keycloak (security ns)  │
                          ───────►│  realm: job7189         │
                                  │  clients: recruiter-app │
                                  │           candidate-app │
                                  └────────────┬────────────┘
                                               │ (signed JWT, no business
                                               │  realm-roles — azp distinguishes
                                               │  recruiter vs candidate)
                                               ▼
   ┌──────────┐  /api/jobs   ┌──────────────────────────────┐  POST /v1/data/zta/authz/allow  ┌─────────────┐
   │  user    │ ───────────► │ Kong gateway (gateway ns)    │ ──────────────────────────────► │ OPA         │
   │ (browser │              │   1. plugin `jwt` (verify)   │                                 │ (security)  │
   │ /curl)   │              │   2. plugin `pre-function`   │ ◄────────────── {allow=T/F} ─── │  policies:  │
   └──────────┘              │      → calls OPA             │                                 │  default,   │
                             │   3. forward to upstream     │                                 │  public     │
                             └──────────────┬───────────────┘                                 └─────────────┘
                                            │ (if allow=T)
                                            ▼
                              ┌─────────────────────────────┐
                              │ Laravel service             │
                              │ (job7189-apps)              │
                              │   middleware:               │
                              │     auth + super.admin      │
                              │   workspace_members bitmask │
                              │   = real business authz     │
                              └─────────────────────────────┘
```

Sequence:
1. User authenticates at Keycloak via either the `recruiter-app-*` or
   `candidate-app-*` client. The JWT's `azp` claim records which client
   minted it; Laravel uses this to decide whether the user is a recruiter
   or a candidate. No business realm-roles are assigned.
2. Browser/curl sends `Authorization: Bearer <jwt>` to Kong.
3. Kong's per-route `jwt` plugin verifies the token signature against the
   Keycloak public key (`http://keycloak.security.svc.cluster.local:8080/realms/job7189`).
4. Kong's global `pre-function` plugin re-decodes the JWT payload (signature
   already verified — just need the claims for the decision log) and POSTs:
   ```json
   { "input": { "method": "GET", "path": "/api/jobs",
                "jwt": { "sub": "<keycloak-user-id>",
                         "preferred_username": "recruiter1",
                         "azp": "recruiter-app-dev" } } }
   ```
   to `http://opa.security.svc.cluster.local:8181/v1/data/zta/authz/allow`.
5. OPA evaluates `default.rego`:
   - if `public.rego` matches → allow,
   - else if `input.jwt.sub` is non-empty → allow,
   - else → deny.
6. If `allow=false`, the pre-function plugin terminates the request with
   `HTTP 403 {"message": "forbidden", "reason": "OPA denied user-authz",
   "user": "...", "azp": "..."}`. Otherwise it falls through and Kong
   proxies to the upstream service. Laravel's middleware (`auth`,
   `super.admin`, controller-level `Gate::authorize(...)`) then does the
   per-workspace authorization based on `workspace_members` bitmasks.

### Why a separate plugin (and not the Kong `opa` plugin)?

Kong's enterprise `opa` plugin is paywalled. The OSS `pre-function` plugin
ships with every Kong image and runs Lua in the `access` phase — exactly
where we need to gate the request. Bonus: keeping the integration in our
own `kong.yml` makes the OPA call site fully visible in the repo (one
place to read), which matters for the thesis defence.

## 3. Deployment

### 3.1. Keycloak — test users (no business roles)

Source-of-truth script:
[`infras/keycloak/scripts/add-test-users.sh`](../infras/keycloak/scripts/add-test-users.sh)

```bash
export KUBECONFIG=~/.kube/config-job7189
bash infras/keycloak/scripts/add-test-users.sh
```

Effect (idempotent, safe to rerun):

| Realm `job7189` | Before | After |
|---|---|---|
| Clients | `recruiter-app-dev`, `candidate-app-dev` (unchanged) | _ditto_ |
| Realm roles | 3 defaults (`default-roles-job7189`, `uma_authorization`, `offline_access`) | _unchanged_ (the 8 legacy business roles are absent; if you upgraded an existing realm that still has them, run `--cleanup-legacy-roles` to delete them) |
| Users | 0 | **3 test users**: `admin1`, `recruiter1`, `member1` — password `dev1234`, no role mapping |

> Identity comes from the `azp` claim of the access token (which Keycloak
> client the user logged in through). Laravel reads `azp` and writes
> `users.type = 'recruiter'` or `'candidate'` accordingly. Platform admin
> is determined by the user's membership of the workspace whose ID is set
> in the env var `SUPER_ADMIN_WORKSPACE_ID` — checked by each Laravel
> service's `super.admin` middleware. The `admin1` test user gets platform
> admin powers by being seeded as an active member of that workspace, not
> by any Keycloak role.

Verify in Keycloak Admin Console (`http://auth.job7189.local`, realm
`job7189`) or via kcadm:

```bash
KC_POD=$(kubectl -n security get pod -l app=keycloak -o jsonpath='{.items[0].metadata.name}')
kubectl -n security exec "$KC_POD" -- \
  /opt/keycloak/bin/kcadm.sh get users -r job7189 --fields username | head -20
```

> **Security caveat.** `dev1234` is a literal thesis-demo password — these
> three users exist solely for the OPA sequence diagram and the 3-curl demo.
> Remove them before any production cut-over:
> `bash add-test-users.sh --remove`.
>
> If the realm still has the 8 legacy business realm-roles (`admin`,
> `rec_ops`, `recruiter`, `sourcer`, `coordinator`, `hiring_manager`,
> `interviewer`, `member`) from the older role-based design, delete them
> with `bash add-test-users.sh --cleanup-legacy-roles`. The current OPA
> policy ignores `realm_access.roles` entirely, so they are dead weight.

### 3.2. OPA Helm chart

Helm values: [`infras/k8s-yaml/opa/values.yaml`](../infras/k8s-yaml/opa/values.yaml)
Deploy script: [`scripts/zta-deploy-opa.sh`](../scripts/zta-deploy-opa.sh)

```bash
bash scripts/zta-deploy-opa.sh
```

What it does:
1. `helm repo add open-policy-agent https://open-policy-agent.github.io/kube-mgmt/charts`
2. Creates `ConfigMap security/opa-policies` from the `.rego` files in
   `infras/k8s-yaml/opa/policies/`. The ConfigMap carries the label
   `openpolicyagent.org/policy=rego` so the kube-mgmt sidecar finds it.
3. `helm upgrade --install opa open-policy-agent/opa-kube-mgmt
   -f infras/k8s-yaml/opa/values.yaml -n security`
4. Waits for rollout, then smoke-tests the `/v1/data/zta/authz/allow`
   endpoint with a synthetic GET `/api/health` input (expects `true`) and
   an anonymous GET `/api/workspaces` input (expects `false`).

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
$EDITOR infras/k8s-yaml/opa/policies/public.rego
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

`.rego` files live in `infras/k8s-yaml/opa/policies/` and feed the single
decision rule `data.zta.authz.allow`.

| File | Package | Guards |
|---|---|---|
| `default.rego` | `zta.authz` | Default deny; allow if `public.rego` matches OR JWT has a non-empty `sub`. Holds the `public_paths` set. |
| `public.rego` | `zta.authz.public` | Anonymous-OK paths: health probes, `/api/jobs` (browse), `GET /api/jobs/*`, `POST /api/jobs/*/apply`, `GET /api/companies/*`, `/api/metadata/*`, `/api/public/*`, `/realms/*`. |

To add a new public endpoint:

1. Either add an exact match to `public_paths` in `default.rego`, or
2. Add a new `allow if { … }` block in `public.rego` for prefix / pattern
   matching.

To add a new authenticated endpoint: **do nothing in OPA** — having a JWT
is enough. Configure the Kong route with `plugins: [{ name: jwt }]` so
Kong rejects anonymous traffic with 401 before it even reaches OPA, and
add the per-workspace authorization in the Laravel controller / policy.

## 5. Demo — public vs authenticated

```bash
# 0. Resolve hostname (assumes /etc/hosts maps auth.job7189.local + api.job7189.local
#    to the cluster Kong + Keycloak; or run kubectl port-forward).
KC_URL="http://auth.job7189.local"
API_URL="http://api.job7189.local"

# 1. Public path — no token required
curl -i "$API_URL/api/health"
# → 200 OK

# 2. Authenticated path — no token → OPA denies
curl -i "$API_URL/api/workspaces"
# → 403 forbidden ({"reason":"OPA denied user-authz"})

# 3. Authenticated path — valid token → OPA allows; Laravel then decides
#    whether the user has access to the specific workspace.
RECRUITER_TOKEN=$(curl -s -X POST \
  -d 'client_id=recruiter-app-dev' \
  -d 'username=recruiter1' -d 'password=dev1234' \
  -d 'grant_type=password' \
  "$KC_URL/realms/job7189/protocol/openid-connect/token" | jq -r .access_token)

curl -i -H "Authorization: Bearer $RECRUITER_TOKEN" "$API_URL/api/workspaces"
# → 200 / 403 depending on the user's workspace_members rows in Laravel
```

Expected OPA decision log (visible via `kubectl -n security logs deploy/opa
-c opa --tail=20 | jq -c 'select(.msg=="Decision Log")'`):

```json
{ "msg": "Decision Log", "path": "zta/authz/allow", "result": true,
  "input": { "method": "GET", "path": "/api/workspaces",
             "jwt": { "sub": "9a…", "preferred_username": "recruiter1",
                      "azp": "recruiter-app-dev" } } }
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
# Expected: ["default.rego", "public.rego"]
kill $PF

# 6.3. End-to-end decision via Kong (no token, public path)
curl -i http://api.job7189.local/api/health

# 6.4. Hubble flow for the OPA call site
hubble observe --namespace gateway --to-namespace security \
  --label app=kong-gateway --port 8181 -o compact -f
```

## 7. Operational notes

- **Decision logs** are written to stdout in JSON (`opa.logFormat=json` in
  `values.yaml`) so Filebeat (Phase 4) ships them straight to Elasticsearch
  for later auditing. The thesis chapter cites these as the evidence trail
  for "who tried to call what, was it allowed".
- **Policy revision** is monotonic — kube-mgmt logs `policy reloaded:
  opa-policies/public.rego` every time the ConfigMap changes. Roll back by
  reverting the file and `bash scripts/zta-deploy-opa.sh --policies-only`.
- **Latency budget**: the pre-function plugin times out the OPA call at 1
  second (`TIMEOUT_MS = 1000`). Realistic p99 in this cluster is ~5–15 ms.
- **Header echo for audit**: the Lua script does NOT mutate the request
  forwarded to upstream — it only short-circuits on deny. The upstream
  service therefore still relies on Kong's existing `jwt` plugin to inject
  the verified claims into `X-Consumer-*` headers.
- **No business roles in the JWT.** If a request needs different behaviour
  for a recruiter vs a candidate, the Laravel service should read the
  `azp` claim (or the `users.type` column written by the auth callback).
  If it needs per-workspace behaviour, the Laravel service should read
  `workspace_members.{job,workspace,candidate,pipeline}_permissions`
  bitmasks. Neither of these belongs in OPA.

## 8. Open items / FU backlog

| ID | Item | Owner | Notes |
|---|---|---|---|
| FU-1 | Replace `dev1234` with Vault-issued passwords | thesis-after | After Vault dynamic-secret flow is set up |
| FU-2 | Add per-route OPA bypass for `/api/health` (instead of relying on `public.rego`) | thesis-after | Reduces OPA load on liveness probes |
| FU-3 | Wire OPA decision logs into the Grafana evidence dashboard | thesis-after | Mirror the `pdp_*` metric pattern from Phase 5.B.1 |
| FU-4 | Add OPA SLO panel (decision latency p99 < 50 ms) | thesis-after | |
| FU-5 | Bundle realm-export with seeded test users into the custom Keycloak image (currently kcadm at run-time) | thesis-after | Removes the "rerun add-test-users.sh after cluster rebuild" step |
