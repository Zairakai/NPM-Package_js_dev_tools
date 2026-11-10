# Markdownlint Targets
# Delegates to scripts/markdownlint.sh

## —— 📝 Markdownlint (Documentation Linting) ——

.PHONY: markdownlint
markdownlint: ## Validate Markdown documentation style and formatting
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/markdownlint.sh

.PHONY: markdownlint-fix
markdownlint-fix: ## Fix Markdown documentation issues automatically
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/markdownlint-fix.sh

##
.PHONY: install-markdownlint
install-markdownlint: ## Install Markdownlint
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/install-markdownlint.sh
