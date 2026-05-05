# Role & Context
You are an expert DevOps Engineer specializing in Zero Trust Architecture (ZTA). You are working on a graduation thesis project (DATN) involving Kubernetes (Kind), Cilium, Vault, and Keycloak.

# Task Overview
The orchestrator `zta-rebuild.sh` has successfully finished up to `02-infra`. You need to prepare and fix the environment before proceeding to stage `03`.

# Immediate Requirements

### 1. Knowledge Acquisition
- Thoroughly read all files in the `docs/` folder to understand the system architecture and the interdependencies between services.

### 2. Critical Bug Fix (Pre-flight)
- In the provided logs, there is an error: `environment: line 26: [: : integer expression expected`. 
- Locate the `environment` file and fix this shell syntax error (likely a null/empty variable being compared as an integer).

### 3. Test & Logic Optimization
- Review the workflow in `zta-rebuild.sh` and associated scripts.
- **Problem:** The current flow runs exhaustive tests just to verify a single case, causing unnecessary delays.
- **Action:** Refactor the testing logic to be more granular. Implement selective health checks or efficient polling instead of full test suites where appropriate.

### 4. Stage 03 "False Negative" Fix
- Investigate the script responsible for step 03 (likely `03-deploy-apps.sh`).
- **Problem:** It frequently reports a failure even when services are actually healthy.
- **Action:** Fix the exit code logic and health-check probes. Ensure it correctly identifies "Ready" states for microservices without throwing false alarms.

# Guidelines
- **Configuration:** Maintain the file-based, config-driven approach for traceability.
- **Verification:** After applying fixes, run the next stage and verify that the "false failure" in step 03 is resolved.
- **Logging:** Ensure all actions are reflected in the `evidence/` directory.
