import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "mokkabonna.plugin-settings"
  implicitWidth: barSize
  implicitHeight: barSize

  WidgetButton {
    anchors.fill: parent
    bar: root.bar
    text: ""
    fontSize: Style.font.body
    fixedWidth: root.barSize
    fixedHeight: root.barSize
    tooltipText: "Plugin Settings"
    onPressed: function(button) {
      if (button === Qt.LeftButton && root.bar)
        root.bar.run("omarchy-shell shell toggle mokkabonna.plugin-settings")
    }
  }
}
