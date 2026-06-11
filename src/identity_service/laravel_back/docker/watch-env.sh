#!/bin/sh
set -eu

# Watch the Vault-rendered dynamic DB credentials and reload the app when they
# rotate (Vault renews the lease every ~10-15 minutes).
#
# IMPORTANT (root cause of a past 502 incident):
#   Restart ONLY the web/worker programs. NEVER restart the whole supervisor
#   group and NEVER restart watch-env itself. The previous version ran
#   `supervisorctl restart laravel-service:*`, which restarted watch-env too;
#   watch-env got SIGTERM'd, lost its in-memory dedup state on respawn,
#   re-detected a "change" and restarted again -> an infinite restart storm
#   every few seconds -> nginx/php-fpm bounced -> Kong returned 502
#   (connect() failed (111: Connection refused) while connecting to upstream).
#
#   This version keeps its dedup state in files under /tmp (survives restarts),
#   enforces a cooldown, and restarts only nginx/php-fpm/queue.

WATCH_FILE=/app-secrets/.env.db.lease
LAST_SUM_FILE=/tmp/watch-env.last-sum
LAST_RESTART_TIME_FILE=/tmp/watch-env.last-restart-time
MIN_RESTART_INTERVAL=300  # >= 5 min between restarts (creds rotate every ~10-15 min)

# Programs to reload on rotation. Group-qualified names are REQUIRED because the
# programs live in the [group:laravel-service] group. watch-env and the one-shot
# laravel-schedule are intentionally excluded.
RELOAD_TARGETS="laravel-service:nginx laravel-service:php8-fpm laravel-service:laravel-queue_00"

# Load persistent state (survives process restarts so we never loop).
LAST_SUM=$(cat "$LAST_SUM_FILE" 2>/dev/null || echo "")
LAST_RESTART_TIME=$(cat "$LAST_RESTART_TIME_FILE" 2>/dev/null || echo "0")

while true; do
  if [ -f "$WATCH_FILE" ]; then
    SUM=$(md5sum "$WATCH_FILE" 2>/dev/null | cut -d' ' -f1 || echo "")
    NOW=$(date +%s)

    if [ -n "$SUM" ] && [ "$SUM" != "$LAST_SUM" ] && [ $((NOW - LAST_RESTART_TIME)) -gt "$MIN_RESTART_INTERVAL" ]; then
      echo "$SUM" > "$LAST_SUM_FILE"
      echo "$NOW" > "$LAST_RESTART_TIME_FILE"
      LAST_SUM="$SUM"
      LAST_RESTART_TIME="$NOW"

      # Sync the freshly-rotated credentials into the env file Laravel reads.
      if [ -f /app-secrets/.env ]; then
        echo "[watch-env] vault creds rotated; syncing /app-secrets/.env -> /var/www/.env" >&2 || true
        cp -f /app-secrets/.env /var/www/.env 2>/dev/null || true
      fi

      if command -v supervisorctl >/dev/null 2>&1; then
        echo "[watch-env] reloading web/worker (NOT watch-env): $RELOAD_TARGETS" >&2 || true
        # shellcheck disable=SC2086
        supervisorctl restart $RELOAD_TARGETS 2>/dev/null || true
      else
        # Fallback: graceful php-fpm reload via SIGUSR2 (shareProcessNamespace=true).
        for p in /proc/[0-9]*/cmdline; do
          if grep -ql 'php-fpm: master' "$p" 2>/dev/null; then
            kill -USR2 "$(echo "$p" | cut -d'/' -f3)" 2>/dev/null || true
          fi
        done
      fi
    fi
  fi
  sleep 10
done
