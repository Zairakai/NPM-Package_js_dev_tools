#!/usr/bin/env bash
#
# Knip — Dead Code & Unused Dependency Detection
# Finds unused exports, files, and dependencies in TypeScript/JavaScript projects.
# https://knip.dev
#
# Optional: skips gracefully if knip is not installed.
#
# Usage:
#   bash scripts/knip.sh
#
# Installation:
#   npm install --save-dev knip
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.sh"

KNIP_BIN="${BIN_DIR}/knip"

log_header "Knip — Dead Code Detection"

if ! ensure_bin_optional "$KNIP_BIN" "knip"; then
    log_info "Install: npm install --save-dev knip"
    exit 0
fi

KNIP_ARGS=()

if [[ -n "$KNIP_CONFIG" ]]; then
    log_step "Using configuration: ${KNIP_CONFIG#"$PROJECT_ROOT"/}"
    KNIP_ARGS+=(--config "$KNIP_CONFIG")
fi

"$KNIP_BIN" "${KNIP_ARGS[@]}"

log_success "Knip check passed — no dead code found"
