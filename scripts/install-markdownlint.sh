#!/usr/bin/env bash
#
# Zairakai NPM Dev Tools - Markdownlint Installer
# Installs markdownlint-cli2 as a local npm dev dependency.
#
# Usage:
#   bash scripts/install-markdownlint.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

log_header "Markdownlint Installer"

if [[ -f "$MARKDOWNLINT_BIN" ]]; then
    version=$("$MARKDOWNLINT_BIN" --version 2>/dev/null || echo "unknown")
    log_success "markdownlint-cli2 already installed: ${version}"
    log_info "Run: make markdownlint"
    exit 0
fi

log_info "markdownlint-cli2 not found in node_modules/.bin/"
log_step "Installing markdownlint-cli2 as a dev dependency…"

"$PM" install --save-dev markdownlint-cli2

log_success "markdownlint-cli2 installed"
log_info "Run: make markdownlint"
