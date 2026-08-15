.PHONY: check lint manifest whitespace act local install

QML_FILES := Panel.qml BarWidget.qml
QMLLINT ?= qmllint
QMLLINT_ARGS ?=
QMLLINT_IMPORT_PATH ?= tests/qml-stubs
ACT ?= act
PLUGIN_ID ?= mokkabonna.plugin-settings
PLUGIN_DIR ?= $(HOME)/.config/omarchy/plugins
PLUGIN_PATH := $(PLUGIN_DIR)/$(PLUGIN_ID)
PLUGIN_REPO ?= https://github.com/mokkabonna/omarchy-plugin-settings.git

# Run every local validation check.
check: lint manifest whitespace

# Run QML lint against the plugin entry points and test stubs.
lint:
	$(QMLLINT) -I $(QMLLINT_IMPORT_PATH) $(QMLLINT_ARGS) $(QML_FILES)

# Validate the required plugin manifest fields.
manifest:
	jq -e '(.schemaVersion == 1) and (.id | type == "string" and length > 0) and (.name | type == "string" and length > 0) and (.version | type == "string" and length > 0) and (.entryPoints.panel == "Panel.qml") and (.entryPoints.barWidget == "BarWidget.qml")' manifest.json >/dev/null

# Check for whitespace errors in the Git diff.
whitespace:
	@if [ -n "$$CI" ]; then \
		git diff --check "$$(git hash-object -t tree /dev/null)" HEAD; \
	else \
		git diff --check HEAD; \
	fi

# Run the GitHub Actions check workflow locally with act and Docker.
act:
	$(ACT) push -W .github/workflows/check.yml

# Replace the installed plugin with a symlink to this checkout.
local:
	@set -eu; \
	if [ -L "$(PLUGIN_PATH)" ] && [ "$$(readlink -f "$(PLUGIN_PATH)")" = "$$(pwd -P)" ]; then \
		echo "$(PLUGIN_ID) is already linked to $$(pwd -P)"; \
	else \
		if [ -e "$(PLUGIN_PATH)" ] || [ -L "$(PLUGIN_PATH)" ]; then \
			backup="$(PLUGIN_DIR)/.$(PLUGIN_ID).installed.$$(date -u +%Y%m%d%H%M%S)"; \
			mv "$(PLUGIN_PATH)" "$$backup"; \
			echo "Moved the installed plugin to $$backup"; \
		fi; \
		ln -s "$$(pwd -P)" "$(PLUGIN_PATH)"; \
		echo "Linked $(PLUGIN_ID) to $$(pwd -P)"; \
	fi; \
	omarchy-shell shell rescanPlugins; \
	omarchy plugin enable $(PLUGIN_ID)

# Download and enable the plugin from PLUGIN_REPO.
install:
	@set -eu; \
	if [ -e "$(PLUGIN_PATH)" ] || [ -L "$(PLUGIN_PATH)" ]; then \
		backup="$(PLUGIN_DIR)/.$(PLUGIN_ID).previous.$$(date -u +%Y%m%d%H%M%S)"; \
		mv "$(PLUGIN_PATH)" "$$backup"; \
		echo "Moved the existing plugin to $$backup"; \
	fi; \
	omarchy plugin add "$(PLUGIN_REPO)" --enable --yes
