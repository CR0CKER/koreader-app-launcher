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

Every shortcut is also registered as a KOReader **Dispatcher** action
(category: "general"), so it shows up wherever KOReader exposes
system actions — gestures, profiles, and the SimpleUI QuickAction
picker if [SimpleUI](https://github.com/doctorhetfield-cmd/simpleui.koplugin)
is installed. Dispatcher registrations refresh automatically when you
add, edit, or delete shortcuts.

## Usage

- **Tools → App Launcher** lists every shortcut. Tap to launch.
- **Edit shortcuts…** opens the editor: add, edit, reorder, delete.
- Each shortcut has a **Label** (shown in the menu) and a **URI**
  (whatever scheme the target app handles).
- The editor's **Test** button immediately launches the URI so you can
  verify it before saving.
- Tap a row to open its menu — **Set icon…** lets you browse to any
  SVG / PNG / JPG on the device. The picker starts in SimpleUI's icon
  directory if it exists. The icon shows up in App Launcher's own menu
  and is pushed to SimpleUI (via `QA.setDefaultActionIcon`) so the
  matching QuickAction tile uses it automatically.

If no installed app handles a URI, KOReader shows a toast
("No app handles `scheme:`") instead of crashing.

## Storage

Shortcuts live in `<koreader-data>/settings/applauncher_shortcuts.lua` as
a list of `{ id, label, uri, icon }` records. Safe to edit by hand or
sync between devices.

## Discovering an app's URL scheme

If you don't know what URI to plug into a shortcut, the most reliable
way is to ask the installed APK directly. With the device connected via
ADB:

```bash
adb shell pm list packages | grep -i <app-name>
adb shell dumpsys package <package.name> | grep -iE 'scheme|action.VIEW'
```

Any `scheme=…` line under an `android.intent.action.VIEW` filter is a
URI prefix the app accepts.

## Tested examples

| App           | Working URI                                |
|---------------|--------------------------------------------|
| Default browser | `https://duckduckgo.com/`                |
| Email client  | `mailto:`                                  |
| EinkBro       | `einkbros://duckduckgo.com` (requires recent build) |
| Obsidian      | `obsidian://open`                          |

## Limitations

- Android only. On other platforms the plugin loads but every launch
  attempt shows a toast.
- URI-scheme dispatch only. No package-name launch, no arbitrary intents.
  See [DESIGN.md](DESIGN.md) for why and what it would take to lift
  this.
- Icons depend on SimpleUI exposing `QA.setDefaultActionIcon`. On
  SimpleUI builds that predate this API, the icon you pick still
  appears in App Launcher's own menu but not on SimpleUI tiles.
- You have to know the scheme of each target app. See "Discovering an
  app's URL scheme" above.

## Architecture & design decisions

See [DESIGN.md](DESIGN.md) for the reasoning behind the URL-scheme
approach, why shortcuts register with KOReader's Dispatcher (rather
than a SimpleUI-private hook), the storage format, and known
limitations.
