#!/usr/bin/env bash
#
# CI Quality Aggregator
# Runs all quality checks (ESLint, Prettier, Stylelint, TypeScript)
# and reports all failures at once rather than stopping on the first error.
#
# Usage:
#   bash scripts/ci-quality.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.sh"

log_header "Quality Checks"

init_error_counter

# 1. Documentation & Shell (Foundational)
run_check "Documentation (Markdownlint)" "bash '${SCRIPT_DIR}/markdownlint.sh'" || true
echo ""

run_check "Shell Scripts (ShellCheck)" "bash '${SCRIPT_DIR}/validate-shellcheck.sh'" || true
echo ""

# 2. Code Quality & Style (Language Specific)
run_check "Code Style (ESLint)" "bash '${SCRIPT_DIR}/eslint.sh'" || true
echo ""

run_check "Formatting (Prettier)" "bash '${SCRIPT_DIR}/prettier.sh'" || true
echo ""

run_check "CSS/SCSS (Stylelint)" "bash '${SCRIPT_DIR}/stylelint.sh'" || true
echo ""

# 3. Static Analysis (Optional, Project aware)
if [[ -f "${PROJECT_ROOT}/tsconfig.json" ]] && [[ -f "${BIN_DIR}/tsc" ]]; then
    run_check "TypeScript (tsc --noEmit)" "bash '${SCRIPT_DIR}/typecheck.sh'" || true
    echo ""
else
    log_info "TypeScript: no tsconfig.json or tsc — skipping"
    echo ""
fi

if exit_with_error_count "Quality Checks"; then
    exit 0
else
    exit 1
fi
