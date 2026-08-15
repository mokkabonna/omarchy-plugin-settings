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
  property alias booleanToggleControl: booleanToggleMouse
  property alias enumToggleControl: enumToggleMouse
  property alias enumOptionsControl: enumOptions

  objectName: "settings-field-" + (field.key || "")
  Layout.fillWidth: true
  spacing: Style.space(1)

  Text {
    text: root.field.label || root.field.key
    color: Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  Text {
    Layout.fillWidth: true
    visible: root.field.description !== undefined
    text: root.field.description || ""
    color: Color.foreground
    opacity: 0.65
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  Rectangle {
    Layout.fillWidth: true
    visible: ["string", "path", "integer", "number"].indexOf(root.field.type) !== -1
    Layout.preferredHeight: Style.space(36)
    color: Color.menu.background
    border.color: Color.menu.border
    border.width: 1
    radius: Style.cornerRadius / 2

    TextInput {
      id: valueInput
      objectName: "settings-field-input"
      activeFocusOnTab: true
      KeyNavigation.backtab: root.fieldIndex === 0 ? root.backtabTarget : null
      anchors.fill: parent
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      anchors.topMargin: Style.space(6)
      anchors.bottomMargin: Style.space(6)
      text: String(root.controller.valueFor(root.field) === undefined ? "" : root.controller.valueFor(root.field))
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      selectByMouse: true
      verticalAlignment: TextInput.AlignVCenter
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

  RowLayout {
    visible: root.field.type === "boolean"
    spacing: Style.space(8)
    Rectangle {
      readonly property bool checked: root.controller.valueFor(root.field) === true
      Layout.preferredWidth: Style.space(42)
      Layout.preferredHeight: Style.space(24)
      radius: height / 2
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
        objectName: "settings-field-boolean-toggle"
        anchors.fill: parent
        activeFocusOnTab: true
        KeyNavigation.backtab: root.fieldIndex === 0 ? root.backtabTarget : null
        onClicked: root.controller.setValue(root.field.key, root.controller.valueFor(root.field) !== true)
        Keys.onPressed: function(event) {
          if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return
          root.controller.setValue(root.field.key, root.controller.valueFor(root.field) !== true)
          event.accepted = true
        }
      }
    }
    Text {
      text: root.controller.valueFor(root.field) === true ? "On" : "Off"
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
  }

  RowLayout {
    visible: root.field.type === "enum" && root.controller.isOnOffEnum(root.field)
    spacing: Style.space(8)
    Rectangle {
      readonly property bool checked: String(root.controller.valueFor(root.field)).toLowerCase() === "on"
      Layout.preferredWidth: Style.space(42)
      Layout.preferredHeight: Style.space(24)
      radius: height / 2
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
        objectName: "settings-field-enum-toggle"
        anchors.fill: parent
        activeFocusOnTab: true
        KeyNavigation.backtab: root.fieldIndex === 0 ? root.backtabTarget : null
        onClicked: root.controller.setValue(root.field.key, parent.checked ? "Off" : "On")
        Keys.onPressed: function(event) {
          if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return
          root.controller.setValue(root.field.key, parent.checked ? "Off" : "On")
          event.accepted = true
        }
      }
    }
    Text {
      text: String(root.controller.valueFor(root.field)).toLowerCase() === "on" ? "On" : "Off"
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
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
      delegate: Rectangle {
        required property var modelData
        readonly property string value: root.controller.enumOptionValue(modelData)
        readonly property bool selected: root.controller.multiValues(root.field).indexOf(value) !== -1
        width: multiLabel.implicitWidth + Style.space(20)
        height: Style.space(30)
        radius: Style.cornerRadius / 2
        color: selected ? Color.menu.selectedBackground : "transparent"
        border.color: multiChoiceMouse.activeFocus || selected ? Color.accent : Color.menu.border
        border.width: multiChoiceMouse.activeFocus ? 2 : 1
        Text {
          id: multiLabel
          anchors.centerIn: parent
          text: typeof modelData === "object" ? (modelData.label || parent.value) : parent.value
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
        MouseArea {
          id: multiChoiceMouse
          objectName: "settings-field-multiselect-" + parent.value
          anchors.fill: parent
          activeFocusOnTab: true
          cursorShape: Qt.PointingHandCursor
          KeyNavigation.backtab: root.fieldIndex === 0 ? root.backtabTarget : null
          onClicked: root.controller.toggleMultiselect(root.field, parent.value)
          Keys.onPressed: function(event) {
            if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return
            root.controller.toggleMultiselect(root.field, parent.value)
            event.accepted = true
          }
        }
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
