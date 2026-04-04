#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "${SCRIPT_DIR}/infras/k8s-yaml/vault-scripts/08_check_backend_env_injection.sh" "$@"
