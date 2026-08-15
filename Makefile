.PHONY: check test integration lint manifest whitespace act local install reload release

QML_FILES := Panel.qml BarWidget.qml SettingsController.qml SettingsField.qml ShortcutOverlay.qml
QMLLINT ?= qmllint
QMLLINT_ARGS ?=
QMLLINT_IMPORT_PATH ?= tests/qml-stubs
QMLTEST ?= /usr/lib/qt6/bin/qmltestrunner
ACT ?= act
PLUGIN_ID ?= mokkabonna.plugin-settings
PLUGIN_DIR ?= $(HOME)/.config/omarchy/plugins
PLUGIN_PATH := $(PLUGIN_DIR)/$(PLUGIN_ID)
PLUGIN_REPO ?= https://github.com/mokkabonna/omarchy-plugin-settings.git
RELEASE_CHECK ?= check

# Run every local validation check.
check: test integration lint manifest whitespace

# Run QML behavior tests without requiring a display server.
test:
	QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= $(QMLTEST) -input tests -import $(QMLLINT_IMPORT_PATH) -import .

# Test the local and downloaded plugin workflows in a temporary environment.
integration:
	bash tests/test_make.sh

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

# Reload QML changes by restarting the Omarchy shell.
reload:
	omarchy restart shell

# Validate, commit, and tag a release; publish it separately with git push.
release:
	@if [ -z "$(VERSION)" ]; then \
		echo "Usage: make release VERSION=x.y.z" >&2; \
		exit 1; \
	fi
	@if ! printf '%s\n' "$(VERSION)" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$'; then \
		echo "VERSION must use x.y.z format" >&2; \
		exit 1; \
	fi
	@if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$$(git ls-files --others --exclude-standard)" ]; then \
		echo "Release requires a clean working tree" >&2; \
		exit 1; \
	fi
	@if git rev-parse -q --verify "refs/tags/v$(VERSION)" >/dev/null; then \
		echo "Tag v$(VERSION) already exists" >&2; \
		exit 1; \
	fi
	@if [ "$$(jq -r '.version' manifest.json)" = "$(VERSION)" ]; then \
		echo "manifest.json is already at version $(VERSION)" >&2; \
		exit 1; \
	fi
	@tmp="$$(mktemp ./manifest.json.release.XXXXXX)"; \
	trap 'rm -f "$$tmp"' EXIT; \
	jq --arg version "$(VERSION)" '.version = $$version' manifest.json > "$$tmp"; \
	mv "$$tmp" manifest.json; \
	trap - EXIT
	$(MAKE) $(RELEASE_CHECK)
	git add manifest.json
	git commit -m "Release v$(VERSION)"
	git tag -a "v$(VERSION)" -m "v$(VERSION)"
	@echo "Created v$(VERSION). Publish with: git push origin HEAD v$(VERSION)"

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
