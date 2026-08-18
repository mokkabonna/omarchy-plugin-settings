import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

Item {
  id: root

  property alias shell: settingsController.shell
  property var manifest: null
  property alias barWidgetRegistry: settingsController.barWidgetRegistry
  property alias pluginRegistry: settingsController.pluginRegistry
  property bool opened: false
  property bool closingFromHost: false
  property alias selectedId: settingsController.selectedId
  property alias selectedKind: settingsController.selectedKind
  property alias selectedSection: settingsController.selectedSection
  property alias selectedIndex: settingsController.selectedIndex
  property alias selectedDefinition: settingsController.selectedDefinition
  property alias draft: settingsController.draft
  property alias status: settingsController.status
  property bool shortcutsVisible: false
  property Item focusBeforeReset: null

  readonly property bool resetConfirmationVisible: resetConfirmation.opened

  readonly property var shortcutItems: [
    { keys: "↑ / k · ↓ / j", action: "Previous / next item" },
    { keys: "Home / End", action: "First / last item" },
    { keys: "Page Up / Down", action: "Scroll the settings form" },
    { keys: "Esc / Ctrl+W", action: "Close" },
    { keys: "?", action: "Show or hide this reference" }
  ]

  readonly property var selectedMetadata: settingsController.selectedMetadata
  readonly property var schema: settingsController.schema

  SettingsController {
    id: settingsController
  }

  function valueFor(field) {
    return settingsController.valueFor(field)
  }

  function widgetInstancesWithSchemas() {
    return settingsController.widgetInstancesWithSchemas()
  }

  function shellDefinition(section) {
    return settingsController.shellDefinition(section)
  }

  function shellSettingsEntries() {
    return settingsController.shellSettingsEntries()
  }

  function pluginInstancesWithSchemas() {
    return settingsController.pluginInstancesWithSchemas()
  }

  function configurableEntries() {
    return settingsController.configurableEntries()
  }

  function selectWidget(instance) {
    if (!instance) return
    var alreadySelected = instance.id === selectedId && instance.kind === selectedKind
      && instance.section === selectedSection && instance.index === selectedIndex
    if (alreadySelected) return
    settingsController.selectWidget(instance)
  }

  function selectRelativeWidget(offset) {
    var widgets = configurableEntries()
    if (widgets.length === 0) return
    var current = -1
    for (var i = 0; i < widgets.length; i++) {
      if (widgets[i].id === selectedId && widgets[i].kind === selectedKind && widgets[i].section === selectedSection
          && widgets[i].index === selectedIndex) {
        current = i
        break
      }
    }
    var next = current < 0 ? 0 : Math.max(0, Math.min(widgets.length - 1, current + offset))
    selectWidget(widgets[next])
    widgetList.positionViewAtIndex(next, ListView.Contain)
  }

  function setValue(key, value) {
    settingsController.setValue(key, value)
  }

  function enumOptionValue(option) {
    return settingsController.enumOptionValue(option)
  }

  function isOnOffEnum(field) {
    return settingsController.isOnOffEnum(field)
  }

  function multiValues(field) {
    return settingsController.multiValues(field)
  }

  function toggleMultiselect(field, value) {
    settingsController.toggleMultiselect(field, value)
  }

  function normalizedNumber(field, value) {
    return settingsController.normalizedNumber(field, value)
  }

  function resetToDefaults() {
    settingsController.resetToDefaults()
    settingsController.save()
  }

  function save() {
    settingsController.save()
  }

  function open(payloadJson) {
    opened = true
    shortcutsVisible = false
    window.visible = true
    var entries = configurableEntries()
    if ((!selectedId || !selectedKind) && entries.length > 0) selectWidget(entries[0])
  }

  function close() {
    closingFromHost = true
    shortcutsVisible = false
    opened = false
    window.visible = false
    closingFromHost = false
  }

  function requestClose() {
    windowContent.forceActiveFocus()
    Qt.callLater(root.closeWithoutConfirmation)
  }

  function closeWithoutConfirmation() {
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "mokkabonna.plugin-settings")
    else close()
  }

  function requestReset() {
    focusBeforeReset = window.activeFocusItem
    resetConfirmation.selectedIndex = 1
    resetConfirmation.opened = true
    windowContent.forceActiveFocus()
  }

  function cancelReset() {
    var previousFocus = focusBeforeReset
    focusBeforeReset = null
    resetConfirmation.opened = false
    if (previousFocus && typeof previousFocus.forceActiveFocus === "function")
      previousFocus.forceActiveFocus()
  }

  function confirmReset() {
    cancelReset()
    resetToDefaults()
  }

  function handleResetKey(event) {
    if (!resetConfirmation.opened) return false
    return resetConfirmation.handleKey(event)
  }

  function toggleShortcuts() {
    shortcutsVisible = !shortcutsVisible
    shortcutsFocusTimer.restart()
  }

  function hideShortcuts() {
    if (!shortcutsVisible) return
    shortcutsVisible = false
    shortcutsFocusTimer.restart()
  }

  function focusFirstFormControl() {
    for (var i = 0; i < fieldsRepeater.count; i++) {
      var fieldItem = fieldsRepeater.itemAt(i)
      if (fieldItem && fieldItem.focusFirstControl()) return true
    }
    return false
  }

  Timer {
    id: shortcutsFocusTimer
    interval: 0
    repeat: false
    onTriggered: {
      if (root.shortcutsVisible) shortcutOverlay.forceCloseFocus()
      else helpButton.forceActiveFocus()
    }
  }

  FloatingWindow {
    id: window
    title: "Plugin Settings"
    visible: root.opened
    color: Color.menu.background
    implicitWidth: 900
    implicitHeight: 650
    minimumSize: Qt.size(680, 480)
    onVisibleChanged: {
      if (!visible && !root.closingFromHost && root.shell && typeof root.shell.hide === "function")
        root.shell.hide((root.manifest && root.manifest.id) || "mokkabonna.plugin-settings")
    }

    Rectangle {
      id: windowContent
      anchors.fill: parent
      radius: Style.cornerRadius
      color: Color.menu.background
      border.color: Color.menu.border
      border.width: 1
      focus: true
      Keys.priority: Keys.AfterItem
      Keys.onPressed: function(event) {
        if (root.handleResetKey(event)) {
          event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
          if (root.shortcutsVisible) root.hideShortcuts()
          else root.requestClose()
          event.accepted = true
        } else if (event.text === "?") {
          root.toggleShortcuts()
          event.accepted = true
        } else if (event.key === Qt.Key_W && (event.modifiers & Qt.ControlModifier)) {
          root.requestClose()
          event.accepted = true
        } else if (event.key === Qt.Key_PageUp && event.modifiers === Qt.NoModifier) {
          formFlickable.contentY = Math.max(0, formFlickable.contentY - formFlickable.height * 0.8)
          event.accepted = true
        } else if (event.key === Qt.Key_PageDown && event.modifiers === Qt.NoModifier) {
          formFlickable.contentY = Math.min(formFlickable.contentHeight - formFlickable.height,
            formFlickable.contentY + formFlickable.height * 0.8)
          event.accepted = true
        }
      }

      RowLayout {
        id: mainContent
        anchors.fill: parent
        anchors.margins: Style.space(18)
        spacing: Style.space(14)
        enabled: !root.shortcutsVisible

        Rectangle {
          Layout.preferredWidth: 245
          Layout.fillHeight: true
          color: Color.menu.background

          ColumnLayout {
            anchors.fill: parent
            spacing: Style.space(1)

            Text {
              Layout.fillWidth: true
              text: "Plugin Settings"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.heading
              font.bold: true
              wrapMode: Text.WordWrap
            }
            Text {
              Layout.fillWidth: true
              text: "Omarchy shell and schema-enabled plugins"
              color: Color.foreground
              opacity: 0.65
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Color.menu.border }

            ListView {
              id: widgetList
              activeFocusOnTab: true
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              model: root.configurableEntries()
              delegate: CursorSurface {
                required property var modelData
                width: widgetList.width
                height: 54
                radius: Style.cornerRadius / 2
                readonly property bool selectedInstance: root.selectedId === modelData.id
                  && root.selectedKind === modelData.kind && root.selectedSection === modelData.section
                  && root.selectedIndex === modelData.index
                current: selectedInstance
                hasCursor: widgetList.activeFocus && selectedInstance
                foreground: Color.foreground
                accent: Color.accent
                Column {
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  spacing: Style.space(2)
                  Text {
                    width: parent.width
                    text: modelData.metadata.displayName || modelData.id
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                  }
                  Text {
                    width: parent.width
                    text: modelData.locationLabel
                    color: Color.foreground
                    opacity: 0.6
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideRight
                  }
                }
                MouseArea {
                  anchors.fill: parent
                  onClicked: {
                    widgetList.forceActiveFocus()
                    root.selectWidget(modelData)
                  }
                }
              }
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Tab) {
                  if (event.modifiers & Qt.ShiftModifier) helpButton.forceActiveFocus()
                  else root.focusFirstFormControl()
                  event.accepted = true
                  return
                }
                if (event.modifiers !== Qt.NoModifier) return
                if (event.key === Qt.Key_Up || event.text === "k") root.selectRelativeWidget(-1)
                else if (event.key === Qt.Key_Down || event.text === "j") root.selectRelativeWidget(1)
                else if (event.key === Qt.Key_Home) root.selectRelativeWidget(-9999)
                else if (event.key === Qt.Key_End) root.selectRelativeWidget(9999)
                else return
                event.accepted = true
              }
            }
          }
        }

        Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Color.menu.border }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(2)

          RowLayout {
            Layout.fillWidth: true
            Text {
              Layout.fillWidth: true
              text: root.selectedMetadata && root.selectedMetadata.displayName
                ? root.selectedMetadata.displayName : "No configurable item selected"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.heading
              font.bold: true
              elide: Text.ElideRight
            }
            Button {
              id: helpButton
              Layout.preferredWidth: Style.space(36)
              Layout.preferredHeight: Style.space(36)
              text: "?"
              tooltipText: "Keyboard shortcuts"
              fontSize: Style.font.body
              foreground: Color.foreground
              accent: Color.accent
              bordered: true
              focusable: true
              onClicked: root.toggleShortcuts()
              KeyNavigation.backtab: resetButton
              KeyNavigation.tab: widgetList
            }
          }
          Text {
            Layout.fillWidth: true
            visible: !!(root.selectedMetadata && root.selectedMetadata.description)
            text: root.selectedMetadata && root.selectedMetadata.description
              ? root.selectedMetadata.description : ""
            color: Color.foreground
            opacity: 0.65
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          Flickable {
            id: formFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Style.space(10)
            contentWidth: width
            contentHeight: form.implicitHeight
            clip: true

            ColumnLayout {
              id: form
              width: parent.width
              spacing: Style.space(14)
              Repeater {
                id: fieldsRepeater
                model: root.schema
                delegate: SettingsField {
                  required property var modelData
                  required property int index
                  field: modelData
                  fieldIndex: index
                  controller: settingsController
                  backtabTarget: widgetList
                }
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            Text {
              Layout.fillWidth: true
              text: root.status
              color: Color.foreground
              opacity: 0.65
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
            Button {
              id: resetButton
              Layout.preferredHeight: Style.space(38)
              text: "Reset"
              foreground: Color.foreground
              accent: Color.accent
              bordered: true
              focusable: true
              onClicked: root.requestReset()
              KeyNavigation.tab: helpButton
            }
          }
        }
      }

      ShortcutOverlay {
        id: shortcutOverlay
        anchors.fill: parent
        visible: root.shortcutsVisible
        shortcutItems: root.shortcutItems
        onCloseRequested: root.hideShortcuts()
      }

      ConfirmDialog {
        id: resetConfirmation
        anchors.fill: parent
        message: "Reset " + (root.selectedMetadata && root.selectedMetadata.displayName
          ? root.selectedMetadata.displayName : "this item") + " to its defaults?"
        cancelText: "Cancel"
        confirmText: "Reset"
        onCanceled: root.cancelReset()
        onConfirmed: root.confirmReset()
      }
    }
  }
}
