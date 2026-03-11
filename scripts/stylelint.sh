#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.sh"

EXTRA_IGNORES=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ignore)     EXTRA_IGNORES+=("$2"); shift 2 ;;
        --ignore=*)   EXTRA_IGNORES+=("${1#--ignore=}"); shift ;;
        *)            shift ;;
    esac
done

log_header "Stylelint Check"

# Stylelint is optional — skip gracefully if not installed
ensure_bin_optional "$STYLELINT_BIN" "stylelint" || exit 0

if [[ -n "$STYLELINT_CONFIG" ]]; then
    log_step "Using configuration: ${STYLELINT_CONFIG#"$PROJECT_ROOT"/}"
fi

# Lint target depends on project type (overridable via env)
if [[ "$PROJECT_TYPE" == "laravel-app" ]]; then
    STYLELINT_TARGET="${STYLELINT_TARGET:-resources/**/*.scss}"
else
    STYLELINT_TARGET="${STYLELINT_TARGET:-src/**/*.scss}"
fi

log_step "Checking: $STYLELINT_TARGET"

# Skip gracefully if no matching files exist (stylelint v16 errors on empty glob)
if ! has_files "${PROJECT_ROOT}/${STYLELINT_TARGET}"; then
    log_info "No SCSS/CSS files found matching ${STYLELINT_TARGET} — skipping"
    exit 0
fi

STYLELINT_ARGS=()

if [[ -n "$STYLELINT_CONFIG" ]] && [[ "$STYLELINT_CONFIG" != "${PROJECT_ROOT}/stylelint.config.js" ]]; then
    STYLELINT_ARGS+=(--config "$STYLELINT_CONFIG")
fi

if [[ -n "$STYLELINT_IGNORE" ]]; then
    STYLELINT_ARGS+=(--ignore-path "$STYLELINT_IGNORE")
fi

# Also respect .gitignore if present
if [[ -f "${PROJECT_ROOT}/.gitignore" ]]; then
    STYLELINT_ARGS+=(--ignore-path "${PROJECT_ROOT}/.gitignore")
fi

# Extra ignores passed via --ignore → temp file (gitignore format)
if [[ ${#EXTRA_IGNORES[@]} -gt 0 ]]; then
    _TMP_IGNORE=$(mktemp)
    trap 'rm -f "$_TMP_IGNORE"' EXIT
    printf '%s\n' "${EXTRA_IGNORES[@]}" > "$_TMP_IGNORE"
    STYLELINT_ARGS+=(--ignore-path "$_TMP_IGNORE")
fi

"$STYLELINT_BIN" "${STYLELINT_ARGS[@]}" "$STYLELINT_TARGET"

log_success "Stylelint check passed"
