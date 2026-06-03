#!/usr/bin/env bash
# knowledge-base/migration/scripts/03-worker-join.sh
#
# Backward-compatibility wrapper for phases/worker-join.sh.
# Prefer:  sudo -E bash knowledge-base/migration/scripts/bootstrap.sh --server=NN  (NN=02,03,04)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/phases/worker-join.sh" "$@"
