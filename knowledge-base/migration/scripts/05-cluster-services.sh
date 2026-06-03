#!/usr/bin/env bash
# knowledge-base/migration/scripts/05-cluster-services.sh
#
# Backward-compatibility wrapper for phases/cluster-services.sh.
# Prefer:  sudo -E bash knowledge-base/migration/scripts/bootstrap.sh --server=01

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/phases/cluster-services.sh" "$@"
