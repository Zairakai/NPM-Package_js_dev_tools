#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.sh"
maybe_dockerize "$0" "$@"

EXTRA_IGNORES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ignore)     EXTRA_IGNORES+=("$2"); shift 2 ;;
    --ignore=*)   EXTRA_IGNORES+=("${1#--ignore=}"); shift ;;
    *)            shift ;;
  esac
done

log_header "Stylelint Fix"

ensure_bin_optional "$STYLELINT_BIN" "stylelint" || exit 0

if [[ -n "$STYLELINT_CONFIG" ]]; then
  log_step "Using configuration: ${STYLELINT_CONFIG#"$PROJECT_ROOT"/}"
fi

if [[ "$PROJECT_TYPE" == "laravel-app" ]]; then
  STYLELINT_TARGET="${STYLELINT_TARGET:-resources/**/*.scss resources/**/*.css resources/**/*.vue}"
else
  STYLELINT_TARGET="${STYLELINT_TARGET:-src/**/*.scss src/**/*.css src/**/*.vue}"
fi

# STYLELINT_TARGET is a list of globs separated by spaces (one per file type: stylelint lints the style blocks of .vue)
read -r -a STYLELINT_PATTERNS <<< "$STYLELINT_TARGET"
STYLELINT_ABSOLUTE=()
for _pattern in "${STYLELINT_PATTERNS[@]}"; do
  STYLELINT_ABSOLUTE+=("${PROJECT_ROOT}/${_pattern}")
done

log_step "Fixing: $STYLELINT_TARGET"

# Skip gracefully if no matching files exist
if ! has_files "${STYLELINT_ABSOLUTE[@]}"; then
  log_info "No SCSS, CSS or Vue files found matching ${STYLELINT_TARGET} - skipping"
  exit 0
fi

STYLELINT_ARGS=(--fix)

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

"$STYLELINT_BIN" "${STYLELINT_ARGS[@]}" "${STYLELINT_PATTERNS[@]}"

log_success "Stylelint fix applied"
