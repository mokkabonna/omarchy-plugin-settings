import QtQuick

Item {
  property bool opened: false
  property string message: ""
  property string cancelText: "Cancel"
  property string confirmText: "Confirm"
  signal canceled()
  signal confirmed()
  visible: opened
}
