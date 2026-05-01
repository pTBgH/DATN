#!/usr/bin/env bash
# scripts/zta-cosign-sign-deployment.sh
#
# Sign a Kubernetes Deployment YAML with Cosign and embed the signature
# (+ signed-by + algo) into spec.template.metadata.annotations so the
# K8sSignedImageAnnotation constraint passes admission.
#
# Workflow:
#   1. (One-time) zta-cosign-keygen.sh — generate keypair + public-key ConfigMap.
#   2. For each Deployment manifest:
#        bash scripts/zta-cosign-sign-deployment.sh path/to/deploy.yaml
#      → mutates the file in-place (or writes to --output path).
#   3. kubectl apply -f path/to/deploy.yaml
#
# Annotation schema (read by ConstraintTemplate K8sSignedImageAnnotation):
#   spec.template.metadata.annotations:
#     image.zta/signed-by:       "zta-platform-team"
#     image.zta/signature-algo:  "cosign-ecdsa-p256-sha256"
#     image.zta/signature:       "<base64 ECDSA signature of canonical YAML>"
#     image.zta/signed-at:       "2026-04-26T12:34:56Z"
#     image.zta/key-id:          "<sha256(public-key-PEM)>"
#
# This script does NOT push to OCI registries. It sticks the signature into
# the manifest itself so admission-time verification only needs cluster-local
# data. For full sigstore-style verification, deploy sigstore/policy-controller
# in a future PR (PR #19+).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY_DIR="${REPO_ROOT}/infras/cosign-keys"
PRIVATE_KEY="${COSIGN_PRIVATE_KEY:-${KEY_DIR}/zta.key}"
PUBLIC_KEY="${COSIGN_PUBLIC_KEY:-${KEY_DIR}/zta.pub}"
SIGNED_BY="${COSIGN_SIGNED_BY:-zta-platform-team}"
ALGO="cosign-ecdsa-p256-sha256"

red()    { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \?//'
  exit 1
}

INPUT_FILE=""
OUTPUT_FILE=""
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage ;;
    --dry-run) DRY_RUN=1 ;;
    --output=*) OUTPUT_FILE="${arg#--output=}" ;;
    *) INPUT_FILE="$arg" ;;
  esac
done

[ -z "$INPUT_FILE" ] && { red "ERROR: missing input YAML path"; usage; }
[ ! -f "$INPUT_FILE" ] && { red "ERROR: file not found: $INPUT_FILE"; exit 1; }

if ! command -v cosign >/dev/null 2>&1; then
  red "ERROR: cosign not installed. Install: https://docs.sigstore.dev/cosign/installation/"
  yellow "  Quick install:  go install github.com/sigstore/cosign/v2/cmd/cosign@latest"
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  red "ERROR: python3 required for YAML mutation"; exit 1
fi

if [ ! -f "$PRIVATE_KEY" ]; then
  red "ERROR: private key not found at $PRIVATE_KEY"
  yellow "  Run: bash scripts/zta-cosign-keygen.sh"
  exit 1
fi

OUTPUT_FILE="${OUTPUT_FILE:-$INPUT_FILE}"

blue "============================================================"
blue " Cosign-sign Kubernetes manifest"
blue "   input:  $INPUT_FILE"
blue "   output: $OUTPUT_FILE"
blue "   key:    $PRIVATE_KEY"
blue "============================================================"

# 1. Compute deterministic canonical bytes to sign — strip existing signature
#    annotations so re-signing produces same payload.
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
CANONICAL="$TMP_DIR/canonical.yaml"
SIGNATURE="$TMP_DIR/signature.bin"

python3 - "$INPUT_FILE" "$CANONICAL" <<'PY'
import sys, yaml, json
src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    docs = list(yaml.safe_load_all(f))
def strip(d):
    if not isinstance(d, dict): return d
    if d.get("kind") in ("Deployment", "StatefulSet", "DaemonSet"):
        ann = d.get("spec", {}).get("template", {}).get("metadata", {}).get("annotations", {}) or {}
        for k in list(ann):
            if k.startswith("image.zta/"): ann.pop(k)
        if ann:
            d["spec"]["template"]["metadata"]["annotations"] = ann
        else:
            d.get("spec", {}).get("template", {}).get("metadata", {}).pop("annotations", None)
    return d
clean = [strip(d) for d in docs if d]
with open(dst, "w") as f:
    f.write(json.dumps(clean, sort_keys=True, separators=(",", ":")))
PY

# 2. Sign the canonical bytes with cosign sign-blob.
#
# IMPORTANT: --tlog-upload=false is REQUIRED on NAT'd / air-gapped clusters.
# By default cosign uploads the signing cert to the public Rekor transparency
# log at https://rekor.sigstore.dev. On a host that can't reach Rekor (typical
# kind-on-VMware setup), the call hangs indefinitely waiting for HTTPS to
# resolve — observed during the 2026-05-01 rebuild as a >10-minute hang on
# phase 22-cosign-sign with no visible progress.
#
# Setting --tlog-upload=false (CLI flag, not env var — cosign sign-blob does
# NOT honor COSIGN_TLOG_UPLOAD as an env var for this flag in v2.x) makes
# the call entirely offline. The signature is still verifiable cluster-side
# because we don't depend on the public log; verification uses our own
# public key in the security/zta-cosign-public-key ConfigMap.
#
# Override CLI: set ZTA_COSIGN_TLOG_UPLOAD=true if you actually want Rekor
# upload (e.g. running on a machine with internet egress and want public
# transparency log entries).
TLOG_FLAG="--tlog-upload=${ZTA_COSIGN_TLOG_UPLOAD:-false}"

# Capture cosign stderr to a temp file inside TMP_DIR so the existing
# `trap 'rm -rf "$TMP_DIR"' EXIT` (line 88) cleans it up too — DO NOT
# install a second EXIT trap here, that would overwrite the first one
# and leak TMP_DIR.
COSIGN_STDERR="$TMP_DIR/cosign.stderr"

if ! cosign sign-blob --yes "$TLOG_FLAG" --key "$PRIVATE_KEY" \
       --output-signature "$SIGNATURE" "$CANONICAL" 2> "$COSIGN_STDERR"; then
  red "ERROR: cosign sign-blob failed:"
  cat "$COSIGN_STDERR" >&2
  exit 1
fi

if [ ! -s "$SIGNATURE" ]; then
  red "ERROR: cosign sign-blob produced empty signature file"
  cat "$COSIGN_STDERR" >&2
  exit 1
fi

SIG_B64="$(base64 -w0 < "$SIGNATURE")"
if [ -z "${SIG_B64:-}" ]; then
  red "ERROR: base64 of signature is empty"
  exit 1
fi

# 3. Compute key id (sha256 of public key PEM bytes).
KEY_ID="$(sha256sum "$PUBLIC_KEY" 2>/dev/null | awk '{print $1}')"
SIGNED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

green "  ✓ signature length: ${#SIG_B64} bytes (base64)"
green "  ✓ key id:           ${KEY_ID:0:16}..."

if [ "$DRY_RUN" -eq 1 ]; then
  yellow "[dry-run] not mutating file."
  echo "image.zta/signed-by:      $SIGNED_BY"
  echo "image.zta/signature-algo: $ALGO"
  echo "image.zta/signed-at:      $SIGNED_AT"
  echo "image.zta/key-id:         $KEY_ID"
  echo "image.zta/signature:      ${SIG_B64:0:48}..."
  exit 0
fi

# 4. Mutate the YAML — inject annotations into spec.template.metadata.annotations.
python3 - "$INPUT_FILE" "$OUTPUT_FILE" <<PY
import sys, yaml
src, dst = sys.argv[1], sys.argv[2]
ann = {
    "image.zta/signed-by": "$SIGNED_BY",
    "image.zta/signature-algo": "$ALGO",
    "image.zta/signed-at": "$SIGNED_AT",
    "image.zta/key-id": "$KEY_ID",
    "image.zta/signature": "$SIG_B64",
}
with open(src) as f:
    docs = list(yaml.safe_load_all(f))
out = []
for d in docs:
    if isinstance(d, dict) and d.get("kind") in ("Deployment", "StatefulSet", "DaemonSet"):
        spec = d.setdefault("spec", {}).setdefault("template", {}).setdefault("metadata", {})
        existing = spec.get("annotations") or {}
        existing.update(ann)
        spec["annotations"] = existing
    if d is not None:
        out.append(d)
with open(dst, "w") as f:
    yaml.safe_dump_all(out, f, default_flow_style=False, sort_keys=False)
PY

green "============================================================"
green " ✓ Signed and updated $OUTPUT_FILE"
green "============================================================"
echo "Apply:"
echo "  kubectl apply -f $OUTPUT_FILE"
echo
echo "Verify (after apply):"
echo "  kubectl get deploy -n <ns> <name> -o jsonpath='{.spec.template.metadata.annotations.image\\.zta/signed-by}'"
