#!/usr/bin/env bash
#
# Build script for npm packages.
# Supports (in order of preference):
#   1. Vite  — detected via vite.config.ts / vite.config.js (runs npm run build)
#   2. tsup  — fast, esbuild-based bundler (recommended for pure TS packages)
#   3. tsc   — official TypeScript compiler
#
# Usage:
#   bash scripts/build.sh
#
# Recommendation:
#   Use Vite for Vue component libraries (vite.config.ts present)
#   Use tsup for pure TypeScript packages: npm install --save-dev tsup
#   Use tsc for simple transpilation:      npm install --save-dev typescript
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.sh"

TSUP_BIN="${BIN_DIR}/tsup"
TSC_BIN="${BIN_DIR}/tsc"

log_header "Build"

if [[ -f "${PROJECT_ROOT}/vite.config.ts" ]] || [[ -f "${PROJECT_ROOT}/vite.config.js" ]]; then
    log_info "Builder: Vite (vite.config detected — running npm run build)"
    npm run build
    log_success "Build complete — output in dist/"

elif [[ -f "$TSUP_BIN" ]]; then
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
    log_error "No builder found. Expected one of: vite.config.ts, tsup, tsc"
    log_info "Install one of:"
    log_info "  npm install --save-dev tsup       (recommended for pure TS packages)"
    log_info "  npm install --save-dev typescript (for simple transpilation)"
    exit 1
fi
