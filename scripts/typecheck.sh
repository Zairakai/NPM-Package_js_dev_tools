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
VUE_TSC_BIN="${BIN_DIR}/vue-tsc"

log_header "TypeScript Type Checking"

if [[ ! -f "${PROJECT_ROOT}/tsconfig.json" ]]; then
    log_error "No tsconfig.json found at project root"
    log_info "Publish one with:"
    log_info "  bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --publish=tsconfig"
    exit 1
fi

log_info "Config: tsconfig.json"
log_info "Mode: --noEmit (type validation only)"

# Skip gracefully if no .ts/.vue files are found
if ! has_files "${PROJECT_ROOT}/**/*.ts" && ! has_files "${PROJECT_ROOT}/**/*.tsx" && ! has_files "${PROJECT_ROOT}/**/*.vue"; then
    log_info "No TypeScript or Vue files found — skipping"
    exit 0
fi

# Prefer vue-tsc when available (handles .vue SFC imports correctly)
if [[ -x "$VUE_TSC_BIN" ]]; then
    log_info "Checker: vue-tsc (Vue SFC support)"
    "$VUE_TSC_BIN" --noEmit
else
    ensure_bin "$TSC_BIN" "tsc (typescript)"
    log_info "Checker: tsc"
    "$TSC_BIN" --noEmit
fi

log_success "TypeScript type checking passed"
