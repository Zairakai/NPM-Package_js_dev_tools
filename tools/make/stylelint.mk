# Stylelint Targets
# Delegates to scripts/stylelint.sh

## —— 🎨 Stylelint ——
.PHONY: stylelint
stylelint: ## Check CSS/SCSS style (Stylelint)
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/stylelint.sh

.PHONY: stylelint-fix
stylelint-fix: ## Fix CSS/SCSS style automatically
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/stylelint-fix.sh
