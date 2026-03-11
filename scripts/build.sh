#!/usr/bin/env bash
#
# TypeScript Build / Transpilation
# Compiles TypeScript to JavaScript for distribution.
#
# Supports (in order of preference):
#   1. tsup  — fast, esbuild-based bundler (recommended for npm packages)
#   2. tsc   — official TypeScript compiler
#
# Usage:
#   bash scripts/build.sh
#
# Recommendation:
#   Use tsup for npm packages:  npm install --save-dev tsup
#   Use tsc for apps:           npm install --save-dev typescript
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.sh"

TSUP_BIN="${BIN_DIR}/tsup"
TSC_BIN="${BIN_DIR}/tsc"

log_header "TypeScript Build"

if [[ -f "$TSUP_BIN" ]]; then
    log_info "Builder: tsup (fast, esbuild-based)"
    if [[ -n "$TSUP_CONFIG" ]]; then
        "$TSUP_BIN" --config "$TSUP_CONFIG"
    else
        "$TSUP_BIN"
    fi
    log_success "Build complete — output in dist/"

elif [[ -f "$TSC_BIN" ]]; then
    log_info "Builder: tsc (official TypeScript compiler)"

    if [[ ! -f "${PROJECT_ROOT}/tsconfig.json" ]]; then
        log_error "No tsconfig.json found at project root"
        log_info "Publish one with:"
        log_info "  bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --publish=tsconfig"
        exit 1
    fi

    log_info "Config: tsconfig.json"
    "$TSC_BIN"
    log_success "Build complete"

else
    log_error "No TypeScript builder found in node_modules/.bin/"
    log_info "Install one of:"
    log_info "  npm install --save-dev tsup       (recommended for npm packages)"
    log_info "  npm install --save-dev typescript (for apps or when you need full tsc control)"
    exit 1
fi
