Vault rotation test — records and playbook

What I collected:
- Agent config (from `/home/vault/config.json` in `identity-service-65977b665-fwsks`)
- Rendered secret `/vault/secrets/.env.db` (current DB_USERNAME/DB_PASSWORD)
- A sample dynamic-creds response from Vault showing `lease_duration=3600`
- `kubectl describe` output summary and recent events/logs seen earlier

What this folder contains:
- `commands.sh` — scripted commands to backup role, set test TTL (5 minutes), revoke leases, and verify rotation. **Requires a Vault token with permission to write/read `database/roles/*` and revoke leases.**
- `backups/role-backup.json` — placeholder; script will write the current role JSON here before changes.
- `outputs/` — collected outputs from inspection (agent-config, env-db, creds response, pod-describe)

Next steps to run the test (pick one):
- Provide a Vault admin token (securely) and ask me to run `commands.sh` here.
- Or run `commands.sh` yourself after setting `VAULT_ADDR` and `VAULT_TOKEN` env vars.

Important: reducing TTL will increase churn on the DB (create/revoke users). After test, restore the original role from `backups/role-backup.json`.
