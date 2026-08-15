import QtQuick
import QtQuick.Layouts
import qs.Commons

Item {
  id: root

  property var shortcutItems: []
  property alias closeControl: closeMouse
  signal closeRequested()

  objectName: "shortcut-overlay"
  z: 100

  function forceCloseFocus() {
    closeMouse.forceActiveFocus()
  }

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
          Layout.preferredWidth: Style.space(34)
          Layout.preferredHeight: Style.space(34)
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
            objectName: "shortcut-overlay-close"
            anchors.fill: parent
            activeFocusOnTab: true
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeRequested()
            Keys.onPressed: function(event) {
              if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return
              root.closeRequested()
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
