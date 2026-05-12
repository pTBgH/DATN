#!/usr/bin/env bash
# doc/migration/scripts/01-host-prep.sh
#
# Backward-compatibility wrapper. The actual logic now lives at
# `phases/host-prep.sh`, executed by the new orchestrator `bootstrap.sh`.
#
# Existing muscle memory still works — this wrapper just execs the new
# phase script. New users should use:
#   sudo -E bash doc/migration/scripts/bootstrap.sh --server=NN
# which handles host-prep + the other phases for the given VM.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/phases/host-prep.sh" "$@"
