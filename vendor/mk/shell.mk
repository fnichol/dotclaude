SH_SOURCES ?=

CHECK_TOOLS += shellcheck shfmt

.PHONY: check-shell
check-shell: shellcheck shfmt ## Checks shell files

.PHONY: clean-shell
clean-shell: ## Cleans shell artifacts
	rm -rf tmp/

.PHONY: shellcheck
shellcheck: checktools ## Lints shell files with shellcheck
	@printf -- "---\n%s\n" "$@"
	shellcheck $(SH_SOURCES)

.PHONY: shfmt
shfmt: checktools ## Checks shell files are formatted with shfmt
	@printf -- "---\n%s\n" "$@"
	shfmt -i 2 -ci -bn -d $(SH_SOURCES)

.PHONY: shfmt-write
shfmt-write: ## Formats shell files with shfmt
	@printf -- "---\n%s\n" "$@"
	shfmt -i 2 -ci -bn -w $(SH_SOURCES)
