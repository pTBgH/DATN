# DATN Knowledge Base (`docs/`)

Operational incident reports and architecture notes for the Zero Trust
Architecture (ZTA) thesis project. Each file documents one failure mode
we hit during the rebuild pipeline, its root cause, and the committed
fix. These are the "why" behind script changes in `scripts/`.

## Index

| Topic | File | Related commit |
|-------|------|----------------|
| Falco + Tetragon OOM cascade on 12 GiB host | `falco-tetragon-ram-overcommit.md` | `313178f` |
| Gatekeeper helm CRD install timeout (504 from apiserver) | `gatekeeper-crd-timeout-incident.md` | *(uncommitted — per user directive)* |

## Conventions

- One incident per file; filename describes the symptom.
- Each file has: Symptom → Root cause → Fix → Operational guidance.
- Reference log paths in `evidence/rebuild_<timestamp>/` for the raw
  evidence.
- Reference commit hashes so future readers can `git show` the exact
  change that fixed it.

## When to add a new doc here

Add a doc whenever you fix something that could plausibly regress or
recur. Goal: future operators (including future-you) should be able to
reach for `docs/` first, not `git log`.
