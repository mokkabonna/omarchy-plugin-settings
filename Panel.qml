import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var barWidgetRegistry: null
  property bool opened: false
  property bool closingFromHost: false
  property string selectedId: ""
  property string selectedSection: ""
  property int selectedIndex: -1
  property var draft: ({})
  property var savedDraft: ({})
  property string status: ""

  readonly property bool dirty: JSON.stringify(draft) !== JSON.stringify(savedDraft)

  readonly property var selectedMetadata: barWidgetRegistry && selectedId
    ? barWidgetRegistry.metadataFor(selectedId) : null
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
          result.push({ id: entry.id, section: sections[s], index: i, entry: entry, metadata: metadata })
      }
    }
    return result
  }

  function selectWidget(instance) {
    selectedId = instance.id
    selectedSection = instance.section
    selectedIndex = instance.index
    status = ""
    var next = ({})
    for (var key in instance.entry) if (key !== "id") next[key] = instance.entry[key]
    draft = next
    savedDraft = JSON.parse(JSON.stringify(next))
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
    status = "Reset to manifest defaults — save to apply"
  }

  function save() {
    if (!shell || !selectedId || selectedIndex < 0 || typeof shell.mutateShellConfig !== "function") return
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
    shell.mutateShellConfig(function(config) {
      var layout = config.bar && config.bar.layout ? config.bar.layout : {}
      var entries = layout[selectedSection] || []
      if (!entries[selectedIndex] || entries[selectedIndex].id !== selectedId) return
      var next = { id: selectedId }
      for (var name in values) next[name] = values[name]
      entries[selectedIndex] = next
      saved = true
    })
    if (!saved) {
      status = "This widget moved; select it again before saving"
      return
    }
    draft = values
    savedDraft = JSON.parse(JSON.stringify(values))
    status = "Saved to shell.json"
  }

  function open(payloadJson) {
    opened = true
    window.visible = true
    var widgets = widgetInstancesWithSchemas()
    if ((!selectedId || selectedIndex < 0) && widgets.length > 0) selectWidget(widgets[0])
  }

  function close() {
    closingFromHost = true
    opened = false
    window.visible = false
    closingFromHost = false
  }

  function requestClose() {
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "mokkabonna.plugin-settings")
    else close()
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
          root.requestClose()
          event.accepted = true
        } else if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
          root.save()
          event.accepted = true
        }
      }

      RowLayout {
        anchors.fill: parent
        anchors.margins: Style.space(18)
        spacing: Style.space(14)

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
              text: "Schema-enabled bar widgets"
              color: Color.foreground
              opacity: 0.65
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Color.menu.border }

            ListView {
              id: widgetList
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              model: root.widgetInstancesWithSchemas()
              delegate: Rectangle {
                required property var modelData
                width: widgetList.width
                height: 54
                radius: Style.cornerRadius / 2
                color: root.selectedId === modelData.id && root.selectedSection === modelData.section
                  && root.selectedIndex === modelData.index ? Color.menu.selectedBackground : "transparent"
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
                    text: modelData.section + " bar · instance " + (modelData.index + 1)
                    color: Color.foreground
                    opacity: 0.6
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideRight
                  }
                }
                MouseArea { anchors.fill: parent; onClicked: root.selectWidget(modelData) }
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
              text: root.selectedMetadata ? root.selectedMetadata.displayName : "No configurable widget selected"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.heading
              font.bold: true
              elide: Text.ElideRight
            }
            Rectangle {
              width: Style.space(36)
              height: Style.space(36)
              radius: Style.cornerRadius / 2
              color: closeMouse.containsMouse ? Color.menu.selectedBackground : "transparent"
              border.color: Color.menu.border
              border.width: 1
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
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.requestClose()
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
                      border.color: checked ? Color.accent : Color.menu.border
                      border.width: 1
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
                      MouseArea { anchors.fill: parent; onClicked: root.setValue(modelData.key, root.valueFor(modelData) !== true) }
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
                      border.color: checked ? Color.accent : Color.menu.border
                      border.width: 1
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
                        anchors.fill: parent
                        onClicked: root.setValue(modelData.key, parent.checked ? "Off" : "On")
                      }
                    }
                    Text { text: String(root.valueFor(modelData)).toLowerCase() === "on" ? "On" : "Off"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body }
                  }
                  RowLayout {
                    id: enumChoices
                    property var field: modelData
                    visible: modelData.type === "enum" && !root.isOnOffEnum(modelData)
                    Repeater {
                      model: modelData.options || []
                      delegate: Rectangle {
                        required property var modelData
                        readonly property string value: typeof modelData === "object" ? modelData.value : modelData
                        width: choiceLabel.implicitWidth + Style.space(2); height: choiceLabel.implicitHeight + Style.space(1)
                        radius: Style.cornerRadius / 2
                        color: root.valueFor(enumChoices.field) === value ? Color.menu.selectedBackground : "transparent"
                        border.color: Color.menu.border; border.width: 1
                        Text { id: choiceLabel; anchors.centerIn: parent; text: typeof modelData === "object" ? (modelData.label || value) : value; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                        MouseArea { anchors.fill: parent; onClicked: root.setValue(enumChoices.field.key, parent.value) }
                      }
                    }
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
                        border.color: selected ? Color.accent : Color.menu.border
                        border.width: 1
                        Text {
                          id: multiLabel
                          anchors.centerIn: parent
                          text: typeof modelData === "object" ? (modelData.label || value) : value
                          color: Color.foreground
                          font.family: Style.font.family
                          font.pixelSize: Style.font.bodySmall
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleMultiselect(multiselectChoices.field, parent.value) }
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
              border.color: Color.menu.border
              border.width: 1
              Text { id: resetLabel; anchors.centerIn: parent; text: "Reset"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body }
              MouseArea {
                id: resetMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.resetToDefaults()
              }
            }
            Rectangle {
              width: saveLabel.implicitWidth + Style.space(28)
              height: Style.space(38)
              radius: Style.cornerRadius / 2
              color: root.dirty ? (saveMouse.containsMouse ? Qt.lighter(Color.accent, 1.08) : Color.accent) : Color.menu.border
              Text { id: saveLabel; anchors.centerIn: parent; text: "Save"; color: Color.background; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
              MouseArea {
                id: saveMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.dirty
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (enabled) root.save()
              }
            }
          }
        }
      }
    }
  }
}
