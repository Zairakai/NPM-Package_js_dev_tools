#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.sh"

log_header "NPM Outdated Check"

ensure_dir "build/reports"

# ─── IGNORE LIST ──────────────────────────────────────────────────────────────
# Packages to exclude from the outdated check.
# Populated from two sources (merged):
#   1. OUTDATED_IGNORE env var — comma-separated list
#      e.g. OUTDATED_IGNORE=prettier-plugin-blade,some-other-pkg
#   2. package.json "outdatedIgnore" array field (optional, project-level)
#      e.g. "outdatedIgnore": ["prettier-plugin-blade"]
# ──────────────────────────────────────────────────────────────────────────────
build_jq_filter() {
    local ignore_csv="${OUTDATED_IGNORE:-}"
    local pkg_json="${PROJECT_ROOT}/package.json"
    local from_pkg_json=""

    if command_exists jq && [[ -f "$pkg_json" ]]; then
        from_pkg_json="$(jq -r '(.outdatedIgnore // []) | join(",")' "$pkg_json" 2>/dev/null || true)"
    fi

    # Merge both sources
    local combined="${ignore_csv}${ignore_csv:+,}${from_pkg_json}"

    if [[ -z "$combined" ]]; then
        echo "."
        return
    fi

    # Build: del(.pkg1) | del(.pkg2) | ...
    local filter="."
    IFS=',' read -ra packages <<< "$combined"
    for pkg in "${packages[@]}"; do
        pkg="${pkg// /}"  # trim spaces
        [[ -z "$pkg" ]] && continue
        filter+=" | del(.\"${pkg}\")"
    done

    echo "$filter"
}

log_step "Checking direct dependencies for outdated packages..."

npm outdated --omit=peer --json > build/reports/npm-outdated.json 2>/dev/null || true

JQ_FILTER="$(build_jq_filter)"

if command_exists jq && [[ "$JQ_FILTER" != "." ]]; then
    log_step "Ignoring: ${OUTDATED_IGNORE:-}$(jq -r '(.outdatedIgnore // []) | join(", ")' "${PROJECT_ROOT}/package.json" 2>/dev/null || true)"
    filtered="$(jq "${JQ_FILTER}" build/reports/npm-outdated.json 2>/dev/null || cat build/reports/npm-outdated.json)"
    echo "$filtered" > build/reports/npm-outdated.json
fi

if [[ ! -s build/reports/npm-outdated.json ]] || [[ "$(cat build/reports/npm-outdated.json)" == "{}" ]]; then
    log_success "All dependencies are up to date"
    exit 0
fi

log_error "Outdated packages found:"
cat build/reports/npm-outdated.json
echo ""
echo "Run: npm update (or update package.json manually)"
exit 1
