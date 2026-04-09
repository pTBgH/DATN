#!/bin/sh
set -eu
SENTINEL=/app-secrets/.env.db.lease
LAST=""
while true; do
  if [ -f "$SENTINEL" ]; then
    cur=$(cat "$SENTINEL" 2>/dev/null || echo "")
    if [ "$cur" != "$LAST" ]; then
      LAST="$cur"
      date -Iseconds >&2 || true
      echo "[watch-env] sentinel changed; restarting php-fpm" >&2 || true
      if command -v supervisorctl >/dev/null 2>&1; then
        supervisorctl restart php8-fpm || true
      else
        if [ -f /run/php/php-fpm.pid ]; then
          kill -USR2 "$(cat /run/php/php-fpm.pid)" || true
        fi
      fi
    fi
  fi
  sleep 5
done
