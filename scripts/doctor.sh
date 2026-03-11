#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.sh"

log_header "Environment Diagnostics"

echo -e "${CYAN}Node.js Version:${NC}"
node --version

echo ""
echo -e "${CYAN}Package Manager:${NC}"
echo "  → ${PM} $(${PM} --version)"

echo ""
echo -e "${CYAN}Project Type:${NC}"
echo "  → ${PROJECT_TYPE}"

echo ""
echo -e "${CYAN}Available Tools:${NC}"
[[ -f "$ESLINT_BIN" ]]      && echo "  ✅ ESLint:       $("$ESLINT_BIN" --version 2>/dev/null)" || echo "  ❌ ESLint not found"
[[ -f "$PRETTIER_BIN" ]]    && echo "  ✅ Prettier:     $("$PRETTIER_BIN" --version 2>/dev/null)" || echo "  ❌ Prettier not found"
[[ -f "$STYLELINT_BIN" ]]   && echo "  ✅ Stylelint:    $("$STYLELINT_BIN" --version 2>/dev/null)" || echo "  ℹ️  Stylelint not installed (optional)"
[[ -f "$VITEST_BIN" ]]      && echo "  ✅ Vitest:       $("$VITEST_BIN" --version 2>/dev/null)" || echo "  ℹ️  Vitest not installed"
[[ -f "$MARKDOWNLINT_BIN" ]] && echo "  ✅ Markdownlint: installed" || echo "  ❌ Markdownlint not found"
[[ -f "${BIN_DIR}/knip" ]]  && echo "  ✅ Knip:         installed" || echo "  ℹ️  Knip not installed (optional)"
[[ -f "${BIN_DIR}/tsc" ]]   && echo "  ✅ TypeScript:   $("${BIN_DIR}/tsc" --version 2>/dev/null)" || echo "  ℹ️  TypeScript not installed (optional)"
[[ -f "${BIN_DIR}/tsup" ]]  && echo "  ✅ tsup:         installed" || echo "  ℹ️  tsup not installed (optional)"

echo ""
echo -e "${CYAN}CI/CD Detection:${NC}"
if [[ "$IS_CI" == "true" ]]; then
    echo "  ✅ Running in CI environment"
    [[ "$IS_GITLAB_CI" == "true" ]]      && echo "  → Platform: GitLab CI"
    [[ "$IS_GITHUB_ACTIONS" == "true" ]] && echo "  → Platform: GitHub Actions"
else
    echo "  ℹ️  Local development environment"
fi

echo ""
echo -e "${CYAN}Configuration Files (resolved):${NC}"

show_config() {
    local label="$1"
    local value="$2"
    if [[ -n "$value" ]] && [[ -f "$value" ]]; then
        echo "  ✅ ${label}: ${value#"$PROJECT_ROOT"/}"
    else
        echo "  ℹ️  ${label}: Using defaults (no config file)"
    fi
}

show_config "ESLint"       "$ESLINT_CONFIG"
show_config "Prettier"     "$PRETTIER_CONFIG"
show_config ".prettierignore" "$PRETTIER_IGNORE"
show_config "Stylelint"    "$STYLELINT_CONFIG"
show_config ".stylelintignore" "$STYLELINT_IGNORE"
show_config "Markdownlint" "$MARKDOWNLINT_CONFIG"
show_config ".markdownlintignore" "$MARKDOWNLINT_IGNORE"
show_config "Vitest"       "$VITEST_CONFIG"
show_config "Knip"         "$KNIP_CONFIG"
show_config "tsup"         "$TSUP_CONFIG"

echo ""
echo -e "${CYAN}Configuration Fallback Order (all tools):${NC}"
echo "    1. {file}                  (project root override)"
echo "    2. config/dev-tools/{file} (published — can extend bundled default)"
echo "    3. config/{file}           (legacy or intermediate)"
echo "    4. node_modules/@zairakai/js-dev-tools/config/{file} (bundled default)"

echo ""
log_success "Diagnostics complete"
