# Utility Targets
# Miscellaneous commands for development

## —— 🎼  Package Manager ——
.PHONY: package-install
package-install: ## Install dependencies
	@echo "📦 Installing dependencies…"
	@npm install

.PHONY: package-update
package-update: ## Update dependencies
	@echo "⬆️  Updating dependencies…"
	@npm update

.PHONY: package-normalize
package-normalize: ## Normalize package.json structure (sort-package-json)
	@$(NPM_DIRECTORY_TOOLS_PROJECT_ROOT)/node_modules/.bin/sort-package-json package.json

.PHONY: package-validate
package-validate: ## Validate package.json and lockfile sync
	@echo "🔍 Validating package.json and lockfile…"
	@npm install --package-lock-only --dry-run
	@$(NPM_DIRECTORY_TOOLS_PROJECT_ROOT)/node_modules/.bin/sort-package-json --check package.json

## —— 🧰 Utils ——
.PHONY: doctor
doctor: ## Run environment diagnostics
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/doctor.sh

.PHONY: outdated
outdated: ## Check for outdated npm dependencies
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/outdated.sh

.PHONY: install-hooks
install-hooks: ## Install git hooks into .git/hooks
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/install-hooks.sh

.PHONY: git-update
git-update: ## Fast-forward all local branches that track a remote
	@bash $(NPM_DIRECTORY_TOOLS_PACKAGE_ROOT)/tools/scripts/git-update.sh

.PHONY: git-cleanup
git-cleanup: ## Remove local branches whose remote tracking branch no longer exists
	@bash $(NPM_DIRECTORY_TOOLS_PACKAGE_ROOT)/tools/scripts/git-cleanup.sh
