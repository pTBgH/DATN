#!/bin/sh
set -eu
WATCH_FILE=/app-secrets/.env
LAST_SUM=""
while true; do
  if [ -f "$WATCH_FILE" ]; then
    SUM=$(md5sum "$WATCH_FILE" 2>/dev/null | cut -d' ' -f1 || echo "")
    if [ "$SUM" != "$LAST_SUM" ]; then
      LAST_SUM="$SUM"
      date -Iseconds >&2 || true
      echo "[watch-env] .env changed; restarting php-fpm" >&2 || true
      if command -v supervisorctl >/dev/null 2>&1; then
        supervisorctl restart php8-fpm || true
      else
        if [ -f /run/php/php-fpm.pid ]; then
          kill -USR2 "$(cat /run/php/php-fpm.pid)" || true
        fi
      fi
    fi
  fi
  sleep 10
done
