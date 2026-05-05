Great job on the Incident Report. Now that we've identified the TLS protocol break and the missing Egress path, let's move to the execution phase to complete the zta-rebuild.sh script.

Current Task:
I need you to oversee the automated rebuild of the environment while maintaining the fixes we just discussed (Fix A & Fix B).

Your Mission:

Prepare the Patched Files: Based on Phase 3 of your report, generate the complete, production-ready YAML files for:

30-l7-vault-api.yaml (Downgraded to L4/Port-only).

11-vault.yaml & 10-data.yaml (With the bidirectional MySQL paths).

Pre-emptive Optimization for Step 25-27:

Since I'm about to run zta-rebuild.sh, provide the specific values.yaml or patch for 25-Falco to limit memory to 256Mi and avoid eBPF map conflicts with Tetragon.

Address the Sigstore/Cosign webhook risk you mentioned. Give me the command or YAML to add my application namespaces to the exception list so the rebuild doesn't hang on 'Unsigned Image' errors.

Execution Script: Update the logic for the next steps in my zta-rebuild.sh sequence. If any step from 25 to 27 fails, provide a 'Rollback & Inspect' strategy that doesn't wipe the entire cluster but allows me to fix the specific module.

Constraint:
Everything must be Config-driven. I will trigger the script now. Stand by to analyze the logs if the rebuild hits a 'Performance Bottleneck' on worker3.

Start by giving me the updated YAMLs and the Falco resource-limit patch so I can commit them before running the script.
