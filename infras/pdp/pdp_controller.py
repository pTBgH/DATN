"""
PDP Controller — Continuous ZTA Trust Score Engine
====================================================

Step 2.3.6 — Adaptive Loop Closure (CISA ZTMM Identity Advanced → Optimal).

Watches Pod label changes in 7 ZTA namespaces and:
  1. Verifies presence of 6 required ZTA labels (zta.job7189/{tier,role,
     team,data-classification,env,exposure}) — schema theo Phase 4 ZTA
     hardening (xem knowledge-base/19-label-schema.md).
  2. Reads VulnerabilityReport CRs from Trivy Operator to assess image
     CVE posture (criticalCount, highCount).
  3. Computes weighted trust score from 2 inputs:
     score = max(0, 100 - 30*(missing_labels/6) - 50*has_critical - 20*has_high)
  4. Patches pods with label `zta.job7189/score-bucket=high|medium|low` so
     Cilium CNP and Gatekeeper can enforce based on trust level.
  5. Emits structured audit log to stdout (Filebeat → Elasticsearch).
  6. Exposes Prometheus metrics for monitoring.

Score-bucket thresholds:
  high   : score >= 80
  medium : score >= 50
  low    : score < 50

Reference:
  - knowledge-base/19-label-schema.md (label definitions)
  - knowledge-base/25-pdp-controller.md (architecture)
  - knowledge-base/zta-gap-decision.md (Decision 1 — 2-input Trust Score)

Runtime: kopf 1.37+ on Python 3.11.
"""
from __future__ import annotations

import json
import logging
import os
import sys
import threading
import time
from typing import Any

import kopf
from kubernetes import client, config
from kubernetes.dynamic import DynamicClient
from prometheus_client import Counter, Gauge, start_http_server


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
ZTA_NAMESPACES = os.environ.get(
    "ZTA_NAMESPACES",
    "data,vault,security,monitoring,gateway,management,job7189-apps",
).split(",")

REQUIRED_LABELS = [
    "zta.job7189/tier",                  # T0/T1/T2/T3
    "zta.job7189/role",                  # api/db/gateway/sso/proxy/broker/...
    "zta.job7189/team",                  # security/data/platform/backend
    "zta.job7189/data-classification",   # public/internal/confidential/none
    "zta.job7189/env",                   # prod/staging/dev
    "zta.job7189/exposure",              # cluster-only/internal/external
]

PROMETHEUS_PORT = int(os.environ.get("PROMETHEUS_PORT", "9100"))
METRICS_RECONCILE_PERIOD = int(os.environ.get("RECONCILE_PERIOD", "60"))

# Score formula weights (from knowledge-base/zta-gap-decision.md)
WEIGHT_LABEL = int(os.environ.get("PDP_WEIGHT_LABEL", "30"))
WEIGHT_CRITICAL_CVE = int(os.environ.get("PDP_WEIGHT_CRITICAL", "50"))
WEIGHT_HIGH_CVE = int(os.environ.get("PDP_WEIGHT_HIGH", "20"))

# Score-bucket thresholds
BUCKET_HIGH_THRESHOLD = int(os.environ.get("PDP_BUCKET_HIGH", "80"))
BUCKET_MEDIUM_THRESHOLD = int(os.environ.get("PDP_BUCKET_MEDIUM", "50"))

# Enable/disable CVE input (graceful degradation if Trivy not installed)
CVE_INPUT_ENABLED = os.environ.get("PDP_CVE_INPUT", "true").lower() == "true"


# ---------------------------------------------------------------------------
# Prometheus metrics
# ---------------------------------------------------------------------------
LABEL_COMPLIANCE = Gauge(
    "pdp_label_compliance",
    "1 if pod has all 6 ZTA labels, 0 otherwise",
    ["namespace", "pod"],
)
LABEL_DRIFT_TOTAL = Counter(
    "pdp_label_drift_total",
    "Total label drift events detected",
    ["namespace"],
)
TRUST_SCORE = Gauge(
    "pdp_trust_score",
    "Trust score (0-100) for each pod based on label coverage + CVE posture",
    ["namespace", "pod"],
)
SCORE_BUCKET = Gauge(
    "pdp_score_bucket",
    "Score bucket as numeric: 3=high, 2=medium, 1=low",
    ["namespace", "pod"],
)
PDP_RECONCILES = Counter(
    "pdp_reconcile_total", "Total reconcile cycles run"
)
CVE_CRITICAL_TOTAL = Gauge(
    "pdp_cve_critical_total",
    "Total critical CVEs across all scanned images in namespace",
    ["namespace"],
)
CVE_HIGH_TOTAL = Gauge(
    "pdp_cve_high_total",
    "Total high CVEs across all scanned images in namespace",
    ["namespace"],
)


# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO"),
    format="%(message)s",
)
log = logging.getLogger("pdp")


def _structured(level: str, **fields: Any) -> None:
    """Emit one valid JSON line per call (Filebeat-friendly)."""
    record = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "lvl": level,
        "comp": "pdp",
        **{k: ("" if v is None else v) for k, v in fields.items()},
    }
    sys.stdout.write(json.dumps(record, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def audit(event: str, **fields: Any) -> None:
    """Emit a structured audit JSON line for Filebeat to ship to Elasticsearch."""
    _structured("INFO", event=event, **fields)


# ---------------------------------------------------------------------------
# CVE posture from Trivy VulnerabilityReport CRs
# ---------------------------------------------------------------------------
_vr_cache: dict[str, dict[str, tuple[int, int]]] = {}
_vr_cache_ts: float = 0.0
_VR_CACHE_TTL = 30  # seconds


def _refresh_vr_cache(dyn_client: DynamicClient) -> None:
    """Fetch all VulnerabilityReport CRs and cache per-pod CVE counts."""
    global _vr_cache, _vr_cache_ts
    now = time.time()
    if now - _vr_cache_ts < _VR_CACHE_TTL:
        return
    try:
        vr_api = dyn_client.resources.get(
            api_version="aquasecurity.github.io/v1alpha1",
            kind="VulnerabilityReport",
        )
        reports = vr_api.get()
        new_cache: dict[str, dict[str, tuple[int, int]]] = {}
        for item in reports.items:
            ns = item.metadata.namespace
            labels = item.metadata.labels or {}
            pod_name = labels.get("trivy-operator.resource.name", "")
            summary = getattr(item.report, "summary", None)
            if summary is None:
                continue
            crit = int(getattr(summary, "criticalCount", 0) or 0)
            high = int(getattr(summary, "highCount", 0) or 0)
            if ns not in new_cache:
                new_cache[ns] = {}
            existing = new_cache[ns].get(pod_name, (0, 0))
            new_cache[ns][pod_name] = (
                max(existing[0], crit),
                max(existing[1], high),
            )
        _vr_cache = new_cache
        _vr_cache_ts = now
    except Exception as exc:
        log.warning(f"VulnerabilityReport fetch failed: {exc}")


def read_image_cve(
    dyn_client: DynamicClient | None,
    ns: str,
    pod_name: str,
    owner_name: str,
) -> tuple[int, int]:
    """Return (critical_count, high_count) for a pod from Trivy VR cache."""
    if not CVE_INPUT_ENABLED or dyn_client is None:
        return 0, 0
    _refresh_vr_cache(dyn_client)
    ns_cache = _vr_cache.get(ns, {})
    if owner_name and owner_name in ns_cache:
        return ns_cache[owner_name]
    if pod_name in ns_cache:
        return ns_cache[pod_name]
    for key, val in ns_cache.items():
        if pod_name.startswith(key) or key.startswith(
            pod_name.rsplit("-", 1)[0]
        ):
            return val
    return 0, 0


def _get_pod_owner(pod: Any) -> str:
    """Extract the immediate owner name (ReplicaSet, StatefulSet, etc.)."""
    refs = getattr(pod.metadata, "owner_references", None) or []
    for ref in refs:
        if ref.kind in ("ReplicaSet", "StatefulSet", "DaemonSet", "Job"):
            return ref.name
    return ""


# ---------------------------------------------------------------------------
# Score computation
# ---------------------------------------------------------------------------
def compute_score(
    labels: dict | None,
    critical_cve: int = 0,
    high_cve: int = 0,
) -> tuple[int, list[str], str]:
    """Compute weighted trust score and bucket.

    Returns (score, missing_labels, bucket).
    """
    labels = labels or {}
    missing = [lbl for lbl in REQUIRED_LABELS if lbl not in labels]
    missing_ratio = len(missing) / len(REQUIRED_LABELS)
    has_critical = 1 if critical_cve > 0 else 0
    has_high = 1 if high_cve > 0 else 0

    score = max(
        0,
        100
        - round(WEIGHT_LABEL * missing_ratio)
        - WEIGHT_CRITICAL_CVE * has_critical
        - WEIGHT_HIGH_CVE * has_high,
    )

    if score >= BUCKET_HIGH_THRESHOLD:
        bucket = "high"
    elif score >= BUCKET_MEDIUM_THRESHOLD:
        bucket = "medium"
    else:
        bucket = "low"

    return score, missing, bucket


def evaluate_labels(labels: dict | None) -> tuple[int, list[str]]:
    """Backward-compatible: return (trust_score, missing_labels)."""
    score, missing, _ = compute_score(labels)
    return score, missing


def evaluate_pod(pod: Any) -> tuple[int, list[str]]:
    """Compatibility helper for kubernetes V1Pod objects."""
    labels = (pod.metadata.labels or {}) if hasattr(pod, "metadata") else {}
    return evaluate_labels(labels)


# ---------------------------------------------------------------------------
# Pod patching
# ---------------------------------------------------------------------------
def patch_pod_trust(
    api: client.CoreV1Api,
    ns: str,
    name: str,
    score: int,
    bucket: str,
) -> None:
    """Patch pod with trust-score annotation AND score-bucket label."""
    body = {
        "metadata": {
            "annotations": {"zta.job7189/trust-score": str(score)},
            "labels": {"zta.job7189/score-bucket": bucket},
        }
    }
    try:
        api.patch_namespaced_pod(name=name, namespace=ns, body=body)
    except client.exceptions.ApiException as exc:
        if exc.status not in (404, 409):
            log.warning(f"patch failed ns={ns} pod={name}: {exc.reason}")


# ---------------------------------------------------------------------------
# kopf event handlers
# ---------------------------------------------------------------------------
@kopf.on.create("v1", "pods")
@kopf.on.update("v1", "pods", field="metadata.labels")
def on_pod_event(meta, namespace, name, **_kwargs):
    if namespace not in ZTA_NAMESPACES:
        return
    labels = meta.get("labels", {})
    score, missing, bucket = compute_score(labels)
    LABEL_COMPLIANCE.labels(namespace=namespace, pod=name).set(
        1 if not missing else 0
    )
    TRUST_SCORE.labels(namespace=namespace, pod=name).set(score)
    SCORE_BUCKET.labels(namespace=namespace, pod=name).set(
        {"high": 3, "medium": 2, "low": 1}.get(bucket, 0)
    )
    if missing:
        LABEL_DRIFT_TOTAL.labels(namespace=namespace).inc()
        audit("label-drift", ns=namespace, pod=name,
              missing=";".join(missing), score=score, bucket=bucket)


@kopf.on.delete("v1", "pods")
def on_pod_delete(namespace, name, **_kwargs):
    if namespace not in ZTA_NAMESPACES:
        return
    try:
        LABEL_COMPLIANCE.remove(namespace, name)
        TRUST_SCORE.remove(namespace, name)
        SCORE_BUCKET.remove(namespace, name)
    except KeyError:
        pass
    audit("pod-deleted", ns=namespace, pod=name)


# ---------------------------------------------------------------------------
# Periodic reconcile loop (full score with CVE input)
# ---------------------------------------------------------------------------
def reconcile_loop(
    api: client.CoreV1Api,
    dyn_client: DynamicClient | None,
) -> None:
    while True:
        try:
            PDP_RECONCILES.inc()
            for ns in ZTA_NAMESPACES:
                try:
                    pods = api.list_namespaced_pod(ns, watch=False)
                except client.exceptions.ApiException as exc:
                    if exc.status == 404:
                        continue
                    log.warning(f"list ns={ns} failed: {exc.reason}")
                    continue

                ns_crit_max = 0
                ns_high_max = 0
                for pod in pods.items:
                    if pod.metadata.deletion_timestamp:
                        continue
                    labels = pod.metadata.labels or {}
                    owner = _get_pod_owner(pod)
                    crit, high = read_image_cve(
                        dyn_client, ns, pod.metadata.name, owner
                    )
                    ns_crit_max = max(ns_crit_max, crit)
                    ns_high_max = max(ns_high_max, high)
                    score, missing, bucket = compute_score(
                        labels, crit, high
                    )
                    LABEL_COMPLIANCE.labels(
                        namespace=ns, pod=pod.metadata.name
                    ).set(1 if not missing else 0)
                    TRUST_SCORE.labels(
                        namespace=ns, pod=pod.metadata.name
                    ).set(score)
                    SCORE_BUCKET.labels(
                        namespace=ns, pod=pod.metadata.name
                    ).set({"high": 3, "medium": 2, "low": 1}.get(bucket, 0))
                    patch_pod_trust(api, ns, pod.metadata.name, score, bucket)

                CVE_CRITICAL_TOTAL.labels(namespace=ns).set(ns_crit_max)
                CVE_HIGH_TOTAL.labels(namespace=ns).set(ns_high_max)

            audit("reconcile-complete", namespaces=len(ZTA_NAMESPACES))
        except Exception as exc:  # noqa: BLE001 - keep loop alive
            log.error(f"reconcile error: {exc}")
        time.sleep(METRICS_RECONCILE_PERIOD)


# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------
@kopf.on.startup()
def on_startup(settings: kopf.OperatorSettings, **_kwargs):
    audit("startup", namespaces=",".join(ZTA_NAMESPACES), prom=PROMETHEUS_PORT)
    settings.posting.enabled = False
    start_http_server(PROMETHEUS_PORT)
    try:
        config.load_incluster_config()
    except config.ConfigException:
        config.load_kube_config()

    api = client.CoreV1Api()

    dyn_client: DynamicClient | None = None
    if CVE_INPUT_ENABLED:
        try:
            api_client = client.ApiClient()
            dyn_client = DynamicClient(api_client)
            audit("cve-input-enabled", source="trivy-operator")
        except Exception as exc:
            log.warning(f"DynamicClient init failed: {exc} — CVE input disabled")
            dyn_client = None

    threading.Thread(
        target=reconcile_loop, args=(api, dyn_client), daemon=True
    ).start()


# ---------------------------------------------------------------------------
# Entrypoint — invoked via `python /app/pdp_controller.py`
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    pod_identity = os.environ.get("POD_NAME", "zta-pdp")
    kopf.run(clusterwide=True, standalone=True, identity=pod_identity)
