#!/bin/sh
set -eu

# Watch vault-agent dynamic credentials file (renewed every ~10-15 minutes)
WATCH_FILE=/vault/secrets/.env.db
LAST_SUM_FILE=/tmp/watch-env.last-sum
LAST_RESTART_TIME_FILE=/tmp/watch-env.last-restart-time
MIN_RESTART_INTERVAL=300  # Minimum 5 minutes between restarts (credentials rotated every 10-15 min)

# Load persistent state from files (survives process restarts)
LAST_SUM=$(cat "$LAST_SUM_FILE" 2>/dev/null || echo "")
LAST_RESTART_TIME=$(cat "$LAST_RESTART_TIME_FILE" 2>/dev/null || echo "0")

while true; do
  if [ -f "$WATCH_FILE" ]; then
    SUM=$(md5sum "$WATCH_FILE" 2>/dev/null | cut -d' ' -f1 || echo "")
    CURRENT_TIME=$(date +%s)
    
    if [ "$SUM" != "$LAST_SUM" ] && [ $((CURRENT_TIME - LAST_RESTART_TIME)) -gt $MIN_RESTART_INTERVAL ]; then
      echo "$SUM" > "$LAST_SUM_FILE"
      echo "$CURRENT_TIME" > "$LAST_RESTART_TIME_FILE"
      LAST_SUM="$SUM"
      LAST_RESTART_TIME=$CURRENT_TIME
      date -Iseconds >&2 || true
      
      # Copy vault-agent rendered .env to app directory
      # vault-agent renders: .env (full merged), .env.db (db creds), .env.common (common vars)
      if [ -f /vault/secrets/.env ]; then
        echo "[watch-env] vault .env.db changed; syncing from /vault/secrets/.env to /var/www/.env" >&2 || true
        cp -f /vault/secrets/.env /var/www/.env 2>/dev/null || true
      fi
      
      # Also try to extract just DB credentials if .env doesn't have them
      if [ -f /vault/secrets/.env.db ]; then
        DB_USERNAME=$(grep DB_USERNAME /vault/secrets/.env.db | cut -d= -f2 | tr -d '"' 2>/dev/null || echo "")
        DB_PASSWORD=$(grep DB_PASSWORD /vault/secrets/.env.db | cut -d= -f2 | tr -d '"' 2>/dev/null || echo "")
        if [ -n "$DB_USERNAME" ] && [ -n "$DB_PASSWORD" ]; then
          sed -i "s/^DB_USERNAME=.*/DB_USERNAME=\"$DB_USERNAME\"/" /var/www/.env 2>/dev/null || true
          sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=\"$DB_PASSWORD\"/" /var/www/.env 2>/dev/null || true
          echo "[watch-env] Updated DB credentials in /var/www/.env: $DB_USERNAME" >&2 || true
        fi
      fi
      
      # Restart PHP-FPM and Laravel workers (but NOT watch-env to preserve state)
      if command -v supervisorctl >/dev/null 2>&1; then
        echo "[watch-env] Restarting laravel-service processes" >&2 || true
        supervisorctl restart nginx php8-fpm laravel-schedule laravel-queue:* 2>/dev/null || true
      else
        if [ -f /run/php/php-fpm.pid ]; then
          echo "[watch-env] Signaling PHP-FPM" >&2 || true
          kill -USR2 "$(cat /run/php/php-fpm.pid)" || true
        fi
      fi
    fi
  fi
  sleep 10
done
