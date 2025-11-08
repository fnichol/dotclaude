YAML_SOURCES ?= $(shell find . \( -path './tmp' -o -path './vendor' \) -prune \
	-o -type f \( -name '*.yaml' -o -name '*.yml' \) -print)

CHECK_TOOLS += yamllint

.PHONY: check-yaml
check-yaml: checktools ## Checks YAML files are well formed
	@printf -- "---\n%s\n" "$@"
	yamllint $(YAML_SOURCES)
