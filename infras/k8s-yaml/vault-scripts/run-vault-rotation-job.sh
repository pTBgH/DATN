#!/usr/bin/env bash
set -euo pipefail

# Helper to create a Secret (vault-admin-token) from VAULT_TOKEN env, apply Job, wait and collect logs.
# Usage: export VAULT_TOKEN="..."; ./run-vault-rotation-job.sh

if [ -z "${VAULT_TOKEN:-}" ]; then
  echo "Set VAULT_TOKEN environment variable with an admin token before running." >&2
  exit 2
fi

NAMESPACE=job7189-apps
JOB_MANIFEST="$(dirname "$0")/vault-rotation-job.yaml"

# create or replace secret
kubectl -n "$NAMESPACE" delete secret vault-admin-token --ignore-not-found
kubectl -n "$NAMESPACE" create secret generic vault-admin-token --from-literal=token="$VAULT_TOKEN"

# apply job
kubectl apply -f "$JOB_MANIFEST"

# wait for job to complete (or fail)
kubectl -n "$NAMESPACE" wait --for=condition=complete job/vault-rotation-test --timeout=120s || true

# fetch pod name
POD=$(kubectl -n "$NAMESPACE" get pod -l job-name=vault-rotation-test -o jsonpath='{.items[0].metadata.name}')

if [ -n "$POD" ]; then
  echo "Job pod: $POD"
  echo "Logs:"
  kubectl -n "$NAMESPACE" logs "$POD" -c vault-cli || true
  echo "Copying /tmp outputs from pod to local outputs dir"
  mkdir -p "$(pwd)/k8s-management/operational/vault-rotation-test/outputs/job-run"
  kubectl -n "$NAMESPACE" cp "$POD":/tmp/creds.json "$(pwd)/k8s-management/operational/vault-rotation-test/outputs/job-run/creds.json" || true
  kubectl -n "$NAMESPACE" cp "$POD":/tmp/role-backup.json "$(pwd)/k8s-management/operational/vault-rotation-test/backups/role-backup.json" || true
fi

echo "Cleanup: delete job (keeps the secret)"
kubectl -n "$NAMESPACE" delete job vault-rotation-test --ignore-not-found

echo "DONE."
