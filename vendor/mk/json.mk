JSON_SOURCES ?=

CHECK_TOOLS += jq

.PHONY: check-json
check-json: checktools ## Checks JSON files are well formed
	@printf -- "---\n%s\n" "$@"
	@for f in $(JSON_SOURCES); do \
		printf -- "checking %s\n" "$$f"; \
		jq empty "$$f" || exit 1; \
	done
