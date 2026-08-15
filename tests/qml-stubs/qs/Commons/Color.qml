pragma Singleton
import QtQml

QtObject {
  property color foreground: "white"
  property color background: "black"
  property color accent: "steelblue"
  property color urgent: "red"
  property var menu: ({ background: "black", border: "gray", selectedBackground: "gray" })
}
