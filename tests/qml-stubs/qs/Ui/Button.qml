import QtQuick

Item {
  property string text: ""
  property string iconText: ""
  property real fontSize: 14
  property color foreground: "white"
  property color accent: "steelblue"
  property bool selected: false
  property bool active: false
  property bool bordered: false
  property bool focusable: false
  signal clicked()

  implicitWidth: Math.max(40, text.length * 9 + 24)
  implicitHeight: 34
  activeFocusOnTab: focusable
  Keys.onReturnPressed: if (focusable) clicked()
  Keys.onEnterPressed: if (focusable) clicked()
  Keys.onSpacePressed: if (focusable) clicked()

  MouseArea {
    anchors.fill: parent
    onClicked: parent.clicked()
  }
}
