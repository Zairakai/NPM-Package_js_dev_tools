#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.sh"

log_header "ESLint Fix"

ensure_bin "$ESLINT_BIN" "eslint" || exit 1

if [[ -n "$ESLINT_CONFIG" ]]; then
    log_step "Using configuration: ${ESLINT_CONFIG#"$PROJECT_ROOT"/}"
fi

if [[ "$PROJECT_TYPE" == "laravel-app" ]]; then
    LINT_TARGET="${LINT_TARGET:-resources/js/}"
else
    LINT_TARGET="${LINT_TARGET:-src/}"
fi

log_step "Fixing: $LINT_TARGET"

# Skip gracefully if no matching files exist
if ! has_files "${PROJECT_ROOT}/${LINT_TARGET}**/*.{js,ts,vue,jsx,tsx}"; then
    log_info "No JS/TS files found in ${LINT_TARGET} — skipping"
    exit 0
fi

ESLINT_ARGS=(--fix)

if [[ -n "$ESLINT_CONFIG" ]] && [[ "$ESLINT_CONFIG" != "${PROJECT_ROOT}/eslint.config.js" ]]; then
    ESLINT_ARGS+=(--config "$ESLINT_CONFIG")
fi

"$ESLINT_BIN" "${ESLINT_ARGS[@]}" "$LINT_TARGET"

log_success "ESLint fix applied"
