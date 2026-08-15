import QtQuick
import QtTest
import ".." as Plugin

TestCase {
  name: "Panel"

  QtObject {
    id: shellFixture
    property var shellConfig: ({
      bar: {
        position: "top",
        transparent: false,
        layout: { right: [{ id: "example.widget", enabled: true }] }
      },
      idle: { screensaver: 150, lock: 300 },
      plugins: [{ id: "example.plugin", enabled: false, mode: "safe" }]
    })
    property var defaultsConfig: ({
      bar: { position: "bottom", transparent: true },
      idle: { screensaver: 120, lock: 240 }
    })
    property int hideCalls: 0
    property string hiddenId: ""
    function mutateShellConfig(callback) { callback(shellConfig) }
    function hide(id) {
      hideCalls++
      hiddenId = id
    }
  }

  QtObject {
    id: barWidgetRegistryFixture
    function metadataFor(id) {
      if (id !== "example.widget") return null
      return {
        displayName: "Example widget",
        schema: [{ key: "enabled", type: "boolean" }],
        defaults: { enabled: false }
      }
    }
  }

  QtObject {
    id: pluginRegistryFixture
    property var installedPlugins: ({
      "example.plugin": {
        kinds: ["panel"],
        settings: {
          displayName: "Example plugin",
          schema: [
            { key: "enabled", type: "boolean" },
            { key: "mode", type: "enum", options: ["safe", "fast"] }
          ],
          defaults: { enabled: true, mode: "safe" }
        }
      },
      "defaults.plugin": {
        kinds: ["panel"],
        settings: {
          displayName: "Defaults plugin",
          schema: [{ key: "enabled", type: "boolean" }],
          defaults: { enabled: true }
        }
      },
      "active.bar": {
        kinds: ["bar"],
        settings: {
          displayName: "Active bar",
          schema: [{ key: "mode", type: "enum", options: ["balanced", "compact"] }],
          defaults: { mode: "balanced" }
        }
      },
      "unsupported.plugin": {
        kinds: ["bar-widget"],
        settings: { schema: [{ key: "value", type: "string" }] }
      }
    })
    function isEnabled(id) { return id === "example.plugin" || id === "defaults.plugin" }
  }

  Plugin.Panel {
    id: panel
    shell: shellFixture
    barWidgetRegistry: barWidgetRegistryFixture
    pluginRegistry: pluginRegistryFixture
  }

  function init() {
    shellFixture.shellConfig = ({
      bar: {
        position: "top",
        transparent: false,
        layout: { right: [{ id: "example.widget", enabled: true }] }
      },
      idle: { screensaver: 150, lock: 300 },
      plugins: [{ id: "example.plugin", enabled: false, mode: "safe" }]
    })
    panel.selectedId = ""
    panel.selectedKind = ""
    panel.selectedSection = ""
    panel.selectedIndex = -1
    panel.selectedDefinition = null
    panel.draft = ({})
    panel.savedDraft = ({})
    panel.status = ""
    panel.manifest = { id: "test.plugin-settings" }
    shellFixture.hideCalls = 0
    shellFixture.hiddenId = ""
  }

  function entryWith(id, kind) {
    var entries = panel.configurableEntries()
    for (var i = 0; i < entries.length; i++)
      if (entries[i].id === id && (!kind || entries[i].kind === kind)) return entries[i]
    return null
  }

  function test_shell_and_plugin_discovery() {
    var entries = panel.configurableEntries()
    compare(entries.length, 5)
    compare(entries[0].id, "omarchy.shell.bar")
    compare(entries[1].id, "omarchy.shell.idle")
    compare(entries[2].id, "example.widget")
    compare(entries[3].id, "example.plugin")
    compare(entries[4].id, "defaults.plugin")
    compare(entries[2].locationLabel, "right bar · position 1")
    compare(entries[3].locationLabel, "Plugin instance 1")
    compare(entries[4].locationLabel, "Plugin defaults")
  }

  function test_select_and_reset_to_defaults() {
    var entry = panel.configurableEntries()[3]
    panel.selectWidget(entry)
    compare(panel.valueFor({ key: "mode" }), "safe")
    panel.setValue("mode", "fast")
    panel.setValue("enabled", false)
    verify(panel.dirty)

    panel.resetToDefaults()
    compare(panel.draft.enabled, true)
    compare(panel.draft.mode, "safe")
    compare(panel.status, "Reset to manifest defaults — save to apply")
  }

  function test_numeric_normalization() {
    compare(panel.normalizedNumber({ type: "integer", min: 0, max: 300, step: 30 }, 44), 30)
    compare(panel.normalizedNumber({ type: "integer", min: 0, max: 300, step: 30 }, 316), 300)
    compare(panel.normalizedNumber({ type: "number", min: 1, step: 0.5 }, 2.24), 2)
    compare(panel.normalizedNumber({ type: "number" }, "not-a-number"), undefined)
  }

  function test_multiselect_toggle() {
    var field = { key: "features", type: "multiselect" }
    panel.selectedDefinition = { schema: [field], defaults: { features: ["a"] } }
    panel.draft = ({ features: ["a"] })
    compare(panel.multiValues(field), ["a"])

    panel.toggleMultiselect(field, "b")
    compare(panel.draft.features, ["a", "b"])
    panel.toggleMultiselect(field, "a")
    compare(panel.draft.features, ["b"])
  }

  function test_save_updates_only_selected_plugin_instance() {
    var entry = panel.configurableEntries()[3]
    panel.selectWidget(entry)
    panel.setValue("mode", "fast")
    panel.setValue("enabled", true)
    panel.save()

    compare(shellFixture.shellConfig.plugins[0].id, "example.plugin")
    compare(shellFixture.shellConfig.plugins[0].mode, "fast")
    compare(shellFixture.shellConfig.plugins[0].enabled, true)
    compare(shellFixture.shellConfig.plugins.length, 1)
    compare(panel.status, "Saved to shell.json")
    verify(!panel.dirty)
  }

  function test_save_updates_shell_bar_and_preserves_layout() {
    panel.selectWidget(entryWith("omarchy.shell.bar", "shell"))
    panel.setValue("transparent", true)
    panel.setValue("position", "bottom")
    panel.save()

    compare(shellFixture.shellConfig.bar.transparent, true)
    compare(shellFixture.shellConfig.bar.position, "bottom")
    compare(shellFixture.shellConfig.bar.layout.right[0].id, "example.widget")
    compare(panel.status, "Saved to shell.json")
  }

  function test_save_updates_shell_idle_settings() {
    panel.selectWidget(entryWith("omarchy.shell.idle", "shell"))
    panel.setValue("screensaver", 180)
    panel.setValue("lock", 360)
    panel.save()

    compare(shellFixture.shellConfig.idle.screensaver, 180)
    compare(shellFixture.shellConfig.idle.lock, 360)
    compare(panel.status, "Saved to shell.json")
  }

  function test_save_updates_bar_widget_instance() {
    panel.selectWidget(entryWith("example.widget", "bar-widget"))
    panel.setValue("enabled", false)
    panel.save()

    compare(shellFixture.shellConfig.bar.layout.right[0].id, "example.widget")
    compare(shellFixture.shellConfig.bar.layout.right[0].enabled, false)
    compare(panel.status, "Saved to shell.json")
  }

  function test_save_updates_active_bar_plugin() {
    var config = shellFixture.shellConfig
    config.bar = { id: "active.bar", mode: "balanced", other: "removed" }
    shellFixture.shellConfig = config
    var entry = entryWith("active.bar", "bar")
    compare(entry !== null, true, JSON.stringify(panel.configurableEntries()))
    panel.selectWidget(entry)
    panel.setValue("mode", "compact")
    panel.save()

    compare(shellFixture.shellConfig.bar.id, "active.bar")
    compare(shellFixture.shellConfig.bar.mode, "compact")
    compare(shellFixture.shellConfig.bar.other, "removed")
    compare(panel.status, "Saved to shell.json")
  }

  function test_invalid_number_is_rejected_without_mutating_config() {
    panel.selectWidget(entryWith("omarchy.shell.idle", "shell"))
    panel.setValue("screensaver", "not-a-number")
    panel.save()

    compare(shellFixture.shellConfig.idle.screensaver, 150)
    compare(panel.status, "Screensaver timeout must be a number")
    verify(panel.dirty)
  }

  function test_save_adds_missing_plugin_instance() {
    shellFixture.shellConfig.plugins = []
    var entry = entryWith("defaults.plugin", "plugin")
    verify(entry !== null)
    compare(entry.index, -1)
    panel.selectWidget(entry)
    panel.setValue("enabled", false)
    panel.save()

    compare(shellFixture.shellConfig.plugins.length, 1)
    compare(shellFixture.shellConfig.plugins[0].id, "defaults.plugin")
    compare(shellFixture.shellConfig.plugins[0].enabled, false)
    compare(panel.selectedIndex, 0)
  }

  function test_save_rejects_moved_bar_widget() {
    panel.selectWidget(entryWith("example.widget", "bar-widget"))
    panel.setValue("enabled", false)
    shellFixture.shellConfig.bar.layout.right = []
    panel.save()

    compare(shellFixture.shellConfig.bar.layout.right.length, 0)
    compare(panel.status, "This item moved or is no longer enabled; select it again before saving")
    verify(panel.dirty)
  }

  function test_panel_open_close_and_host_close_request() {
    panel.open("")
    verify(panel.opened)
    compare(panel.selectedId, "omarchy.shell.bar")

    panel.requestClose()
    compare(shellFixture.hideCalls, 1)
    compare(shellFixture.hiddenId, "test.plugin-settings")

    panel.close()
    verify(!panel.opened)
    verify(!panel.shortcutsVisible)
  }
}
