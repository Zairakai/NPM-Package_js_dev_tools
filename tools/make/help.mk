# Help target

## —— 📚 Help ——

.PHONY: help
help:: ## Show available commands
	@echo ""
	@printf "$(NPM_DIRECTORY_TOOLS_COLOR_HEADER_FG)$(NPM_DIRECTORY_TOOLS_COLOR_HEADER_BG)%*s$(NPM_DIRECTORY_TOOLS_COLOR_RESET)\n" $(NPM_DIRECTORY_TOOLS_HELP_WIDTH) ""
	@printf "$(NPM_DIRECTORY_TOOLS_COLOR_HEADER_FG)$(NPM_DIRECTORY_TOOLS_COLOR_HEADER_BG)   %-*s$(NPM_DIRECTORY_TOOLS_COLOR_RESET)\n" $$(($(NPM_DIRECTORY_TOOLS_HELP_WIDTH)-3)) "$(NPM_DIRECTORY_TOOLS_PROJECT_NAME) - Available Commands"
	@printf "$(NPM_DIRECTORY_TOOLS_COLOR_HEADER_FG)$(NPM_DIRECTORY_TOOLS_COLOR_HEADER_BG)%*s$(NPM_DIRECTORY_TOOLS_COLOR_RESET)\n" $(NPM_DIRECTORY_TOOLS_HELP_WIDTH) ""
	@echo ""
	@grep -hE '(^[[:alnum:]_.-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS=":.*?## "; color_section="$(NPM_DIRECTORY_TOOLS_COLOR_SECTION)"; color_target="$(NPM_DIRECTORY_TOOLS_COLOR_TARGET)"; color_reset="$(NPM_DIRECTORY_TOOLS_COLOR_RESET)"} \
			/^##/ { \
				gsub(/^##[[:space:]]*/, "", $$0); \
				if ($$0 != "") { \
					if (!seen_sections[$$0]++) { \
						if (NR > 1) { printf "\n" } \
						printf "%s%s%s\n", color_section, $$0, color_reset \
					} \
				} else { \
					printf "\n" \
				} \
				next \
			} \
			!seen_targets[$$1]++ { printf "  %s%-28s%s %s\n", color_target, $$1, color_reset, $$2 }'
	@echo ""
	@printf "$(NPM_DIRECTORY_TOOLS_COLOR_FOOTER_FG)$(NPM_DIRECTORY_TOOLS_COLOR_FOOTER_BG)%*s$(NPM_DIRECTORY_TOOLS_COLOR_RESET)\n" $(NPM_DIRECTORY_TOOLS_HELP_WIDTH) ""
	@printf "$(NPM_DIRECTORY_TOOLS_COLOR_FOOTER_FG)$(NPM_DIRECTORY_TOOLS_COLOR_FOOTER_BG)   Twitch: %-*s$(NPM_DIRECTORY_TOOLS_COLOR_RESET)\n" $$(($(NPM_DIRECTORY_TOOLS_HELP_WIDTH)-11)) "$(NPM_DIRECTORY_TOOLS_TWITCH_URL)"
	@printf "$(NPM_DIRECTORY_TOOLS_COLOR_FOOTER_FG)$(NPM_DIRECTORY_TOOLS_COLOR_FOOTER_BG)   GitLab: %-*s$(NPM_DIRECTORY_TOOLS_COLOR_RESET)\n" $$(($(NPM_DIRECTORY_TOOLS_HELP_WIDTH)-11)) "$(NPM_DIRECTORY_TOOLS_GITLAB_URL)"
	@printf "$(NPM_DIRECTORY_TOOLS_COLOR_FOOTER_FG)$(NPM_DIRECTORY_TOOLS_COLOR_FOOTER_BG)%*s$(NPM_DIRECTORY_TOOLS_COLOR_RESET)\n" $(NPM_DIRECTORY_TOOLS_HELP_WIDTH) ""
	@echo ""
