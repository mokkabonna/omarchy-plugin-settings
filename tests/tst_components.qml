import QtQuick
import QtTest
import ".." as Plugin

Item {
  width: 640
  height: 480

  QtObject {
    id: shellFixture
    property var shellConfig: ({ bar: {} })
    function mutateShellConfig(callback) { callback(shellConfig) }
  }

  Plugin.SettingsController {
    id: controller
    shell: shellFixture
  }

  Plugin.SettingsField {
    id: fieldUnderTest
    width: 400
    field: testCase.currentField
    controller: controller
  }

  Plugin.ShortcutOverlay {
    id: shortcutOverlay
    anchors.fill: parent
    visible: false
    shortcutItems: [{ keys: "Esc", action: "Close" }]
  }

  SignalSpy {
    id: closeSpy
    target: shortcutOverlay
    signalName: "closeRequested"
  }

  TestCase {
    id: testCase
    name: "SettingsComponents"
    when: windowShown

    property var currentField: ({ key: "enabled", type: "boolean", label: "Enabled" })

    function init() {
      currentField = ({ key: "enabled", type: "boolean", label: "Enabled" })
      controller.selectedDefinition = { schema: [currentField], defaults: { enabled: false } }
      controller.selectedId = "omarchy.shell.bar"
      controller.selectedKind = "shell"
      controller.selectedSection = "bar"
      controller.draft = ({ enabled: false })
      shellFixture.shellConfig = ({ bar: {} })
      shortcutOverlay.visible = false
      closeSpy.clear()
      waitForItemPolished(fieldUnderTest)
    }

    function test_boolean_toggle_accepts_mouse_and_keyboard() {
      tryVerify(function() { return fieldUnderTest.booleanToggleControl.width > 0 })
      mouseClick(fieldUnderTest.booleanToggleControl)
      compare(controller.draft.enabled, true)
      compare(shellFixture.shellConfig.bar.enabled, true)

      fieldUnderTest.booleanToggleControl.forceActiveFocus()
      keyClick(Qt.Key_Space)
      compare(controller.draft.enabled, false)
      compare(shellFixture.shellConfig.bar.enabled, false)
    }

    function test_on_off_enum_accepts_mouse_and_keyboard() {
      currentField = ({ key: "state", type: "enum", options: ["Off", "On"] })
      controller.selectedDefinition = { schema: [currentField], defaults: { state: "Off" } }
      controller.draft = ({ state: "Off" })
      waitForItemPolished(fieldUnderTest)
      tryVerify(function() { return fieldUnderTest.enumToggleControl.width > 0 })

      mouseClick(fieldUnderTest.enumToggleControl)
      compare(controller.draft.state, "On")
      fieldUnderTest.enumToggleControl.forceActiveFocus()
      keyClick(Qt.Key_Return)
      compare(controller.draft.state, "Off")
    }

    function test_numeric_arrow_keys_use_step_and_constraints() {
      currentField = ({ key: "count", type: "integer", min: 0, max: 60, step: 30 })
      controller.selectedDefinition = { schema: [currentField], defaults: { count: 0 } }
      controller.draft = ({ count: 30 })
      waitForItemPolished(fieldUnderTest)
      tryVerify(function() { return fieldUnderTest.inputControl.width > 0 })

      fieldUnderTest.inputControl.forceActiveFocus()
      keyClick(Qt.Key_Up)
      compare(controller.draft.count, 60)
      keyClick(Qt.Key_Up)
      compare(controller.draft.count, 60)
      keyClick(Qt.Key_Down)
      compare(controller.draft.count, 30)
    }

    function test_enum_options_update_the_draft() {
      currentField = ({ key: "mode", type: "enum", options: ["safe", "fast"] })
      controller.selectedDefinition = { schema: [currentField], defaults: { mode: "safe" } }
      controller.draft = ({ mode: "safe" })
      waitForItemPolished(fieldUnderTest)

      fieldUnderTest.enumOptionsControl.changed("fast")
      compare(controller.draft.mode, "fast")
    }

    function test_multiselect_choices_accept_mouse_input() {
      currentField = ({ key: "features", type: "multiselect", options: ["a", "b"] })
      controller.selectedDefinition = { schema: [currentField], defaults: { features: [] } }
      controller.draft = ({ features: ["a"] })
      waitForItemPolished(fieldUnderTest)
      var choice = findChild(fieldUnderTest, "settings-field-multiselect-b")
      verify(choice !== null)

      mouseClick(choice)
      compare(controller.draft.features, ["a", "b"])
      mouseClick(choice)
      compare(controller.draft.features, ["a"])
    }

    function test_multiselect_is_first_focus_target_and_accepts_horizontal_navigation() {
      currentField = ({ key: "features", type: "multiselect", options: ["a", "b"] })
      controller.selectedDefinition = { schema: [currentField], defaults: { features: [] } }
      controller.draft = ({ features: [] })
      waitForItemPolished(fieldUnderTest)
      var firstChoice = findChild(fieldUnderTest, "settings-field-multiselect-a")
      var secondChoice = findChild(fieldUnderTest, "settings-field-multiselect-b")
      verify(firstChoice !== null)
      verify(secondChoice !== null)

      verify(fieldUnderTest.focusFirstControl())
      verify(firstChoice.activeFocus)
      keyClick(Qt.Key_Right)
      verify(secondChoice.activeFocus)
      keyClick(Qt.Key_Left)
      verify(firstChoice.activeFocus)
      keyClick(Qt.Key_L)
      verify(secondChoice.activeFocus)
      keyClick(Qt.Key_H)
      verify(firstChoice.activeFocus)
    }

    function test_shortcut_overlay_close_accepts_mouse_and_keyboard() {
      shortcutOverlay.visible = true
      tryVerify(function() { return shortcutOverlay.closeControl.width > 0 })
      mouseClick(shortcutOverlay.closeControl)
      compare(closeSpy.count, 1)

      shortcutOverlay.closeControl.forceActiveFocus()
      keyClick(Qt.Key_Space)
      compare(closeSpy.count, 2)
    }
  }
}
