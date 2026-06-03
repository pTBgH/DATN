#!/usr/bin/env bash
# knowledge-base/migration/scripts/02-control-plane-init.sh
#
# Backward-compatibility wrapper for phases/control-plane.sh.
# Prefer:  sudo -E bash knowledge-base/migration/scripts/bootstrap.sh --server=01

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/phases/control-plane.sh" "$@"
