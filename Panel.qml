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
  property alias savedDraft: settingsController.savedDraft
  property alias status: settingsController.status
  property bool shortcutsVisible: false
  property string pendingDiscardAction: ""
  property var pendingSelection: null

  readonly property bool discardConfirmationVisible: discardConfirmation.opened

  readonly property var shortcutItems: [
    { keys: "↑ / ↓", action: "Previous / next item" },
    { keys: "Home / End", action: "First / last item" },
    { keys: "Ctrl+1 … 9", action: "Select item by list position" },
    { keys: "Tab / Shift+Tab", action: "Move keyboard focus" },
    { keys: "Enter / Space", action: "Activate the focused control" },
    { keys: "↑ / ↓ in number", action: "Adjust by the configured step" },
    { keys: "Page Up / Down", action: "Scroll the settings form" },
    { keys: "Ctrl+S", action: "Save pending changes" },
    { keys: "Ctrl+R", action: "Reset to defaults" },
    { keys: "Esc / Ctrl+W", action: "Close" },
    { keys: "?", action: "Show or hide this reference" }
  ]

  readonly property bool dirty: settingsController.dirty
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
    if (dirty) {
      pendingDiscardAction = "select"
      pendingSelection = instance
      discardConfirmation.opened = true
      return
    }
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

  function selectWidgetAt(listIndex) {
    var widgets = configurableEntries()
    if (listIndex < 0 || listIndex >= widgets.length) return
    selectWidget(widgets[listIndex])
    widgetList.positionViewAtIndex(listIndex, ListView.Contain)
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
    if (dirty) {
      pendingDiscardAction = "close"
      pendingSelection = null
      discardConfirmation.opened = true
      return
    }
    closeWithoutConfirmation()
  }

  function closeWithoutConfirmation() {
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "mokkabonna.plugin-settings")
    else close()
  }

  function cancelDiscard() {
    pendingDiscardAction = ""
    pendingSelection = null
    discardConfirmation.opened = false
  }

  function confirmDiscard() {
    var action = pendingDiscardAction
    var selection = pendingSelection
    cancelDiscard()
    if (action === "select" && selection) settingsController.selectWidget(selection)
    else if (action === "close") closeWithoutConfirmation()
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
    var pending = []
    if (form.children)
      for (var first = 0; first < form.children.length; first++) pending.push(form.children[first])
    while (pending.length > 0) {
      var item = pending.shift()
      if (!item || !item.visible || !item.enabled) continue
      if (item.activeFocusOnTab && typeof item.forceActiveFocus === "function") {
        item.forceActiveFocus()
        return true
      }
      if (item.children)
        for (var i = 0; i < item.children.length; i++) pending.push(item.children[i])
    }
    return false
  }

  Timer {
    id: shortcutsFocusTimer
    interval: 0
    repeat: false
    onTriggered: {
      if (root.shortcutsVisible) shortcutOverlay.forceCloseFocus()
      else shortcutsMouse.forceActiveFocus()
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
      anchors.fill: parent
      radius: Style.cornerRadius
      color: Color.menu.background
      border.color: Color.menu.border
      border.width: 1
      focus: true
      Keys.priority: Keys.AfterItem
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          if (root.shortcutsVisible) root.hideShortcuts()
          else root.requestClose()
          event.accepted = true
        } else if (event.text === "?") {
          root.toggleShortcuts()
          event.accepted = true
        } else if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
          root.save()
          event.accepted = true
        } else if (event.key === Qt.Key_R && (event.modifiers & Qt.ControlModifier)) {
          root.resetToDefaults()
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
        } else if (event.modifiers & Qt.ControlModifier) {
          var numberKeys = [Qt.Key_1, Qt.Key_2, Qt.Key_3, Qt.Key_4, Qt.Key_5,
            Qt.Key_6, Qt.Key_7, Qt.Key_8, Qt.Key_9]
          var listIndex = numberKeys.indexOf(event.key)
          if (listIndex < 0) return
          root.selectWidgetAt(listIndex)
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
              delegate: Rectangle {
                required property var modelData
                width: widgetList.width
                height: 54
                radius: Style.cornerRadius / 2
                readonly property bool selectedInstance: root.selectedId === modelData.id
                  && root.selectedKind === modelData.kind && root.selectedSection === modelData.section
                  && root.selectedIndex === modelData.index
                color: selectedInstance ? Color.menu.selectedBackground : "transparent"
                border.color: widgetList.activeFocus && selectedInstance ? Color.accent : "transparent"
                border.width: widgetList.activeFocus && selectedInstance ? 2 : 0
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
                  if (event.modifiers & Qt.ShiftModifier) shortcutsMouse.forceActiveFocus()
                  else root.focusFirstFormControl()
                  event.accepted = true
                  return
                }
                if (event.modifiers !== Qt.NoModifier) return
                if (event.key === Qt.Key_Up) root.selectRelativeWidget(-1)
                else if (event.key === Qt.Key_Down) root.selectRelativeWidget(1)
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
            Rectangle {
              Layout.preferredWidth: shortcutsLabel.implicitWidth + Style.space(24)
              Layout.preferredHeight: Style.space(36)
              radius: Style.cornerRadius / 2
              color: shortcutsMouse.containsMouse ? Color.menu.selectedBackground : "transparent"
              border.color: shortcutsMouse.activeFocus ? Color.accent : Color.menu.border
              border.width: shortcutsMouse.activeFocus ? 2 : 1
              Text {
                id: shortcutsLabel
                anchors.centerIn: parent
                text: "Shortcuts"
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
              MouseArea {
                id: shortcutsMouse
                anchors.fill: parent
                activeFocusOnTab: true
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleShortcuts()
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Tab) {
                    if (event.modifiers & Qt.ShiftModifier) saveMouse.forceActiveFocus()
                    else widgetList.forceActiveFocus()
                    event.accepted = true
                  } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root.toggleShortcuts()
                    event.accepted = true
                  }
                }
              }
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
              text: root.status !== "" ? root.status : (root.dirty ? "Unsaved changes" : "")
              color: Color.foreground
              opacity: 0.65
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
            Rectangle {
              Layout.preferredWidth: resetLabel.implicitWidth + Style.space(24)
              Layout.preferredHeight: Style.space(38)
              radius: Style.cornerRadius / 2
              color: resetMouse.containsMouse ? Color.menu.selectedBackground : "transparent"
              border.color: resetMouse.activeFocus ? Color.accent : Color.menu.border
              border.width: resetMouse.activeFocus ? 2 : 1
              Text { id: resetLabel; anchors.centerIn: parent; text: "Reset"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body }
              MouseArea {
                id: resetMouse
                anchors.fill: parent
                activeFocusOnTab: true
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.resetToDefaults()
                Keys.onPressed: function(event) {
                  if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return
                  root.resetToDefaults()
                  event.accepted = true
                }
              }
            }
            Rectangle {
              Layout.preferredWidth: saveLabel.implicitWidth + Style.space(28)
              Layout.preferredHeight: Style.space(38)
              radius: Style.cornerRadius / 2
              color: root.dirty ? (saveMouse.containsMouse ? Qt.lighter(Color.accent, 1.08) : Color.accent) : Color.menu.border
              Rectangle {
                anchors.fill: parent
                anchors.margins: -Style.space(3)
                radius: parent.radius + Style.space(3)
                color: "transparent"
                border.color: Color.foreground
                border.width: 2
                visible: saveMouse.activeFocus
              }
              Text { id: saveLabel; anchors.centerIn: parent; text: "Save"; color: Color.background; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
              MouseArea {
                id: saveMouse
                anchors.fill: parent
                activeFocusOnTab: true
                hoverEnabled: true
                enabled: root.dirty
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (enabled) root.save()
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Tab) {
                    if (event.modifiers & Qt.ShiftModifier) resetMouse.forceActiveFocus()
                    else shortcutsMouse.forceActiveFocus()
                    event.accepted = true
                  } else if (enabled && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
                    root.save()
                    event.accepted = true
                  }
                }
              }
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
        id: discardConfirmation
        anchors.fill: parent
        message: pendingDiscardAction === "select"
          ? "Discard unsaved changes and select another item?"
          : "Discard unsaved changes and close Plugin Settings?"
        cancelText: "Keep editing"
        confirmText: "Discard"
        onCanceled: root.cancelDiscard()
        onConfirmed: root.confirmDiscard()
      }
    }
  }
}
