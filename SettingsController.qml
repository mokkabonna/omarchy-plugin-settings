import QtQuick

QtObject {
  id: root

  property var shell: null
  property var barWidgetRegistry: null
  property var pluginRegistry: null
  property string selectedId: ""
  property string selectedKind: ""
  property string selectedSection: ""
  property int selectedIndex: -1
  property var selectedDefinition: null
  property var draft: ({})
  property string status: ""

  readonly property var selectedMetadata: selectedDefinition
  readonly property var schema: selectedMetadata && selectedMetadata.schema
    ? selectedMetadata.schema : []

  function valueFor(field) {
    if (draft[field.key] !== undefined) return draft[field.key]
    if (field.defaultValue !== undefined) return field.defaultValue
    var defaults = selectedMetadata && selectedMetadata.defaults ? selectedMetadata.defaults : {}
    return defaults[field.key]
  }

  function widgetInstancesWithSchemas() {
    if (!barWidgetRegistry || !shell || !shell.shellConfig) return []
    var result = []
    var layout = shell.shellConfig.bar && shell.shellConfig.bar.layout ? shell.shellConfig.bar.layout : {}
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var entries = layout[sections[s]] || []
      for (var i = 0; i < entries.length; i++) {
        var entry = entries[i]
        if (!entry || !entry.id) continue
        var metadata = barWidgetRegistry.metadataFor(entry.id)
        if (metadata && metadata.schema && metadata.schema.length > 0)
          result.push({ kind: "bar-widget", id: entry.id, section: sections[s], index: i, entry: entry,
            metadata: metadata, locationLabel: sections[s] + " bar" })
      }
    }
    return result
  }

  function shellDefinition(section) {
    var defaultsConfig = shell && shell.defaultsConfig ? shell.defaultsConfig : {}
    if (section === "bar") {
      var barDefaults = defaultsConfig.bar || {}
      return {
        displayName: "Bar",
        description: "Configure the Omarchy shell bar.",
        defaults: {
          position: barDefaults.position !== undefined ? barDefaults.position : "top",
          transparent: barDefaults.transparent !== undefined ? barDefaults.transparent : false
        },
        schema: [
          { key: "position", label: "Position", description: "Screen edge used by the bar.", type: "enum",
            options: ["top", "bottom", "left", "right"] },
          { key: "transparent", label: "Transparent", description: "Use the wallpaper-aware transparent bar style.", type: "boolean" }
        ]
      }
    }
    var idleDefaults = defaultsConfig.idle || {}
    return {
      displayName: "Idle",
      description: "Configure Omarchy screensaver and lock timeouts.",
      defaults: {
        screensaver: idleDefaults.screensaver !== undefined ? idleDefaults.screensaver : 150,
        lock: idleDefaults.lock !== undefined ? idleDefaults.lock : 300
      },
      schema: [
        { key: "screensaver", label: "Screensaver timeout", description: "Seconds of inactivity before the screensaver starts.",
          type: "integer", min: 0, step: 30 },
        { key: "lock", label: "Lock timeout", description: "Seconds of inactivity before the session locks.",
          type: "integer", min: 0, step: 30 }
      ]
    }
  }

  function shellSettingsEntries() {
    if (!shell || !shell.shellConfig) return []
    var config = shell.shellConfig
    var bar = config.bar || {}
    var idle = config.idle || {}
    return [
      { kind: "shell", id: "omarchy.shell.bar", section: "bar", index: -1,
        entry: { position: bar.position, transparent: bar.transparent },
        metadata: shellDefinition("bar"), locationLabel: "Omarchy shell" },
      { kind: "shell", id: "omarchy.shell.idle", section: "idle", index: -1,
        entry: { screensaver: idle.screensaver, lock: idle.lock },
        metadata: shellDefinition("idle"), locationLabel: "Omarchy shell" }
    ]
  }

  function pluginInstancesWithSchemas() {
    if (!pluginRegistry || !pluginRegistry.installedPlugins || !shell || !shell.shellConfig) return []
    var result = []
    var config = shell.shellConfig
    var plugins = config.plugins || []
    var supportedKinds = ["panel", "overlay", "menu", "service"]
    for (var id in pluginRegistry.installedPlugins) {
      var pluginManifest = pluginRegistry.installedPlugins[id]
      var definition = pluginManifest && pluginManifest.settings
      if (!definition || !definition.schema || definition.schema.length === 0) continue
      var kinds = pluginManifest.kinds || []
      if (kinds.indexOf("bar") !== -1) {
        if (config.bar && config.bar.id === id)
          result.push({ kind: "bar", id: id, section: "bar", index: -1, entry: config.bar,
            metadata: definition, locationLabel: "Active bar" })
        continue
      }
      var supportsPluginSettings = false
      for (var k = 0; k < supportedKinds.length; k++)
        if (kinds.indexOf(supportedKinds[k]) !== -1) supportsPluginSettings = true
      if (!supportsPluginSettings) continue
      var found = false
      for (var i = 0; i < plugins.length; i++) {
        if (!plugins[i] || plugins[i].id !== id) continue
        result.push({ kind: "plugin", id: id, section: "plugins", index: i, entry: plugins[i],
          metadata: definition, locationLabel: "Plugin instance " + (i + 1) })
        found = true
      }
      if (!found && pluginRegistry.isEnabled && pluginRegistry.isEnabled(id))
        result.push({ kind: "plugin", id: id, section: "plugins", index: -1, entry: { id: id },
          metadata: definition, locationLabel: "Plugin defaults" })
    }
    return result
  }

  function configurableEntries() {
    return shellSettingsEntries().concat(widgetInstancesWithSchemas(), pluginInstancesWithSchemas())
  }

  function selectWidget(instance) {
    selectedId = instance.id
    selectedKind = instance.kind
    selectedSection = instance.section
    selectedIndex = instance.index
    selectedDefinition = instance.metadata
    status = ""
    var next = ({})
    for (var key in instance.entry) if (key !== "id") next[key] = instance.entry[key]
    draft = next
  }

  function setValue(key, value) {
    var next = ({})
    for (var existing in draft) next[existing] = draft[existing]
    next[key] = value
    draft = next
  }

  function enumOptionValue(option) {
    return typeof option === "object" ? String(option.value) : String(option)
  }

  function isOnOffEnum(field) {
    if (!field || field.type !== "enum" || !field.options || field.options.length !== 2) return false
    var first = enumOptionValue(field.options[0]).toLowerCase()
    var second = enumOptionValue(field.options[1]).toLowerCase()
    return (first === "off" && second === "on") || (first === "on" && second === "off")
  }

  function multiValues(field) {
    var value = valueFor(field)
    return Array.isArray(value) ? value : []
  }

  function toggleMultiselect(field, value) {
    var next = multiValues(field).slice()
    var index = next.indexOf(value)
    if (index === -1) next.push(value)
    else next.splice(index, 1)
    setValue(field.key, next)
  }

  function normalizedNumber(field, value) {
    var numeric = Number(value)
    if (!isFinite(numeric)) return undefined
    if (field.min !== undefined) numeric = Math.max(Number(field.min), numeric)
    if (field.max !== undefined) numeric = Math.min(Number(field.max), numeric)
    if (field.step !== undefined && Number(field.step) > 0) {
      var base = field.min !== undefined ? Number(field.min) : 0
      numeric = base + Math.round((numeric - base) / Number(field.step)) * Number(field.step)
    }
    return field.type === "integer" ? Math.round(numeric) : numeric
  }

  function resetToDefaults() {
    if (!selectedMetadata) return
    var next = ({})
    for (var key in draft) next[key] = draft[key]
    var defaults = selectedMetadata.defaults || {}
    for (var i = 0; i < schema.length; i++) {
      var field = schema[i]
      delete next[field.key]
      if (defaults[field.key] !== undefined) next[field.key] = defaults[field.key]
      else if (field.defaultValue !== undefined) next[field.key] = field.defaultValue
    }
    draft = next
    status = selectedKind === "shell"
      ? "Reset to Omarchy defaults"
      : "Reset to manifest defaults"
  }

  function save() {
    if (!shell || !selectedId || !selectedKind || typeof shell.mutateShellConfig !== "function") return
    var values = ({})
    for (var key in draft) values[key] = draft[key]
    for (var i = 0; i < schema.length; i++) {
      var field = schema[i]
      if (values[field.key] === undefined && field.defaultValue !== undefined)
        values[field.key] = field.defaultValue
      if (["integer", "number"].indexOf(field.type) !== -1 && values[field.key] !== undefined) {
        var normalized = normalizedNumber(field, values[field.key])
        if (normalized === undefined) {
          status = (field.label || field.key) + " must be a number"
          return
        }
        values[field.key] = normalized
      }
    }
    var saved = false
    var persistedIndex = selectedIndex
    shell.mutateShellConfig(function(config) {
      var next = { id: selectedId }
      for (var name in values) next[name] = values[name]
      if (selectedKind === "shell") {
        var target = null
        if (selectedSection === "bar") {
          if (!config.bar || typeof config.bar !== "object") config.bar = {}
          target = config.bar
        } else if (selectedSection === "idle") {
          if (!config.idle || typeof config.idle !== "object") config.idle = {}
          target = config.idle
        }
        if (!target) return
        for (var shellKey in values) target[shellKey] = values[shellKey]
        saved = true
      } else if (selectedKind === "bar-widget") {
        var layout = config.bar && config.bar.layout ? config.bar.layout : {}
        var entries = layout[selectedSection] || []
        if (!entries[selectedIndex] || entries[selectedIndex].id !== selectedId) return
        entries[selectedIndex] = next
        saved = true
      } else if (selectedKind === "bar") {
        if (!config.bar || config.bar.id !== selectedId) return
        config.bar = next
        saved = true
      } else if (selectedKind === "plugin") {
        if (!Array.isArray(config.plugins)) config.plugins = []
        if (selectedIndex >= 0) {
          if (!config.plugins[selectedIndex] || config.plugins[selectedIndex].id !== selectedId) return
          config.plugins[selectedIndex] = next
        } else {
          config.plugins.push(next)
          persistedIndex = config.plugins.length - 1
        }
        saved = true
      }
    })
    if (!saved) {
      status = "This item moved or is no longer enabled; select it again"
      return
    }
    selectedIndex = persistedIndex
    draft = values
    status = "Saved to shell.json"
  }
}
