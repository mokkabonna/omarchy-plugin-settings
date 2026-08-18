import QtQuick

Item {
  property string label: ""
  property string description: ""
  property bool checked: false
  property color foreground: "white"
  property color accent: "steelblue"
  signal clicked()

  implicitWidth: 240
  implicitHeight: 54
  activeFocusOnTab: true
  Keys.onReturnPressed: clicked()
  Keys.onEnterPressed: clicked()
  Keys.onSpacePressed: clicked()

  MouseArea {
    anchors.fill: parent
    onClicked: parent.clicked()
  }
}
