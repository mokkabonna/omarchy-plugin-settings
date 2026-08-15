import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var barWidgetRegistry: null
  property var pluginRegistry: null
  property bool opened: false
  property bool closingFromHost: false
  property string selectedId: ""
  property string selectedKind: ""
  property string selectedSection: ""
  property int selectedIndex: -1
  property var selectedDefinition: null
  property var draft: ({})
  property var savedDraft: ({})
  property string status: ""
  property bool shortcutsVisible: false

  readonly property var shortcutItems: [
    { keys: "↑ / ↓", action: "Previous / next item" },
    { keys: "Home / End", action: "First / last item" },
    { keys: "Ctrl+1 … 9", action: "Select item by list position" },
    { keys: "Tab / Shift+Tab", action: "Move keyboard focus" },
    { keys: "Enter / Space", action: "Activate the focused control" },
    { keys: "↑ / ↓ in number", action: "Adjust by the configured step" },
    { keys: "Page Up / Down", action: "Scroll the settings form" },
    { keys: "Ctrl+S", action: "Save pending changes" },
    { keys: "Ctrl+R", action: "Reset to defaults" },
    { keys: "Esc / Ctrl+W", action: "Close" },
    { keys: "?", action: "Show or hide this reference" }
  ]

  readonly property bool dirty: JSON.stringify(draft) !== JSON.stringify(savedDraft)

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
            metadata: metadata, locationLabel: sections[s] + " bar · instance " + (i + 1) })
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
    savedDraft = JSON.parse(JSON.stringify(next))
  }

  function selectRelativeWidget(offset) {
    var widgets = configurableEntries()
    if (widgets.length === 0) return
    var current = -1
    for (var i = 0; i < widgets.length; i++) {
      if (widgets[i].id === selectedId && widgets[i].kind === selectedKind && widgets[i].section === selectedSection
          && widgets[i].index === selectedIndex) {
        current = i
        break
      }
    }
    var next = current < 0 ? 0 : Math.max(0, Math.min(widgets.length - 1, current + offset))
    selectWidget(widgets[next])
    widgetList.positionViewAtIndex(next, ListView.Contain)
  }

  function selectWidgetAt(listIndex) {
    var widgets = configurableEntries()
    if (listIndex < 0 || listIndex >= widgets.length) return
    selectWidget(widgets[listIndex])
    widgetList.positionViewAtIndex(listIndex, ListView.Contain)
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
      ? "Reset to Omarchy defaults — save to apply"
      : "Reset to manifest defaults — save to apply"
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
      status = "This item moved or is no longer enabled; select it again before saving"
      return
    }
    selectedIndex = persistedIndex
    draft = values
    savedDraft = JSON.parse(JSON.stringify(values))
    status = "Saved to shell.json"
  }

  function open(payloadJson) {
    opened = true
    shortcutsVisible = false
    window.visible = true
    var entries = configurableEntries()
    if ((!selectedId || !selectedKind) && entries.length > 0) selectWidget(entries[0])
  }

  function close() {
    closingFromHost = true
    shortcutsVisible = false
    opened = false
    window.visible = false
    closingFromHost = false
  }

  function requestClose() {
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "mokkabonna.plugin-settings")
    else close()
  }

  function toggleShortcuts() {
    shortcutsVisible = !shortcutsVisible
    if (shortcutsVisible)
      Qt.callLater(function() { shortcutsCloseMouse.forceActiveFocus() })
    else
      Qt.callLater(function() { shortcutsMouse.forceActiveFocus() })
  }

  function hideShortcuts() {
    if (!shortcutsVisible) return
    shortcutsVisible = false
    Qt.callLater(function() { shortcutsMouse.forceActiveFocus() })
  }

  function focusFirstFormControl() {
    var pending = []
    if (form.children)
      for (var first = 0; first < form.children.length; first++) pending.push(form.children[first])
    while (pending.length > 0) {
      var item = pending.shift()
      if (!item || !item.visible || !item.enabled) continue
      if (item.activeFocusOnTab && typeof item.forceActiveFocus === "function") {
        item.forceActiveFocus()
        return true
      }
      if (item.children)
        for (var i = 0; i < item.children.length; i++) pending.push(item.children[i])
    }
    return false
  }

  FloatingWindow {
    id: window
    title: "Plugin Settings"
    visible: root.opened
    color: Color.menu.background
    implicitWidth: 900
    implicitHeight: 650
    minimumSize: Qt.size(680, 480)
    onVisibleChanged: {
      if (!visible && !root.closingFromHost && root.shell && typeof root.shell.hide === "function")
        root.shell.hide((root.manifest && root.manifest.id) || "mokkabonna.plugin-settings")
    }

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: Color.menu.background
      border.color: Color.menu.border
      border.width: 1
      focus: true
      Keys.priority: Keys.AfterItem
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          if (root.shortcutsVisible) root.hideShortcuts()
          else root.requestClose()
          event.accepted = true
        } else if (event.text === "?") {
          root.toggleShortcuts()
          event.accepted = true
        } else if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
          root.save()
          event.accepted = true
        } else if (event.key === Qt.Key_R && (event.modifiers & Qt.ControlModifier)) {
          root.resetToDefaults()
          event.accepted = true
        } else if (event.key === Qt.Key_W && (event.modifiers & Qt.ControlModifier)) {
          root.requestClose()
          event.accepted = true
        } else if (event.key === Qt.Key_PageUp && event.modifiers === Qt.NoModifier) {
          formFlickable.contentY = Math.max(0, formFlickable.contentY - formFlickable.height * 0.8)
          event.accepted = true
        } else if (event.key === Qt.Key_PageDown && event.modifiers === Qt.NoModifier) {
          formFlickable.contentY = Math.min(formFlickable.contentHeight - formFlickable.height,
            formFlickable.contentY + formFlickable.height * 0.8)
          event.accepted = true
        } else if (event.modifiers & Qt.ControlModifier) {
          var numberKeys = [Qt.Key_1, Qt.Key_2, Qt.Key_3, Qt.Key_4, Qt.Key_5,
            Qt.Key_6, Qt.Key_7, Qt.Key_8, Qt.Key_9]
          var listIndex = numberKeys.indexOf(event.key)
          if (listIndex < 0) return
          root.selectWidgetAt(listIndex)
          event.accepted = true
        }
      }

      RowLayout {
        id: mainContent
        anchors.fill: parent
        anchors.margins: Style.space(18)
        spacing: Style.space(14)
        enabled: !root.shortcutsVisible

        Rectangle {
          Layout.preferredWidth: 245
          Layout.fillHeight: true
          color: Color.menu.background

          ColumnLayout {
            anchors.fill: parent
            spacing: Style.space(1)

            Text {
              Layout.fillWidth: true
              text: "Plugin Settings"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.heading
              font.bold: true
              wrapMode: Text.WordWrap
            }
            Text {
              Layout.fillWidth: true
              text: "Omarchy shell and schema-enabled plugins"
              color: Color.foreground
              opacity: 0.65
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Color.menu.border }

            ListView {
              id: widgetList
              activeFocusOnTab: true
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              model: root.configurableEntries()
              delegate: Rectangle {
                required property var modelData
                width: widgetList.width
                height: 54
                radius: Style.cornerRadius / 2
                readonly property bool selectedInstance: root.selectedId === modelData.id
                  && root.selectedKind === modelData.kind && root.selectedSection === modelData.section
                  && root.selectedIndex === modelData.index
                color: selectedInstance ? Color.menu.selectedBackground : "transparent"
                border.color: widgetList.activeFocus && selectedInstance ? Color.accent : "transparent"
                border.width: widgetList.activeFocus && selectedInstance ? 2 : 0
                Column {
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  spacing: Style.space(2)
                  Text {
                    width: parent.width
                    text: modelData.metadata.displayName || modelData.id
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                  }
                  Text {
                    width: parent.width
                    text: modelData.locationLabel
                    color: Color.foreground
                    opacity: 0.6
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideRight
                  }
                }
                MouseArea {
                  anchors.fill: parent
                  onClicked: {
                    widgetList.forceActiveFocus()
                    root.selectWidget(modelData)
                  }
                }
              }
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Tab) {
                  if (event.modifiers & Qt.ShiftModifier) closeMouse.forceActiveFocus()
                  else root.focusFirstFormControl()
                  event.accepted = true
                  return
                }
                if (event.modifiers !== Qt.NoModifier) return
                if (event.key === Qt.Key_Up) root.selectRelativeWidget(-1)
                else if (event.key === Qt.Key_Down) root.selectRelativeWidget(1)
                else if (event.key === Qt.Key_Home) root.selectRelativeWidget(-9999)
                else if (event.key === Qt.Key_End) root.selectRelativeWidget(9999)
                else return
                event.accepted = true
              }
            }
          }
        }

        Rectangle { Layout.fillHeight: true; width: 1; color: Color.menu.border }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(2)

          RowLayout {
            Layout.fillWidth: true
            Text {
              Layout.fillWidth: true
              text: root.selectedMetadata ? root.selectedMetadata.displayName : "No configurable item selected"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.heading
              font.bold: true
              elide: Text.ElideRight
            }
            Rectangle {
              width: shortcutsLabel.implicitWidth + Style.space(24)
              height: Style.space(36)
              radius: Style.cornerRadius / 2
              color: shortcutsMouse.containsMouse ? Color.menu.selectedBackground : "transparent"
              border.color: shortcutsMouse.activeFocus ? Color.accent : Color.menu.border
              border.width: shortcutsMouse.activeFocus ? 2 : 1
              Text {
                id: shortcutsLabel
                anchors.centerIn: parent
                text: "Shortcuts"
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
              MouseArea {
                id: shortcutsMouse
                anchors.fill: parent
                activeFocusOnTab: true
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleShortcuts()
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Tab) {
                    if (event.modifiers & Qt.ShiftModifier) saveMouse.forceActiveFocus()
                    else closeMouse.forceActiveFocus()
                    event.accepted = true
                  } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root.toggleShortcuts()
                    event.accepted = true
                  }
                }
              }
            }
            Rectangle {
              width: Style.space(36)
              height: Style.space(36)
              radius: Style.cornerRadius / 2
              color: closeMouse.containsMouse ? Color.menu.selectedBackground : "transparent"
              border.color: closeMouse.activeFocus ? Color.accent : Color.menu.border
              border.width: closeMouse.activeFocus ? 2 : 1
              Text {
                anchors.centerIn: parent
                text: "×"
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.heading
              }
              MouseArea {
                id: closeMouse
                anchors.fill: parent
                activeFocusOnTab: true
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.requestClose()
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Tab) {
                    if (event.modifiers & Qt.ShiftModifier) shortcutsMouse.forceActiveFocus()
                    else widgetList.forceActiveFocus()
                    event.accepted = true
                  } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root.requestClose()
                    event.accepted = true
                  }
                }
              }
            }
          }
          Text {
            Layout.fillWidth: true
            visible: root.selectedMetadata && root.selectedMetadata.description
            text: root.selectedMetadata ? root.selectedMetadata.description : ""
            color: Color.foreground
            opacity: 0.65
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          Flickable {
            id: formFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Style.space(10)
            contentWidth: width
            contentHeight: form.implicitHeight
            clip: true

            ColumnLayout {
              id: form
              width: parent.width
              spacing: Style.space(14)
              Repeater {
                model: root.schema
                delegate: ColumnLayout {
                  required property var modelData
                  required property int index
                  Layout.fillWidth: true
                  spacing: Style.space(1)
                  Text {
                    text: modelData.label || modelData.key
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                  }
                  Text {
                    Layout.fillWidth: true
                    visible: modelData.description !== undefined
                    text: modelData.description || ""
                    color: Color.foreground
                    opacity: 0.65
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.WordWrap
                  }
                  Rectangle {
                    Layout.fillWidth: true
                    visible: ["string", "path", "integer", "number"].indexOf(modelData.type) !== -1
                    Layout.preferredHeight: Style.space(36)
                    color: Color.menu.background
                    border.color: Color.menu.border
                    border.width: 1
                    radius: Style.cornerRadius / 2

                    TextInput {
                      activeFocusOnTab: true
                      KeyNavigation.backtab: index === 0 ? widgetList : null
                      anchors.fill: parent
                      anchors.leftMargin: Style.space(10)
                      anchors.rightMargin: Style.space(10)
                      anchors.topMargin: Style.space(6)
                      anchors.bottomMargin: Style.space(6)
                      text: String(root.valueFor(modelData) === undefined ? "" : root.valueFor(modelData))
                      color: Color.foreground
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      selectByMouse: true
                      verticalAlignment: TextInput.AlignVCenter
                      onTextEdited: root.setValue(modelData.key, text)
                      onEditingFinished: {
                        var value = text
                        if (modelData.type === "integer" || modelData.type === "number")
                          value = root.normalizedNumber(modelData, text)
                        if (value === undefined) return
                        root.setValue(modelData.key, value)
                      }
                      Keys.onPressed: function(event) {
                        if ((event.key !== Qt.Key_Up && event.key !== Qt.Key_Down)
                            || (modelData.type !== "integer" && modelData.type !== "number")) return
                        var current = root.normalizedNumber(modelData, text)
                        if (current === undefined) current = Number(root.valueFor(modelData)) || 0
                        var step = modelData.step !== undefined && Number(modelData.step) > 0
                          ? Number(modelData.step) : 1
                        var next = root.normalizedNumber(modelData,
                          current + (event.key === Qt.Key_Up ? step : -step))
                        if (next !== undefined) root.setValue(modelData.key, next)
                        event.accepted = true
                      }
                    }
                  }
                  Text {
                    visible: ["integer", "number"].indexOf(modelData.type) !== -1
                      && (modelData.min !== undefined || modelData.max !== undefined || modelData.step !== undefined)
                    text: ""
                      + (modelData.min !== undefined ? "Min " + modelData.min : "")
                      + (modelData.min !== undefined && modelData.max !== undefined ? " · " : "")
                      + (modelData.max !== undefined ? "Max " + modelData.max : "")
                      + ((modelData.min !== undefined || modelData.max !== undefined) && modelData.step !== undefined ? " · " : "")
                      + (modelData.step !== undefined ? "Step " + modelData.step : "")
                    color: Color.foreground
                    opacity: 0.6
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                  }
                  RowLayout {
                    visible: modelData.type === "boolean"
                    spacing: Style.space(8)
                    Rectangle {
                      readonly property bool checked: root.valueFor(modelData) === true
                      width: Style.space(42); height: Style.space(24); radius: height / 2
                      color: checked ? Color.accent : Color.menu.background
                      border.color: booleanToggleMouse.activeFocus ? Color.foreground
                        : (checked ? Color.accent : Color.menu.border)
                      border.width: booleanToggleMouse.activeFocus ? 2 : 1
                      Rectangle {
                        width: parent.height - Style.space(4)
                        height: width
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.checked ? parent.width - width - Style.space(2) : Style.space(2)
                        color: parent.checked ? Color.background : Color.foreground
                        opacity: parent.checked ? 1 : 0.7
                        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                      }
                      MouseArea {
                        id: booleanToggleMouse
                        anchors.fill: parent; activeFocusOnTab: true
                        KeyNavigation.backtab: index === 0 ? widgetList : null
                        onClicked: root.setValue(modelData.key, root.valueFor(modelData) !== true)
                        Keys.onPressed: function(event) {
                          if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return
                          root.setValue(modelData.key, root.valueFor(modelData) !== true)
                          event.accepted = true
                        }
                      }
                    }
                    Text { text: root.valueFor(modelData) === true ? "On" : "Off"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body }
                  }
                  RowLayout {
                    visible: modelData.type === "enum" && root.isOnOffEnum(modelData)
                    spacing: Style.space(8)
                    Rectangle {
                      readonly property bool checked: String(root.valueFor(modelData)).toLowerCase() === "on"
                      width: Style.space(42); height: Style.space(24); radius: height / 2
                      color: checked ? Color.accent : Color.menu.background
                      border.color: enumToggleMouse.activeFocus ? Color.foreground
                        : (checked ? Color.accent : Color.menu.border)
                      border.width: enumToggleMouse.activeFocus ? 2 : 1
                      Rectangle {
                        width: parent.height - Style.space(4)
                        height: width
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.checked ? parent.width - width - Style.space(2) : Style.space(2)
                        color: parent.checked ? Color.background : Color.foreground
                        opacity: parent.checked ? 1 : 0.7
                        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                      }
                      MouseArea {
                        id: enumToggleMouse
                        anchors.fill: parent; activeFocusOnTab: true
                        KeyNavigation.backtab: index === 0 ? widgetList : null
                        onClicked: root.setValue(modelData.key, parent.checked ? "Off" : "On")
                        Keys.onPressed: function(event) {
                          if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return
                          root.setValue(modelData.key, parent.checked ? "Off" : "On")
                          event.accepted = true
                        }
                      }
                    }
                    Text { text: String(root.valueFor(modelData)).toLowerCase() === "on" ? "On" : "Off"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body }
                  }
                  ButtonGroup {
                    property var field: modelData
                    visible: modelData.type === "enum" && !root.isOnOffEnum(modelData)
                    KeyNavigation.backtab: index === 0 ? widgetList : null
                    options: modelData.options || []
                    value: String(root.valueFor(modelData) === undefined ? "" : root.valueFor(modelData))
                    foreground: Color.foreground
                    background: Color.menu.background
                    accent: Color.accent
                    fontFamily: Style.font.family
                    fontSize: Style.font.bodySmall
                    onChanged: function(value) { root.setValue(field.key, value) }
                  }
                  Flow {
                    id: multiselectChoices
                    property var field: modelData
                    Layout.fillWidth: true
                    visible: modelData.type === "multiselect"
                    spacing: Style.space(6)
                    Repeater {
                      model: modelData.options || []
                      delegate: Rectangle {
                        required property var modelData
                        readonly property string value: root.enumOptionValue(modelData)
                        readonly property bool selected: root.multiValues(multiselectChoices.field).indexOf(value) !== -1
                        width: multiLabel.implicitWidth + Style.space(20)
                        height: Style.space(30)
                        radius: Style.cornerRadius / 2
                        color: selected ? Color.menu.selectedBackground : "transparent"
                        border.color: multiChoiceMouse.activeFocus || selected ? Color.accent : Color.menu.border
                        border.width: multiChoiceMouse.activeFocus ? 2 : 1
                        Text {
                          id: multiLabel
                          anchors.centerIn: parent
                          text: typeof modelData === "object" ? (modelData.label || value) : value
                          color: Color.foreground
                          font.family: Style.font.family
                          font.pixelSize: Style.font.bodySmall
                        }
                        MouseArea {
                          id: multiChoiceMouse
                          anchors.fill: parent; activeFocusOnTab: true; cursorShape: Qt.PointingHandCursor
                          KeyNavigation.backtab: index === 0 ? widgetList : null
                          onClicked: root.toggleMultiselect(multiselectChoices.field, parent.value)
                          Keys.onPressed: function(event) {
                            if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return
                            root.toggleMultiselect(multiselectChoices.field, parent.value)
                            event.accepted = true
                          }
                        }
                      }
                    }
                  }
                  Text {
                    visible: ["string", "path", "integer", "number", "boolean", "enum", "multiselect"].indexOf(modelData.type) === -1
                    text: "Unsupported field type: " + modelData.type
                    color: Color.urgent
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                  }
                }
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            Text {
              Layout.fillWidth: true
              text: root.status !== "" ? root.status : (root.dirty ? "Unsaved changes" : "")
              color: Color.foreground
              opacity: 0.65
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
            Rectangle {
              width: resetLabel.implicitWidth + Style.space(24)
              height: Style.space(38)
              radius: Style.cornerRadius / 2
              color: resetMouse.containsMouse ? Color.menu.selectedBackground : "transparent"
              border.color: resetMouse.activeFocus ? Color.accent : Color.menu.border
              border.width: resetMouse.activeFocus ? 2 : 1
              Text { id: resetLabel; anchors.centerIn: parent; text: "Reset"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body }
              MouseArea {
                id: resetMouse
                anchors.fill: parent
                activeFocusOnTab: true
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.resetToDefaults()
                Keys.onPressed: function(event) {
                  if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return
                  root.resetToDefaults()
                  event.accepted = true
                }
              }
            }
            Rectangle {
              width: saveLabel.implicitWidth + Style.space(28)
              height: Style.space(38)
              radius: Style.cornerRadius / 2
              color: root.dirty ? (saveMouse.containsMouse ? Qt.lighter(Color.accent, 1.08) : Color.accent) : Color.menu.border
              Rectangle {
                anchors.fill: parent
                anchors.margins: -Style.space(3)
                radius: parent.radius + Style.space(3)
                color: "transparent"
                border.color: Color.foreground
                border.width: 2
                visible: saveMouse.activeFocus
              }
              Text { id: saveLabel; anchors.centerIn: parent; text: "Save"; color: Color.background; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
              MouseArea {
                id: saveMouse
                anchors.fill: parent
                activeFocusOnTab: true
                hoverEnabled: true
                enabled: root.dirty
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (enabled) root.save()
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Tab) {
                    if (event.modifiers & Qt.ShiftModifier) resetMouse.forceActiveFocus()
                    else shortcutsMouse.forceActiveFocus()
                    event.accepted = true
                  } else if (enabled && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
                    root.save()
                    event.accepted = true
                  }
                }
              }
            }
          }
        }
      }

      Item {
        anchors.fill: parent
        visible: root.shortcutsVisible
        z: 100

        Rectangle {
          anchors.fill: parent
          color: Color.menu.background
          opacity: 0.92
        }

        Rectangle {
          anchors.centerIn: parent
          width: Math.min(Style.space(560), parent.width - Style.space(48))
          height: shortcutsLayout.implicitHeight + Style.space(36)
          radius: Style.cornerRadius
          color: Color.menu.background
          border.color: Color.menu.border
          border.width: 1

          ColumnLayout {
            id: shortcutsLayout
            anchors.fill: parent
            anchors.margins: Style.space(18)
            spacing: Style.space(6)

            RowLayout {
              Layout.fillWidth: true
              Layout.bottomMargin: Style.space(6)
              Text {
                Layout.fillWidth: true
                text: "Keyboard shortcuts"
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.heading
                font.bold: true
              }
              Rectangle {
                width: Style.space(34)
                height: Style.space(34)
                radius: Style.cornerRadius / 2
                color: shortcutsCloseMouse.containsMouse ? Color.menu.selectedBackground : "transparent"
                border.color: shortcutsCloseMouse.activeFocus ? Color.accent : Color.menu.border
                border.width: shortcutsCloseMouse.activeFocus ? 2 : 1
                Text {
                  anchors.centerIn: parent
                  text: "×"
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.heading
                }
                MouseArea {
                  id: shortcutsCloseMouse
                  anchors.fill: parent
                  activeFocusOnTab: true
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.hideShortcuts()
                  Keys.onPressed: function(event) {
                    if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return
                    root.hideShortcuts()
                    event.accepted = true
                  }
                }
              }
            }

            Repeater {
              model: root.shortcutItems
              delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Style.space(14)
                Rectangle {
                  Layout.preferredWidth: Style.space(145)
                  Layout.preferredHeight: Style.space(28)
                  radius: Style.cornerRadius / 2
                  color: Color.menu.selectedBackground
                  Text {
                    anchors.centerIn: parent
                    text: modelData.keys
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                  }
                }
                Text {
                  Layout.fillWidth: true
                  text: modelData.action
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }
              }
            }
          }
        }
      }
    }
  }
}
