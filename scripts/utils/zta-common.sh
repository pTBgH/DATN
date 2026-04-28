#!/usr/bin/env bash

yellow() { printf '\033[1;33m%s\033[0m\n' "$*"; }

wait_for_dns() {
  local hosts=("$@")
  local timeout="${ZTA_DNS_WAIT_TIMEOUT:-120}"
  local interval="${ZTA_DNS_WAIT_INTERVAL:-5}"
  local elapsed=0

  [ "${#hosts[@]}" -gt 0 ] || hosts=(github.com)

  while true; do
    local failed=()
    for host in "${hosts[@]}"; do
      if ! getent ahosts "$host" >/dev/null 2>&1; then
        failed+=("$host")
      fi
    done

    if [ "${#failed[@]}" -eq 0 ]; then
      return 0
    fi

    if [ "$elapsed" -ge "$timeout" ]; then
      yellow "    DNS still failing after ${timeout}s: ${failed[*]}"
      yellow "    Check host resolver: resolvectl status / sudo systemctl restart systemd-resolved"
      return 1
    fi

    yellow "    DNS not ready for: ${failed[*]} — retrying in ${interval}s (${elapsed}/${timeout}s)"
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done
}

helm_repo_update_retry() {
  local attempts="${ZTA_HELM_REPO_UPDATE_RETRIES:-5}"
  local delay="${ZTA_HELM_REPO_UPDATE_BACKOFF:-10}"
  local cmd=(helm repo update "$@")

  for attempt in $(seq 1 "$attempts"); do
    if "${cmd[@]}"; then
      return 0
    fi
    yellow "    helm repo update failed (attempt ${attempt}/${attempts})"
    [ "$attempt" -lt "$attempts" ] || break
    sleep "$delay"
  done

  return 1
}
