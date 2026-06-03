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
      echo "[watch-env] .env changed; syncing to /var/www/.env and restarting php-fpm" >&2 || true
      cp -f /app-secrets/.env /var/www/.env 2>/dev/null || true
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
