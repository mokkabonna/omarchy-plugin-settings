import QtQuick

Row {
  property var options: []
  property string value: ""
  property color foreground: "white"
  property color background: "black"
  property color accent: "steelblue"
  property string fontFamily: "sans"
  property real fontSize: 14
  signal changed(string value)
}
