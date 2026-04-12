#!/bin/sh
set -eu

VAULT_DIR=${VAULT_DIR:-/vault/secrets}
APP_DIR=${APP_DIR:-/app-secrets}
RELOAD_URL=${RELOAD_URL:-http://127.0.0.1:8080/internal/reload-db}
RELOAD_TOKEN=${RELOAD_TOKEN:-}
PIDFILE=${APP_PIDFILE:-/var/run/php-fpm.pid}
CHECK_INTERVAL=${CHECK_INTERVAL:-5}
MAX_NOTIFY_RETRIES=${MAX_NOTIFY_RETRIES:-3}

md5_of() {
  md5sum "$1" 2>/dev/null | cut -d' ' -f1 || echo ""
}

notify_app() {
  if [ -n "$RELOAD_TOKEN" ]; then
    i=0
    while [ "$i" -lt "$MAX_NOTIFY_RETRIES" ]; do
      if curl -s -f -m 3 -X POST -H "X-Internal-Token: $RELOAD_TOKEN" "$RELOAD_URL"; then
        echo "$(date -Is) notify: success"
        return 0
      fi
      i=$((i+1))
      sleep 1
    done
  fi

  # fallback: send signal to app PID
  if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null || echo "")
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill -USR1 "$pid" && { echo "$(date -Is) signaled pid $pid"; return 0; } || true
    fi
  fi

  return 1
}

LAST=""

while true; do
  if [ -f "$VAULT_DIR/.env.db" ]; then
    SUM=$(md5_of "$VAULT_DIR/.env.db")
    if [ "$SUM" != "$LAST" ]; then
      tmpfile="${APP_DIR}/.env.tmp.$$"
      # Build merged env atomically
      cat "$VAULT_DIR/.env.common" 2>/dev/null > "$tmpfile" || true
      cat "$VAULT_DIR/.env.db" >> "$tmpfile" 2>/dev/null || true
      [ -f "$VAULT_DIR/.env.extra" ] && cat "$VAULT_DIR/.env.extra" >> "$tmpfile" || true
      chmod 644 "$tmpfile" || true
      mv -f "$tmpfile" "$APP_DIR/.env"

      # copy lease atomically
      if [ -f "$VAULT_DIR/.env.db.lease" ]; then
        cp -f "$VAULT_DIR/.env.db.lease" "$APP_DIR/.env.db.lease" || true
        chmod 644 "$APP_DIR/.env.db.lease" || true
      fi

      LAST="$SUM"
      echo "$(date -Is) env-watcher: updated env and lease"

      if ! notify_app; then
        echo "$(date -Is) env-watcher: notify failed"
      fi
    fi
  fi
  sleep "$CHECK_INTERVAL"
done
