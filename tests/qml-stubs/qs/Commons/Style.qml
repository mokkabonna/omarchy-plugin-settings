pragma Singleton
import QtQml

QtObject {
  property var font: ({ family: "sans", heading: 16, body: 14, bodySmall: 12 })
  property real cornerRadius: 4
  property var spacing: ({ md: 8 })
  function space(value) { return Number(value) * 4 }
}
