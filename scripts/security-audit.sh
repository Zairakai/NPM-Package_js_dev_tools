#!/usr/bin/env bash
set -euo pipefail

# Load central configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.sh"
maybe_dockerize "$0" "$@"

log_header "Security Audit"

# Run npm audit and output a JSON report
AUDIT_REPORT="${PROJECT_ROOT}/build/reports/npm-audit.json"
ensure_dir "$(dirname "$AUDIT_REPORT")"

log_step "Running npm audit..."

# The exit code is not enough alone: npm audit ends with 1 for advisories, and also when it could not run (no network, no
# lock file). The report decides, and the level is the one of the daily audit (deps:audit): an advisory that is high,
# or critical blocks, the others (an unknown severity counts as a medium one) are listed. The rule is in
# update-dependencies.mjs, in one place.
audit_status=0
npm audit --json > "$AUDIT_REPORT" || audit_status=$?

if ! node "${SCRIPT_DIR}/update-dependencies.mjs" audit-check "$AUDIT_REPORT"; then
  log_error "Security audit failed (npm audit exit ${audit_status}): see the advisories above"
  exit 1
fi

log_success "No security vulnerabilities found at the high level or above"
