# Plugin Settings

Schema-driven settings editor for Omarchy bar widgets. It adds a gear button to
the bar that opens a floating, Hyprland-managed window where each widget
instance can be configured independently.

## Features

- Lists every enabled bar-widget instance that declares a manifest schema.
- Writes changes only to the selected instance's entry in
  `~/.config/omarchy/shell.json`.
- Renders `string`, `path`, `integer`, `number`, `boolean`, `enum`, and
  `multiselect` fields.
- Enforces numeric `min`, `max`, and `step` constraints.
- Uses switches for booleans and two-option `Off` / `On` enums.
- Provides Reset-to-defaults, dirty-state feedback, and a Save action.

## Interactions

- Bar gear: toggle the settings window.
- `Super+W` or the window close button: close the window.
- `Escape`: close the window.
- `Ctrl+S`: save pending changes.

The window opens centered and floating at 900×650, with a 680×480 minimum.

## Install

Once this repository is hosted, install it with Omarchy's plugin manager:

```bash
omarchy plugin add <repository-url>
omarchy plugin enable local.plugin-settings --section right
```

Omarchy plugins run as unsandboxed code inside the shell. Review a plugin's
source before enabling it.

## Development

For a local checkout, link it into the user plugin directory, rescan, and
enable it:

```bash
ln -s "$(pwd)" ~/.config/omarchy/plugins/local.plugin-settings
omarchy-shell shell rescanPlugins
omarchy plugin enable local.plugin-settings --section right
```

Omarchy automatically reloads changes made directly under its plugin
directory. Its watcher does not follow this development symlink, so reload
QML changes with `omarchy restart shell`; use `omarchy-shell shell
rescanPlugins` after changing the manifest.

## Scope

The manifest form format is deliberately flat. Nested values and plugin-owned
`settingsForm` UIs require a separate convention and are not rendered by this
plugin.
