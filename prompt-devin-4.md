Hiện tại mình chạy đến đây (chạy zta-rebuild.sh to 23)
════════════════════════════════════════════════════════
▶ 23-policy-controller — Deploy sigstore policy-controller (image admission)
  cmd: bash scripts/zta-deploy-policy-controller.sh
  log: /home/ptb/project/DATN/evidence/rebuild_20260505_114551/23-policy-controller.log
════════════════════════════════════════════════════════
  timeout: 1800s
  ✓ 23-policy-controller OK (339s)

    Switch to enforce mode:
      kubectl patch clusterimagepolicy zta-job7189-apps-signed --type=merge -p '{"spec":{"mode":"enforce"}}'

    Run 09-verify-zta.sh — Test 4j checks policy-controller health.

════════════════════════════════════════════════════════
▶ 24-hubble-export — Enable Hubble flow export to Elasticsearch
  cmd: bash scripts/zta-deploy-hubble-export.sh --enable-cilium-export
  log: /home/ptb/project/DATN/evidence/rebuild_20260505_114551/24-hubble-export.log
════════════════════════════════════════════════════════
  timeout: 1800s
  ✓ 24-hubble-export OK (721s)
      kubectl -n monitoring logs ds/hubble-flow-shipper --tail=20 | grep -i 'connection\|publish'
      kubectl -n monitoring exec es-0 -- curl -s http://localhost:9200/_cat/indices/hubble-flows-*


    Run 09-verify-zta.sh — Test 4l checks pipeline health.
  Reached --to=24-hubble-export — stopping.
  Summary written to /home/ptb/project/DATN/evidence/rebuild_20260505_114551/SUMMARY.md

============================================================
 ✅  Rebuild orchestrator finished in 4567s
    Logs:    /home/ptb/project/DATN/evidence/rebuild_20260505_114551
    Summary: /home/ptb/project/DATN/evidence/rebuild_20260505_114551/SUMMARY.md
============================================================

Trước đó có build lại và nó đã lỗi ở bước này
════════════════════════════════════════════════════════
▶ 26-gatekeeper — Deploy OPA Gatekeeper + ZTA constraints
  cmd: bash scripts/zta-deploy-gatekeeper.sh
  log: /home/ptb/project/DATN/evidence/rebuild_20260505_092417/26-gatekeeper.log
════════════════════════════════════════════════════════
  timeout: 600s
  ✗ 26-gatekeeper FAILED (exit=1, 52s)
  ──── DIAGNOSTICS for failed step '26-gatekeeper' ────
  >>> full log (10 lines) of /home/ptb/project/DATN/evidence/rebuild_20260505_092417/26-gatekeeper.log <<<
    | ============================================================
    | ZTA Step 2.3.5 — OPA Gatekeeper (PEP Admission)
    | Mode: INSTALL+APPLY
    | ============================================================
    | [1/4] Installing OPA Gatekeeper 3.16.3 via helm...
    | Hang tight while we grab the latest from your chart repositories...
    | ...Successfully got an update from the "gatekeeper" chart repository
    | Update Complete. ⎈Happy Helming!⎈
    | namespace/gatekeeper-system created
    | Error: INSTALLATION FAILED: failed to install CRD crds/syncset-customresourcedefinition.yaml: Timeout: request did not complete within requested timeout - context deadline exceeded

  >>> non-Running / restarting pods <<<


Nó fail thế và chết luôn máy ảo của mình nên bạn phải đặc biệt cẩn thận khi chạy lệnh, đừng tiếc thời gian chạy test trạng thái của máy trước nhé

Giờ thì hãy fix cho mình

Đừng hỏi quá nhiều, bypass hết luôn đi, tuy nhiên tuyệt đối không commit hay làm gì github nhé, làm gì thì cũng phải cập nhật folder docs (cái này là knowledge base) và cập nhật và script nhé
