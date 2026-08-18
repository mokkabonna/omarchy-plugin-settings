import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

ColumnLayout {
  id: root

  required property var field
  required property var controller
  property int fieldIndex: -1
  property Item backtabTarget: null
  property alias inputControl: valueInput
  property alias booleanToggleControl: booleanToggle
  property alias enumToggleControl: enumToggle
  property alias enumOptionsControl: enumOptions

  objectName: "settings-field-" + (field.key || "")
  Layout.fillWidth: true
  spacing: Style.space(1)

  Text {
    visible: root.field.type !== "boolean" && !root.controller.isOnOffEnum(root.field)
    text: root.field.label || root.field.key
    color: Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  Text {
    Layout.fillWidth: true
    visible: root.field.description !== undefined
      && root.field.type !== "boolean" && !root.controller.isOnOffEnum(root.field)
    text: root.field.description || ""
    color: Color.foreground
    opacity: 0.65
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  TextField {
    id: valueInput
    objectName: "settings-field-input"
    Layout.fillWidth: true
    visible: ["string", "path", "integer", "number"].indexOf(root.field.type) !== -1
    Layout.preferredHeight: Style.space(36)
    KeyNavigation.backtab: root.fieldIndex === 0 ? root.backtabTarget : null
    text: String(root.controller.valueFor(root.field) === undefined ? "" : root.controller.valueFor(root.field))
    foreground: Color.foreground
    accent: Color.accent
    selectByMouse: true
    onTextEdited: root.controller.setValue(root.field.key, text)
    onEditingFinished: {
      var value = text
      if (root.field.type === "integer" || root.field.type === "number")
        value = root.controller.normalizedNumber(root.field, text)
      if (value === undefined) return
      root.controller.setValue(root.field.key, value)
    }
    Keys.onPressed: function(event) {
      if ((event.key !== Qt.Key_Up && event.key !== Qt.Key_Down)
          || (root.field.type !== "integer" && root.field.type !== "number")) return
      var current = root.controller.normalizedNumber(root.field, text)
      if (current === undefined) current = Number(root.controller.valueFor(root.field)) || 0
      var step = root.field.step !== undefined && Number(root.field.step) > 0
        ? Number(root.field.step) : 1
      var next = root.controller.normalizedNumber(root.field,
        current + (event.key === Qt.Key_Up ? step : -step))
      if (next !== undefined) root.controller.setValue(root.field.key, next)
      event.accepted = true
    }
  }

  Text {
    visible: ["integer", "number"].indexOf(root.field.type) !== -1
      && (root.field.min !== undefined || root.field.max !== undefined || root.field.step !== undefined)
    text: ""
      + (root.field.min !== undefined ? "Min " + root.field.min : "")
      + (root.field.min !== undefined && root.field.max !== undefined ? " · " : "")
      + (root.field.max !== undefined ? "Max " + root.field.max : "")
      + ((root.field.min !== undefined || root.field.max !== undefined) && root.field.step !== undefined ? " · " : "")
      + (root.field.step !== undefined ? "Step " + root.field.step : "")
    color: Color.foreground
    opacity: 0.6
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
  }

  Toggle {
    id: booleanToggle
    objectName: "settings-field-boolean-toggle"
    Layout.fillWidth: true
    visible: root.field.type === "boolean"
    label: root.field.label || root.field.key
    description: root.field.description || ""
    checked: root.controller.valueFor(root.field) === true
    foreground: Color.foreground
    accent: Color.accent
    KeyNavigation.backtab: root.fieldIndex === 0 ? root.backtabTarget : null
    onClicked: root.controller.setValue(root.field.key, !checked)
  }

  Toggle {
    id: enumToggle
    objectName: "settings-field-enum-toggle"
    Layout.fillWidth: true
    visible: root.field.type === "enum" && root.controller.isOnOffEnum(root.field)
    label: root.field.label || root.field.key
    description: root.field.description || ""
    checked: String(root.controller.valueFor(root.field)).toLowerCase() === "on"
    foreground: Color.foreground
    accent: Color.accent
    KeyNavigation.backtab: root.fieldIndex === 0 ? root.backtabTarget : null
    onClicked: root.controller.setValue(root.field.key, checked ? "Off" : "On")
  }

  ButtonGroup {
    id: enumOptions
    property var currentField: root.field
    objectName: "settings-field-enum-options"
    visible: root.field.type === "enum" && !root.controller.isOnOffEnum(root.field)
    KeyNavigation.backtab: root.fieldIndex === 0 ? root.backtabTarget : null
    options: root.field.options || []
    value: String(root.controller.valueFor(root.field) === undefined ? "" : root.controller.valueFor(root.field))
    foreground: Color.foreground
    background: Color.menu.background
    accent: Color.accent
    fontFamily: Style.font.family
    fontSize: Style.font.bodySmall
    onChanged: function(value) { root.controller.setValue(currentField.key, value) }
  }

  Flow {
    id: multiselectChoices
    Layout.fillWidth: true
    visible: root.field.type === "multiselect"
    spacing: Style.space(6)
    Repeater {
      model: root.field.options || []
      delegate: Button {
        required property var modelData
        readonly property string value: root.controller.enumOptionValue(modelData)
        objectName: "settings-field-multiselect-" + value
        text: typeof modelData === "object" ? (modelData.label || value) : value
        foreground: Color.foreground
        accent: Color.accent
        fontSize: Style.font.bodySmall
        selected: root.controller.multiValues(root.field).indexOf(value) !== -1
        bordered: true
        focusable: true
        KeyNavigation.backtab: root.fieldIndex === 0 ? root.backtabTarget : null
        onClicked: root.controller.toggleMultiselect(root.field, value)
      }
    }
  }

  Text {
    visible: ["string", "path", "integer", "number", "boolean", "enum", "multiselect"].indexOf(root.field.type) === -1
    text: "Unsupported field type: " + root.field.type
    color: Color.urgent
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
  }
}
