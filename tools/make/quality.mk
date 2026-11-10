# Quality Gate Targets
## —— ✅ Quality Gates ——

.PHONY: quality
quality:: markdownlint shellcheck eslint prettier stylelint knip ## Run all quality checks
	@echo "✅ All quality checks passed"

.PHONY: quality-fix
quality-fix:: eslint-fix prettier-fix stylelint-fix markdownlint-fix ## Auto-fix all fixable issues
	@echo "✅ All auto-fixes applied"

.PHONY: quality-fast
quality-fast:: ## Run fast quality checks only (ESLint + Prettier + Markdownlint)
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/ci-quality.sh

.PHONY: ci
ci:: quality typecheck test bats ## Full CI validation (quality + typecheck + tests + BATS)
	@echo ""
	@echo "✅ CI validation passed"
