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

log_header "Prettier Check"

ensure_bin "$PRETTIER_BIN" "prettier" || exit 1

if [[ -n "$PRETTIER_CONFIG" ]]; then
    log_step "Using configuration: ${PRETTIER_CONFIG#"$PROJECT_ROOT"/}"
fi

PRETTIER_ARGS=(--check)

if [[ -n "$PRETTIER_CONFIG" ]] && [[ "$PRETTIER_CONFIG" != "${PROJECT_ROOT}/prettier.config.js" ]]; then
    PRETTIER_ARGS+=(--config "$PRETTIER_CONFIG")
fi

if [[ -n "$PRETTIER_IGNORE" ]]; then
    PRETTIER_ARGS+=(--ignore-path "$PRETTIER_IGNORE")
fi

# Also respect .gitignore if present
if [[ -f "${PROJECT_ROOT}/.gitignore" ]]; then
    PRETTIER_ARGS+=(--ignore-path "${PROJECT_ROOT}/.gitignore")
fi

# Extra ignores passed via --ignore
if [[ ${#EXTRA_IGNORES[@]} -gt 0 ]]; then
    _TMP_IGNORE=$(mktemp)
    trap 'rm -f "$_TMP_IGNORE"' EXIT
    printf '%s\n' "${EXTRA_IGNORES[@]}" > "$_TMP_IGNORE"
    PRETTIER_ARGS+=(--ignore-path "$_TMP_IGNORE")
fi

# Prettier checks all supported files from project root
PRETTIER_ARGS+=(".")

"$PRETTIER_BIN" "${PRETTIER_ARGS[@]}"

log_success "Prettier check passed"
