.PHONY: check lint manifest whitespace

QML_FILES := Panel.qml BarWidget.qml
QMLLINT ?= qmllint
QMLLINT_ARGS ?=
QMLLINT_IMPORT_PATH ?= tests/qml-stubs

check: lint manifest whitespace

lint:
	$(QMLLINT) -I $(QMLLINT_IMPORT_PATH) $(QMLLINT_ARGS) $(QML_FILES)

manifest:
	jq -e '(.schemaVersion == 1) and (.id | type == "string" and length > 0) and (.name | type == "string" and length > 0) and (.version | type == "string" and length > 0) and (.entryPoints.panel == "Panel.qml") and (.entryPoints.barWidget == "BarWidget.qml")' manifest.json >/dev/null

whitespace:
	@if [ -n "$$CI" ]; then \
		git diff --check "$$(git hash-object -t tree /dev/null)" HEAD; \
	else \
		git diff --check HEAD; \
	fi
