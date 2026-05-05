Act as a Senior DevSecOps Engineer and SRE specialist. I am currently at Step 24: Hubble Export. Since enabling this step, my system has entered a 'chaos' state: 7 Laravel services are crashing continuously, and there is instability in both Cilium and the Kube-system.

Your Mission:
Instead of waiting for me to provide all details, I want you to proactively lead the troubleshooting process based on the following context:

Architecture: ZTA based on NIST SP 800-207, using Cilium (mTLS + WireGuard), HashiCorp Vault, and Keycloak on a Kind cluster.

Constraints: I prioritize traceability. All solutions must be file-based (YAML/Helm values). No ad-hoc CLI fixes.

Hardware: This is a local Lab environment. Resources (RAM/CPU) are likely tight.

Execution Steps for you:

Phase 1 (Diagnosis): Tell me exactly which kubectl commands I need to run to give you the data you need (Focus on OOMKilled vs. Policy Drops vs. Probe Timeouts).

Phase 2 (Anticipation): Based on the fact that 7 Laravel services are crashing, hypothesize the 3 most likely root causes (e.g., Resource Starvation, mTLS Latency, or CNI Choke).

Phase 3 (Auto-Fix): Provide a 'Safety-First' YAML patch that I can apply immediately to stabilize the cluster (e.g., limiting Hubble resource usage and loosening application probes).

Phase 4 (Moving Forward): Once we stabilize this, you will guide me through the next steps. If I encounter an error, you must analyze if it's a 'Security Conflict' or a 'Performance Bottleneck' before suggesting a fix.

Right now, start by telling me which logs/metrics I should pull and provide the initial stabilization YAML.
