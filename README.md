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

If no installed app handles a URI, KOReader shows a toast
("No app handles `scheme:`") instead of crashing.

Icons are intentionally not part of this plugin. When the shortcut is
surfaced on a SimpleUI tile, set the icon there — SimpleUI's
QuickAction editor stores a per-tile icon that overrides everything
else, so any default we tried to push from here would be ignored.

## Storage

Shortcuts live in `<koreader-data>/settings/applauncher_shortcuts.lua` as
a list of `{ id, label, uri }` records. Safe to edit by hand or
sync between devices.

## Will my app launch? (no ADB, 30 seconds)

On Android 11+ (every modern Boox), the only reliable launch paths
are:

1. The target app publishes a verified App Link on its `https://`
   domain. Check via:
   ```bash
   curl -fsSL https://<app-domain>/.well-known/assetlinks.json
   ```
   A JSON array with `delegate_permission/common.handle_all_urls`
   means yes — use `https://<app-domain>/` as the shortcut.
2. The target app is the user's **default browser**, in which case
   any `https://…` URL routes to it.

Custom URI schemes like `obsidian://`, `einkbros://` are *not*
reliably launchable from stock KOReader on Android 11+ due to package
visibility restrictions. See [DESIGN.md](DESIGN.md) for the gory
details.

## Tested examples

| App                | Working URI                                  | Why                      |
|--------------------|----------------------------------------------|--------------------------|
| Default browser    | `https://duckduckgo.com/`                    | http/https implicit allowance |
| Email client       | `mailto:`                                    | mailto allowance         |
| Readwise Reader    | `https://read.readwise.io/`                  | Verified App Link        |
| EinkBro (browser)  | `https://start.duckduckgo.com/`              | Only if default browser  |

## Icons (for SimpleUI tiles)

Set icons in SimpleUI's QuickAction editor, not here. For SVG sources,
Arcticons works well — grab them from
[github.com/Donnnno/Arcticons](https://github.com/Donnnno/Arcticons)
(`icons/black/` is ~14k SVGs / 230 MB raw), run them through
`scripts/flatten_arcticons.py` to make them NanoSVG-compatible (drops
to ~60 MB), then push to `/sdcard/icons/arcticons-black/` and point
SimpleUI's icon picker at them.

If a chosen icon renders too thin, edit its `style="…"` attributes to
add `stroke-width:2;` — KOReader's built-in icons sit around that
weight on a 48×48 viewBox.

## Limitations

- Android only. On other platforms the plugin loads but every launch
  attempt shows a toast.
- Custom URI schemes don't work on Android 11+. Use App Links or
  default-browser routing instead — see "Will my app launch?" above.
- No package-name launch, no arbitrary intents, no "bare" app launch
  without a URL. See [DESIGN.md](DESIGN.md) for the underlying
  KOReader/JNI limits.

## Architecture & design decisions

See [DESIGN.md](DESIGN.md) for the reasoning behind the URL-scheme
approach, why shortcuts register with KOReader's Dispatcher (rather
than a SimpleUI-private hook), the storage format, and known
limitations.
