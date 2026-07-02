#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.sh"

log_header "ESLint Check"

ensure_bin "$ESLINT_BIN" "eslint" || exit 1

if [[ -n "$ESLINT_CONFIG" ]]; then
    log_step "Using configuration: ${ESLINT_CONFIG#"$PROJECT_ROOT"/}"
else
    log_warning "No ESLint configuration found — using ESLint defaults"
fi

# Lint target depends on project type (overridable via env)
if [[ "$PROJECT_TYPE" == "laravel-app" ]]; then
    LINT_TARGET="${LINT_TARGET:-resources/js/}"
else
    # Default to src/, but fallback to . if src/ doesn't exist
    if [[ -z "${LINT_TARGET:-}" ]]; then
        if [[ -d "${PROJECT_ROOT}/src" ]]; then
            LINT_TARGET="src/"
        else
            LINT_TARGET="."
        fi
    fi
fi

log_step "Checking: $LINT_TARGET"

# Normalize away any trailing slash before appending our own — LINT_TARGET can be
# "resources/js/", "src/" or "." depending on project type, and concatenating "."
# directly with "**/*.ext" produces the invalid glob ".**/*.ext" (no match ever).
LINT_TARGET_GLOB_BASE="${LINT_TARGET%/}/"

# Skip gracefully if no matching files exist.
# The brace portion is intentionally left unquoted so bash's brace expansion
# splits it into separate arguments before has_files() sees it (see has_files
# doc comment in config.sh — brace expansion never applies to quoted text or
# to the contents of a variable).
if ! has_files "${PROJECT_ROOT}/${LINT_TARGET_GLOB_BASE}"**/*.{js,ts,vue,jsx,tsx}; then
    log_info "No JS/TS files found in ${LINT_TARGET} — skipping"
    exit 0
fi

ESLINT_ARGS=()

# Only pass --config when the config is not at project root (ESLint 9 auto-discovers root)
if [[ -n "$ESLINT_CONFIG" ]] && [[ "$ESLINT_CONFIG" != "${PROJECT_ROOT}/eslint.config.js" ]]; then
    ESLINT_ARGS+=(--config "$ESLINT_CONFIG")
fi

"$ESLINT_BIN" "${ESLINT_ARGS[@]}" "$LINT_TARGET"

log_success "ESLint check passed"
