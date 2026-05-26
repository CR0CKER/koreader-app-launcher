# koreader-app-launcher

A KOReader plugin that adds shortcuts for launching other Android apps from
inside KOReader. Useful on Android e-readers (Boox, Onyx, etc.) where you
want to jump straight from a book to a notes app, browser, dictionary, or
email client.

## How it works

KOReader's Android bridge (`android-luajit-launcher`) does not expose a
generic `startActivity()` to Lua. The only primitive available to a pure
Lua plugin is `Device:openLink(uri)`, which fires an `ACTION_VIEW` intent
on `Uri.parse(uri)`. This plugin builds on that: every shortcut is just a
URI, and Android dispatches it to whichever installed app has registered
an intent filter for the scheme.

This means the plugin can launch any app that exposes a URL scheme —
which is most apps a reader would want to jump to (browsers, `mailto:`,
`obsidian://`, `joplin://`, `kiwix://`, `aard2://`, `anki://`, `calibre://`,
many Boox built-ins, etc.). Apps that register no scheme cannot be
launched without a custom KOReader build that patches the JNI bridge.

## Install

Copy the `applauncher.koplugin/` folder into your KOReader install:

```
<koreader-data>/plugins/applauncher.koplugin/
```

On Android the data dir is typically
`/sdcard/koreader/plugins/applauncher.koplugin/`. Restart KOReader. The
plugin shows up under **Tools → App Launcher**.

If [SimpleUI](https://github.com/doctorhetfield-cmd/simpleui.koplugin) is
also installed, each shortcut is auto-registered as a SimpleUI
QuickAction (homescreen tile) — no manual wiring needed.

## Usage

- **Tools → App Launcher** lists every shortcut. Tap to launch.
- **Edit shortcuts…** opens the editor: add, edit, reorder, delete.
- Each shortcut has a **Label** (shown in the menu) and a **URI**
  (whatever scheme the target app handles).
- The editor's **Test** button immediately launches the URI so you can
  verify it before saving.

If no installed app handles a URI, KOReader shows a toast
("No app handles `scheme:`") instead of crashing.

## Storage

Shortcuts live in `<koreader-data>/settings/applauncher_shortcuts.lua` as
a list of `{ id, label, uri, icon }` records. Safe to edit by hand or
sync between devices.

## Limitations

- Android only. On other platforms the plugin loads but every launch
  attempt shows a toast.
- URI-scheme dispatch only. No package-name launch, no arbitrary intents.
- No way to enumerate installed apps from Lua, so you have to know the
  scheme of each target app. `adb shell dumpsys package <pkg>` is the
  easiest way to discover one.
