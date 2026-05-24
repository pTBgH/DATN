# Microsegmentation L4 Conformance Test

**Status:** PR-microseg-conformance (this PR).
**Owner:** Bao (DATN), assisted by Devin.
**Closes:** doc/34-microseg-phase2c-plan.md §7 "Open items — long Hubble watch".

---

## 1. Why this exists

Phase 2C left two test approaches on the table for declaring the L4
baseline "closed":

1. **Watch Hubble `--verdict DROPPED --since 24h`** on the deployed cluster.
2. **Synthetic conformance test** — issue a deterministic matrix of
   probes and check Cilium's verdict against an expected `ALLOW` / `DROP`
   table.

Option 1 was abandoned because the lab cluster has no real user traffic;
24 h of zero events proves nothing. Option 2 — implemented here — is
both stronger evidence (it actually exercises every CNP allow rule
that matters) and repeatable (anyone with kubectl can re-run it after
any future CNP edit and get the same result, modulo the matrix).

## 2. What it does

`scripts/zta-microseg-conformance-test.sh` reads
`scripts/zta-microseg-conformance-matrix.csv` and, for each non-comment
row, spawns a busybox pod in `src_ns` with optional labels and runs
`nc -zvw5 dst_host dst_port`. The exit code is translated to an
observed verdict (`ALLOW` for nc rc==0, `DROP` otherwise) and compared
against the `expected` column.

Output is written under `evidence/microseg-conformance-<ts>.{csv,log,md}`.
A run is "green" when every TCP row reports PASS; UDP / EXEC rows are
SKIPped in v1 (handled by Phase 2D — L7).

## 3. Matrix conventions

The matrix CSV (`scripts/zta-microseg-conformance-matrix.csv`) groups
rows into three classes by id prefix:

| Prefix | Class | Default behaviour |
|---|---|---|
| `P*` | Positive — flow IS in the CNP allow list, expect `ALLOW` | run |
| `N*` | Negative — flow has no matching allow rule, expect `DROP` | run |
| `A*` | Anomaly injection — burst / exec / TI-egress scenarios | skipped unless `--anomaly` flag is passed AND the row is uncommented |

The `cnp_ref` column points at the CNP file + rule name that the row
is meant to exercise, so a failure points the operator straight at the
offending policy file.

`src_labels` is an optional comma-separated `key=value` list passed to
`kubectl run --labels`. Leave blank to spawn a vanilla pod whose Cilium
identity is "just-the-namespace" (the right shape for testing negative
flows). Add labels here only when the matched CNP `fromEndpoints`
selector includes an `app=X` clause; **avoid spoofing labels that
collide with a real Service selector** to prevent traffic mis-routing.

## 4. CLI

```
bash scripts/zta-microseg-conformance-test.sh            # positive + negative
bash scripts/zta-microseg-conformance-test.sh --anomaly  # also run A* rows
bash scripts/zta-microseg-conformance-test.sh --dry-run  # parse-only, no pods
bash scripts/zta-microseg-conformance-test.sh --filter '^N0[1-3]$'
bash scripts/zta-microseg-conformance-test.sh --keep-pods   # debug: leave pods
```

Exit codes: `0` = all rows PASS, `1` = one or more FAIL, `2` = bad
invocation / unreachable cluster.

## 5. Acceptance criteria for closing Phase 2C

L4 microsegmentation is considered closed once a single run reports
`FAIL == 0` across both P* and N* row classes (SKIP > 0 is acceptable
in v1 — non-TCP probes are deferred to Phase 2D).

When this is achieved, copy the produced
`evidence/microseg-conformance-<ts>.md` into the thesis evidence
folder and reference the run timestamp in `doc/34-microseg-phase2c-plan.md`
§7 Open items.

## 6. Reusability for the Adaptive Security Loop

The `A*` (anomaly) row class exists specifically to be reused by the
Phase 2 ML detector (PR-S in `security-analytics-plan-v2.md`):

- `A01` — burst rate (200 req/s) → trains the statistical UEBA z-score
  detector against a known-bad distribution.
- `A02` — `exec /bin/sh` in a container that never uses a shell → fires
  a Tetragon kprobe event used by the runtime-anomaly classifier.
- `A03` — egress to a CIDR in the FireHOL block list → exercises the
  threat-intel CCNP egress deny path (PIP 6).
- `A04` — DNS query for a known-bad domain → exercises the same path
  via DNS resolution.

These rows are commented out in v1 so that running the script with
`--anomaly` on a fresh cluster is a no-op until the operator
intentionally uncomments the rows they want exercised.

## 7. Known intentional deviations from strict ZTA

A few rows in the matrix carry `expected=ALLOW` even though, under a
strict "everything goes through Kong" reading of the ZTA model, you
might expect `DROP`. These are documented here so a reviewer doesn't
mistake them for over-permissive policy:

| Row | Flow | Why allowed |
|---|---|---|
| `N07` | `job7189-apps → keycloak.security:8080` | The OIDC discovery document (`/realms/<r>/.well-known/openid-configuration`) and JWKS (`/protocol/openid-connect/certs`) are public-key endpoints that Kong does not proxy. Workloads in `job7189-apps` need direct egress to Keycloak to verify JWT signatures locally. Tightening this to a per-app allow list — and ideally to a URL-path L7 policy that restricts apps to just the discovery + JWKS routes — is tracked for Phase 2D. |

When Phase 2D L7 policies land, these rows should flip to `DROP` for
everything except the explicit method+path combinations.

## 8. What this PR does NOT do

- Does **not** implement L7 (HTTP method / path) policy validation —
  that is Phase 2D.
- Does **not** modify any existing CNP. The script is purely a
  validator.
- Does **not** verify that **every** allow rule in files 10–24 has a
  matrix row. The v1 matrix covers the high-risk cross-tier paths
  (T0 ↔ T3, gateway admin, vault, OPA, MySQL); future PRs are expected
  to expand it as new workloads are deployed.
