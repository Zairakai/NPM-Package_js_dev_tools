# Shared Utility Targets
# Targets duplicated across PHP and JS toolchains

## —— 🧰 Utils ——
.PHONY: doctor
doctor: ## Run environment diagnostics
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/doctor.sh

## —— 🌿 Git ——
.PHONY: install-hooks
install-hooks: ## Install git hooks into .git/hooks
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/install-hooks.sh

.PHONY: git-update
git-update: ## Fast-forward all local branches that track a remote
	@bash $(NPM_DIRECTORY_TOOLS_PACKAGE_ROOT)/tools/scripts/git-update.sh

.PHONY: git-cleanup
git-cleanup: ## Remove local branches whose remote tracking branch no longer exists
	@bash $(NPM_DIRECTORY_TOOLS_PACKAGE_ROOT)/tools/scripts/git-cleanup.sh

.PHONY: git-rebase
git-rebase: ## Rebase the current branch to the selected one
	@bash $(NPM_DIRECTORY_TOOLS_TOOLS_SCRIPTS_DIR)/git-rebase.sh
