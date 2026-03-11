#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.sh"

log_header "Vitest Tests"

if ! ensure_bin_optional "$VITEST_BIN" "vitest"; then
    log_warning "vitest not installed — add it to devDependencies to run tests"
    exit 0
fi

COVERAGE="${COVERAGE:-false}"
CI="${CI:-false}"

# CI mode: always run with coverage
if [[ "$CI" == "true" ]]; then
    log_info "Running in CI mode (strict + coverage)"
    COVERAGE="true"
fi

VITEST_ARGS=()

if [[ -n "$VITEST_CONFIG" ]]; then
    log_step "Using configuration: ${VITEST_CONFIG#"$PROJECT_ROOT"/}"
    VITEST_ARGS+=(--config "$VITEST_CONFIG")
fi

if [[ "$COVERAGE" == "true" ]]; then
    log_info "Running with coverage report"
    ensure_dir "build/coverage"
    ensure_dir "build/logs"
    "$VITEST_BIN" run --coverage --passWithNoTests "${VITEST_ARGS[@]}"
else
    "$VITEST_BIN" run --passWithNoTests "${VITEST_ARGS[@]}"
fi

log_success "Tests passed"
