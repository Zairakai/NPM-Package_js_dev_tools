#!/usr/bin/env bash
# Zairakai NPM Dev Tools - Central Configuration

set -euo pipefail

# ─── PATH DETECTION ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Vendor context: node_modules/@zairakai/js-dev-tools/scripts/
# Dev context:    npm/dev-tools/scripts/
if [[ "$SCRIPT_DIR" =~ /node_modules/@zairakai/js-dev-tools/scripts ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
    DEV_TOOLS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    DEV_TOOLS_ROOT="$PROJECT_ROOT"
fi

export PROJECT_ROOT
export DEV_TOOLS_ROOT

# ─── PACKAGE MANAGER DETECTION ────────────────────────────────────────────────
detect_package_manager() {
    if [[ -f "$PROJECT_ROOT/yarn.lock" ]] || [[ -f "$PROJECT_ROOT/.yarnrc.yml" ]]; then
        echo "yarn"
    else
        echo "npm"
    fi
}

PM="$(detect_package_manager)"
export PM

# ─── PROJECT TYPE DETECTION ───────────────────────────────────────────────────
detect_project_type() {
    if [[ -f "${PROJECT_ROOT}/artisan" ]] && [[ -d "${PROJECT_ROOT}/resources/js" ]]; then
        echo "laravel-app"
        return 0
    fi
    echo "npm-package"
}

PROJECT_TYPE="$(detect_project_type)"
export PROJECT_TYPE

# ─── BINARY PATHS ─────────────────────────────────────────────────────────────
BIN_DIR="${PROJECT_ROOT}/node_modules/.bin"
export ESLINT_BIN="${BIN_DIR}/eslint"
export PRETTIER_BIN="${BIN_DIR}/prettier"
export STYLELINT_BIN="${BIN_DIR}/stylelint"
export VITEST_BIN="${BIN_DIR}/vitest"
export MARKDOWNLINT_BIN="${BIN_DIR}/markdownlint-cli2"

# ─── CONFIG RESOLUTION ────────────────────────────────────────────────────────
# Cascade: project root → config/dev-tools/ → config/ → bundled default
resolve_config() {
    local filename="$1"

    # 1. Project root (full override)
    if [[ -f "${PROJECT_ROOT}/${filename}" ]]; then
        echo "${PROJECT_ROOT}/${filename}"
        return 0
    fi

    # 2. config/dev-tools/ (published — can extend bundled default)
    if [[ -f "${PROJECT_ROOT}/config/dev-tools/${filename}" ]]; then
        echo "${PROJECT_ROOT}/config/dev-tools/${filename}"
        return 0
    fi

    # 3. config/ (local usage or internal package structure)
    if [[ -f "${PROJECT_ROOT}/config/${filename}" ]]; then
        echo "${PROJECT_ROOT}/config/${filename}"
        return 0
    fi

    # 4. Bundled default in dev-tools package (fallback when in node_modules)
    if [[ -f "${DEV_TOOLS_ROOT}/config/${filename}" ]]; then
        echo "${DEV_TOOLS_ROOT}/config/${filename}"
        return 0
    fi

    echo ""
}

export -f resolve_config

# ─── COLORS ───────────────────────────────────────────────────────────────────
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;35m'
export NC='\033[0m'

# ─── LOGGING ──────────────────────────────────────────────────────────────────
log_info()    { echo -e "${CYAN}ℹ ${NC}$*"; }
log_success() { echo -e "${GREEN}✅ ${NC}$*"; }
log_warning() { echo -e "${YELLOW}⚠️  ${NC}$*"; }
log_error()   { echo -e "${RED}❌ ${NC}$*" >&2; }
log_step()    { echo -e "${BLUE}→${NC} $*"; }
log_header()  { echo -e "\n${MAGENTA}  $*${NC}\n${MAGENTA}════════════════${NC}\n"; }

export -f log_info
export -f log_success
export -f log_warning
export -f log_error
export -f log_step
export -f log_header

# ─── BINARY CHECKS ────────────────────────────────────────────────────────────
ensure_bin() {
    local bin="$1"
    local name="${2:-$(basename "$bin")}"
    if [[ ! -f "$bin" ]]; then
        log_error "${name} not found in node_modules/.bin/"
        log_error "Run: ${PM} install"
        return 1
    fi
}
export -f ensure_bin

ensure_bin_optional() {
    local bin="$1"
    local name="${2:-$(basename "$bin")}"
    if [[ ! -f "$bin" ]]; then
        log_warning "${name} not installed — skipping (optional)"
        return 1
    fi
    return 0
}
export -f ensure_bin_optional

# Check if files matching any of the given patterns exist.
#
# Variadic: accepts one or more glob patterns, returns success if ANY matches.
# Callers needing a brace-alternation pattern (e.g. *.{js,ts,vue}) must leave that
# portion unquoted at the call site so bash's brace expansion splits it into
# separate arguments BEFORE this function ever sees it — brace expansion only
# applies to unquoted literal text, never to the contents of a variable, so a
# pattern like "**/*.{js,ts}" passed as a single quoted string is matched
# literally (and never matches a real file) instead of being expanded.
has_files() {
    local pattern
    for pattern in "$@"; do
        # SC2086: unquoted intentionally — we need word splitting + glob expansion via nullglob+globstar
        # shellcheck disable=SC2086
        if ( shopt -s nullglob globstar; set -- $pattern; [ $# -gt 0 ] ); then
            return 0
        fi
    done
    return 1
}
export -f has_files

# ─── ERROR COUNTER ────────────────────────────────────────────────────────────
ERROR_COUNT=0
export ERROR_COUNT
init_error_counter()      { ERROR_COUNT=0; }
increment_error_counter() { ERROR_COUNT=$((ERROR_COUNT + 1)); }
get_error_count()         { echo "$ERROR_COUNT"; }

exit_with_error_count() {
    local name="${1:-Checks}"
    if [[ $ERROR_COUNT -eq 0 ]]; then
        log_header "✅ All ${name} Passed"
        return 0
    else
        log_header "❌ ${ERROR_COUNT} ${name} Failed"
        return 1
    fi
}

export -f init_error_counter
export -f increment_error_counter
export -f get_error_count
export -f exit_with_error_count

run_check() {
    local name="$1"
    local cmd="$2"
    log_info "Running: ${name}"
    if eval "$cmd"; then
        log_success "${name} passed"
    else
        log_error "${name} failed"
        increment_error_counter
        return 1
    fi
}

# ─── BACKUP ──────────────────────────────────────────────────────────────────
BACKUP_DIR=""
backup_file() {
    local file="$1"
    local base="${2:-${PROJECT_ROOT}/.dev-tools-backup}"
    [[ ! -f "$file" || -L "$file" ]] && return 1
    if [[ -z "$BACKUP_DIR" ]]; then
        BACKUP_DIR="${base}/$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
    fi
    local rel="${file#"${PROJECT_ROOT}"/}"
    local dest="${BACKUP_DIR}/${rel}"
    mkdir -p "$(dirname "$dest")"
    cp "$file" "$dest" 2>/dev/null
}

# ─── HELPERS ──────────────────────────────────────────────────────────────────
command_exists() { command -v "$1" >/dev/null 2>&1; }
ensure_dir() {
    if [[ ! -d "$1" ]]; then
        mkdir -p "$1"
        log_step "Created directory: $1"
    fi
}

# ─── FILE PROTECTION (SHA-256) ────────────────────────────────────────────────
file_hash() {
    local file="$1"
    if command_exists sha256sum; then
        sha256sum "$file" | cut -d' ' -f1
    elif command_exists shasum; then
        shasum -a 256 "$file" | cut -d' ' -f1
    else
        echo ""
    fi
}

# ─── ENVIRONMENT DETECTION ────────────────────────────────────────────────────
export IS_CI="${CI:-false}"
export IS_GITLAB_CI="${GITLAB_CI:-false}"
export IS_GITHUB_ACTIONS="${GITHUB_ACTIONS:-false}"

# ─── TOOL CONFIG RESOLUTION ───────────────────────────────────────────────────
# Pre-resolved at startup so individual scripts don't call resolve_config themselves.
ESLINT_CONFIG="$(resolve_config "eslint.config.js")"
export ESLINT_CONFIG

PRETTIER_CONFIG="$(resolve_config "prettier.config.js")"
PRETTIER_IGNORE="$(resolve_config ".prettierignore")"
export PRETTIER_CONFIG PRETTIER_IGNORE

STYLELINT_CONFIG="$(resolve_config "stylelint.config.js")"
STYLELINT_IGNORE="$(resolve_config ".stylelintignore")"
export STYLELINT_CONFIG STYLELINT_IGNORE

MARKDOWNLINT_CONFIG="$(resolve_config ".markdownlint.json")"
MARKDOWNLINT_IGNORE="$(resolve_config ".markdownlintignore")"
export MARKDOWNLINT_CONFIG MARKDOWNLINT_IGNORE

VITEST_CONFIG="$(resolve_config "vitest.config.js")"
export VITEST_CONFIG

KNIP_CONFIG="$(resolve_config "knip.config.js")"
export KNIP_CONFIG

TSUP_CONFIG="$(resolve_config "tsup.config.js")"
export TSUP_CONFIG

# ─── VALIDATION ───────────────────────────────────────────────────────────────
cd "$PROJECT_ROOT"

if [[ ! -d "${PROJECT_ROOT}/node_modules" ]]; then
    log_error "Dependencies not installed. Run: ${PM} install"
    exit 1
fi
