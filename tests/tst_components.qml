import QtQuick
import QtTest
import ".." as Plugin

Item {
  width: 640
  height: 480

  Plugin.SettingsController {
    id: controller
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
      controller.draft = ({ enabled: false })
      controller.savedDraft = ({ enabled: false })
      shortcutOverlay.visible = false
      closeSpy.clear()
      waitForPolish(fieldUnderTest)
    }

    function test_boolean_toggle_accepts_mouse_and_keyboard() {
      tryVerify(function() { return fieldUnderTest.booleanToggleControl.width > 0 })
      mouseClick(fieldUnderTest.booleanToggleControl)
      compare(controller.draft.enabled, true)

      fieldUnderTest.booleanToggleControl.forceActiveFocus()
      keyClick(Qt.Key_Space)
      compare(controller.draft.enabled, false)
    }

    function test_on_off_enum_accepts_mouse_and_keyboard() {
      currentField = ({ key: "state", type: "enum", options: ["Off", "On"] })
      controller.selectedDefinition = { schema: [currentField], defaults: { state: "Off" } }
      controller.draft = ({ state: "Off" })
      waitForPolish(fieldUnderTest)
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
      waitForPolish(fieldUnderTest)
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
      waitForPolish(fieldUnderTest)

      fieldUnderTest.enumOptionsControl.changed("fast")
      compare(controller.draft.mode, "fast")
    }

    function test_multiselect_choices_accept_mouse_input() {
      currentField = ({ key: "features", type: "multiselect", options: ["a", "b"] })
      controller.selectedDefinition = { schema: [currentField], defaults: { features: [] } }
      controller.draft = ({ features: ["a"] })
      waitForPolish(fieldUnderTest)
      var choice = findChild(fieldUnderTest, "settings-field-multiselect-b")
      verify(choice !== null)

      mouseClick(choice)
      compare(controller.draft.features, ["a", "b"])
      mouseClick(choice)
      compare(controller.draft.features, ["a"])
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
