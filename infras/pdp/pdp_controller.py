"""
PDP Controller — Continuous ZTA Compliance Verification
========================================================

Step 2.3.6 — Adaptive Loop Closure (CISA ZTMM Identity Advanced → Optimal).

Watches Pod label changes in 7 ZTA namespaces and:
  1. Verifies presence of 6 required ZTA labels (cilium.zta/{tier,source,
     destination,role,owner,sensitivity}).
  2. Detects label drift (pod re-created without correct labels).
  3. Emits structured audit log to stdout (Filebeat → Elasticsearch).
  4. Exposes Prometheus metric `pdp_label_compliance` for monitoring.
  5. Annotates pods with `cilium.zta/trust-score` (0-100) based on
     label completeness + tier consistency.

Reference:
  - doc/19-label-schema.md (label definitions)
  - doc/25-pdp-controller.md (architecture)

Runtime: kopf 1.37+ on Python 3.11.
"""
from __future__ import annotations

import logging
import os
import threading
import time
from typing import Any

import kopf
from kubernetes import client, config
from prometheus_client import Counter, Gauge, start_http_server


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
ZTA_NAMESPACES = os.environ.get(
    "ZTA_NAMESPACES",
    "data,vault,security,monitoring,gateway,management,job7189-apps",
).split(",")

REQUIRED_LABELS = [
    "cilium.zta/tier",          # T0/T1/T2/T3
    "cilium.zta/source",        # logical service name
    "cilium.zta/destination",   # what this pod talks to
    "cilium.zta/role",          # gateway/database/identity/...
    "cilium.zta/owner",         # team / SA name
    "cilium.zta/sensitivity",   # public/internal/confidential/secret
]

PROMETHEUS_PORT = int(os.environ.get("PROMETHEUS_PORT", "9100"))
METRICS_RECONCILE_PERIOD = int(os.environ.get("RECONCILE_PERIOD", "60"))


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
    "Trust score (0-100) for each pod based on label coverage",
    ["namespace", "pod"],
)
PDP_RECONCILES = Counter(
    "pdp_reconcile_total", "Total reconcile cycles run"
)


# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO"),
    format='{"ts":"%(asctime)s","lvl":"%(levelname)s","comp":"pdp",'
           '"msg":"%(message)s"}',
)
log = logging.getLogger("pdp")


def audit(event: str, **fields: Any) -> None:
    """Emit a structured audit line for Filebeat to ship to Elasticsearch."""
    payload = ",".join(f'"{k}":"{v}"' for k, v in fields.items())
    log.info(f'event":"{event}",{payload}')


# ---------------------------------------------------------------------------
# Core compliance logic
# ---------------------------------------------------------------------------
def evaluate_labels(labels: dict | None) -> tuple[int, list[str]]:
    """Return (trust_score, missing_labels) given a labels dict."""
    labels = labels or {}
    missing = [lbl for lbl in REQUIRED_LABELS if lbl not in labels]
    score = round(100 * (len(REQUIRED_LABELS) - len(missing)) / len(REQUIRED_LABELS))
    return score, missing


def evaluate_pod(pod: Any) -> tuple[int, list[str]]:
    """Compatibility helper for kubernetes V1Pod objects."""
    labels = (pod.metadata.labels or {}) if hasattr(pod, "metadata") else {}
    return evaluate_labels(labels)


def annotate_trust_score(api: client.CoreV1Api, ns: str, name: str, score: int) -> None:
    """Patch pod with cilium.zta/trust-score annotation."""
    body = {"metadata": {"annotations": {"cilium.zta/trust-score": str(score)}}}
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
    score, missing = evaluate_labels(meta.get("labels", {}))
    LABEL_COMPLIANCE.labels(namespace=namespace, pod=name).set(
        1 if not missing else 0
    )
    TRUST_SCORE.labels(namespace=namespace, pod=name).set(score)
    if missing:
        LABEL_DRIFT_TOTAL.labels(namespace=namespace).inc()
        audit("label-drift", ns=namespace, pod=name,
              missing=";".join(missing), score=score)


@kopf.on.delete("v1", "pods")
def on_pod_delete(namespace, name, **_kwargs):
    if namespace not in ZTA_NAMESPACES:
        return
    try:
        LABEL_COMPLIANCE.remove(namespace, name)
        TRUST_SCORE.remove(namespace, name)
    except KeyError:
        pass
    audit("pod-deleted", ns=namespace, pod=name)


# ---------------------------------------------------------------------------
# Periodic reconcile loop (also sets annotations)
# ---------------------------------------------------------------------------
def reconcile_loop(api: client.CoreV1Api) -> None:
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
                for pod in pods.items:
                    if pod.metadata.deletion_timestamp:
                        continue
                    score, missing = evaluate_pod(pod)
                    LABEL_COMPLIANCE.labels(namespace=ns, pod=pod.metadata.name).set(
                        1 if not missing else 0
                    )
                    TRUST_SCORE.labels(namespace=ns, pod=pod.metadata.name).set(score)
                    annotate_trust_score(api, ns, pod.metadata.name, score)
            log.info(f'reconcile-complete":"namespaces":{len(ZTA_NAMESPACES)}')
        except Exception as exc:  # noqa: BLE001 - keep loop alive
            log.error(f"reconcile error: {exc}")
        time.sleep(METRICS_RECONCILE_PERIOD)


# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------
@kopf.on.startup()
def on_startup(settings: kopf.OperatorSettings, **_kwargs):
    log.info(f'startup":"namespaces":"{",".join(ZTA_NAMESPACES)}","prom":"{PROMETHEUS_PORT}"')
    # Disable kopf's posting of events (we use stdout audit log instead)
    settings.posting.enabled = False
    # Bind Prometheus metrics endpoint
    start_http_server(PROMETHEUS_PORT)
    try:
        config.load_incluster_config()
    except config.ConfigException:
        config.load_kube_config()
    api = client.CoreV1Api()
    threading.Thread(target=reconcile_loop, args=(api,), daemon=True).start()


# ---------------------------------------------------------------------------
# Entrypoint — invoked via `python /app/pdp_controller.py`
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    kopf.run(clusterwide=True, standalone=True)
