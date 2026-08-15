import QtQuick

Item {
  property var bar: null
  property string text: ""
  property real fontSize: 14
  property real fixedWidth: 0
  property real fixedHeight: 0
  property string tooltipText: ""
  signal pressed(var button)
}
