#!/usr/bin/env bash
# doc/migration/scripts/04-cilium-install.sh
#
# Backward-compatibility wrapper for phases/cilium.sh.
# Prefer:  sudo -E bash doc/migration/scripts/bootstrap.sh --server=01

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/phases/cilium.sh" "$@"
