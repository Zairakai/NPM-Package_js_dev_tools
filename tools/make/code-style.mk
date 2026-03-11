# ESLint + Prettier Code Style Targets

## —— 🎨 Code Style ——

.PHONY: eslint
eslint: ## Check code style
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/eslint.sh

.PHONY: eslint-fix
eslint-fix: ## Fix code style automatically
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/eslint-fix.sh

##
.PHONY: prettier
prettier: ## Check formatting
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/prettier.sh

.PHONY: prettier-fix
prettier-fix: ## Fix formatting automatically
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/prettier-fix.sh
