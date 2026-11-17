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
.PHONY: outdated
outdated: ## Check for outdated npm dependencies
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/outdated.sh

# Double colon: in a full-stack project, the targets of laravel-dev-tools and the ones of this package both run
.PHONY: setup-check
setup-check:: ## Tell which files of the setup are missing or differ from the package (writes nothing)
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/setup-check.sh

.PHONY: setup-update
setup-update:: ## Replace the files that setup-check reports
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/setup-update.sh

.PHONY: uninstall
uninstall:: ## Remove the setup files (copy kept in .dev-tools-backup/)
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/uninstall-package.sh
