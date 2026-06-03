#!/bin/sh
set -eu

APP_DIR=${APP_DIR:-/app-secrets}
RELOAD_URL=${RELOAD_URL:-http://127.0.0.1:8080/internal/reload-db}
RELOAD_TOKEN=${RELOAD_TOKEN:-}
CHECK_INTERVAL=${CHECK_INTERVAL:-5}
MAX_NOTIFY_RETRIES=${MAX_NOTIFY_RETRIES:-3}

md5_of() {
  md5sum "$1" 2>/dev/null | cut -d' ' -f1 || echo ""
}

notify_app() {
  # Primary: HTTP hot-reload endpoint (zero-downtime for services that implement it)
  if [ -n "$RELOAD_TOKEN" ]; then
    i=0
    while [ "$i" -lt "$MAX_NOTIFY_RETRIES" ]; do
      if curl -s -f -m 3 -X POST -H "X-Internal-Token: $RELOAD_TOKEN" "$RELOAD_URL"; then
        echo "$(date -Is) notify: HTTP reload success"
        return 0
      fi
      i=$((i+1))
      sleep 1
    done
  fi

  # Fallback: find php-fpm master via /proc and send SIGUSR2 (graceful restart)
  # shareProcessNamespace=true makes all container PIDs visible
  for p in /proc/[0-9]*/cmdline; do
    if grep -ql 'php-fpm: master' "$p" 2>/dev/null; then
      pid=$(echo "$p" | cut -d'/' -f3)
      if kill -USR2 "$pid" 2>/dev/null; then
        echo "$(date -Is) notify: sent USR2 to php-fpm master (pid $pid)"
        return 0
      fi
    fi
  done

  return 1
}

# Initialize checksum to skip first boot detection
LAST=""
if [ -f "$APP_DIR/.env" ]; then
  LAST=$(md5_of "$APP_DIR/.env")
fi

while true; do
  if [ -f "$APP_DIR/.env" ]; then
    SUM=$(md5_of "$APP_DIR/.env")
    if [ "$SUM" != "$LAST" ]; then
      LAST="$SUM"
      echo "$(date -Is) env-watcher: .env changed, notifying app"

      if ! notify_app; then
        echo "$(date -Is) env-watcher: notify failed (HTTP + signal)"
      fi
    fi
  fi
  sleep "$CHECK_INTERVAL"
done
