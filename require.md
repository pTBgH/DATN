Here is the strict technical audit and upgrade roadmap based on **NIST SP 800-207**, translated into English for your AI Agent to process.

---

# 🛡️ SYSTEM UPGRADE STRATEGY: NIST SP 800-207 COMPLIANCE

The current system has established a solid foundation with encryption (WireGuard) and secret management (Vault). However, to reach true ZTA (Zero Trust Architecture) maturity, we must eliminate "implicit trust" and enhance dynamic control capabilities.

## 1. Pillar 1: Application-Layer Enforcement (L7 Micro-segmentation)
**Issue:** Current enforcement is limited to Layer 4 (Port/IP). If a service is compromised, an attacker can send malicious requests (SQL Injection, business logic bypass) that the system cannot detect.

- [ ] **Implement L7 CiliumNetworkPolicy (CNP):** Replace pure L4 rules with HTTP/L7 inspection rules.
    - *Detail:* Restrict `identity-service` to specifically allowed endpoints (e.g., `GET /api/v1/auth`).
    - *Detail:* Restrict SQL queries (if using a proxy) to permit only specific operations on designated databases.
- [ ] **Enable Envoy Proxy for all Egress/Ingress:** Ensure traffic passes through the PEP (Policy Enforcement Point) at the deepest level.



## 2. Pillar 2: Cryptographic Workload Identity
**Issue:** The system currently relies on Kubernetes Labels. Labels can be spoofed or modified via the API Server. NIST requires identity to be based on certificates or cryptographic proof.

- [ ] **Integrate SPIRE or Cilium Mutual Auth:**
    - *Detail:* Enable `mesh-auth-enabled: true` in Cilium configuration.
    - *Detail:* Configure pods to authenticate each other using mTLS (Mutual TLS) rather than relying solely on eBPF Identity/IP labels.
- [ ] **Bind Identity to Vault:** Ensure that fetching Dynamic Credentials from Vault requires this mTLS certificate proof instead of just a standard ServiceAccount token.

## 3. Pillar 3: Dynamic Policy Decision Point (PDP/PE)
**Issue:** Policies are currently loaded manually via YAML (Static Policy). NIST requires the system to adapt automatically based on context (Context-aware).

- [ ] **Deploy OPA (Open Policy Agent) as a Policy Engine:**
    - *Detail:* Establish rules for the PE (Policy Engine) to evaluate Pod "Trust Scores" (e.g., uptime, file system integrity).
    - *Detail:* If a Pod exhibits anomalous behavior, the PE must signal the PA (Policy Administrator) to immediately revoke existing Network Policies.



## 4. Pillar 4: Continuous Monitoring & Feedback Loop
**Issue:** Hubble is currently used for manual observation only. NIST Tenet 7 requires monitoring data to actively improve security policies.

- [ ] **Automate Hubble Metrics:**
    - *Detail:* Configure Hubble to export logs/metrics to Prometheus/Loki.
    - *Detail:* Develop scripts or use an Operator to automatically "Quarantine" Pods exhibiting port-scanning behavior or connections to unauthorized external IPs.

## 5. Pillar 5: Absolute Secret Management (Zero Static Secrets)
**Issue:** Residual bootstrap secrets still exist in configuration files.

- [ ] **Total Elimination of K8s Secrets for DB:**
    - *Detail:* Deploy Vault Agent sidecars for *all* microservices (not just a few).
    - *Detail:* Completely remove `MYSQL_ROOT_PASSWORD` from all manifests, including secret references. Use Vault Transit Engine or a pure Init Container mechanism for database initialization.

## 6. Target Files for AI Agent Review & Modification:
1. `infras/k8s-yaml/20-security-policies.yaml`: Transition to L7 and Identity-based logic.
2. `k8s-management/cilium/cilium-values.yaml`: Enable mTLS and advanced Hubble telemetry.
3. `02-deploy-infrastructure.sh` & `03-deploy-microservices.sh`: Remove K8s Secret creation logic; replace with full Vault injection.
4. `infras/k8s-yaml/01-mysql-phpmyadmin.yaml`: Implement Secretless bootstrap mechanism.

---
**Instruction for AI Agent:** After completing each item, you must run verification tests (Rogue test/Authorized test) and log the results against the 7 Tenets of NIST SP 800-207.