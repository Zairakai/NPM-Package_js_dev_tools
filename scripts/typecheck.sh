#!/usr/bin/env bash
#
# TypeScript Type Checking (tsc --noEmit)
# Validates types without emitting output files.
# Equivalent to PHPStan for TypeScript.
#
# Usage:
#   bash scripts/typecheck.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.sh"

TSC_BIN="${BIN_DIR}/tsc"

log_header "TypeScript Type Checking"

ensure_bin "$TSC_BIN" "tsc (typescript)"

if [[ ! -f "${PROJECT_ROOT}/tsconfig.json" ]]; then
    log_error "No tsconfig.json found at project root"
    log_info "Publish one with:"
    log_info "  bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --publish=tsconfig"
    exit 1
fi

log_info "Config: tsconfig.json"
log_info "Mode: --noEmit (type validation only)"

# Skip gracefully if no .ts files are found
if ! has_files "${PROJECT_ROOT}/**/*.ts" && ! has_files "${PROJECT_ROOT}/**/*.tsx"; then
    log_info "No TypeScript files found — skipping"
    exit 0
fi

"$TSC_BIN" --noEmit

log_success "TypeScript type checking passed"
