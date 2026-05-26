# Design notes

Why this plugin works the way it does. Useful if you want to extend it,
fork it, or argue with the choices.

## The constraint we hit first

KOReader on Android runs through
[`android-luajit-launcher`](https://github.com/koreader/android-luajit-launcher),
which exposes a small, hand-picked set of helpers to Lua via JNI. Reading
`MainActivity.kt` and `ActivityExtensions.kt` in that repo, the
intent-launching surface is exactly:

| Lua call                          | Underlying Android intent                                          |
|-----------------------------------|--------------------------------------------------------------------|
| `android.openLink(url)`           | `Intent(ACTION_VIEW, Uri.parse(url))`                              |
| `android.dictLookup(text, a, pkg)`| Hard-coded to `aard2`, `colordict`, `quickdic`, `search`, `send`, `text` |
| `android.sendText(...)`           | `ACTION_SEND` chooser                                              |
| `android.openWifiSettings()`      | One specific settings intent                                       |
| `android.safFilePicker(path)`     | SAF file picker                                                    |

Notably absent: any generic `startActivity()` or "launch by package
name" method. The convenient
`intent://...#Intent;package=...;end` URI escape hatch also doesn't
work, because `openLink` calls `Uri.parse` rather than `Intent.parseUri`
— so the package hint inside the URI is just discarded.

**Conclusion: from a pure Lua KOReader plugin you cannot launch an
arbitrary Android app by package name.** The SimpleUI maintainer was
right about that. What you *can* do is fire an `ACTION_VIEW` at a URI
and let Android route it.

## URL schemes as the launch primitive

`openLink("foo://bar")` is enough to launch any app that has registered
an `intent-filter` for that scheme. Most apps a reader would want to
jump to do register one:

- `https://…` (any browser)
- `mailto:…` (any email client)
- `obsidian://`, `joplin://`, `simplenote://` (notes apps)
- `einkbro://`, `einkbros://` (EinkBro browser)
- `kiwix://`, `aard2://`, `colordict://` (dictionaries / offline wiki)
- `anki://`, `pocket://`, `calibre://` …
- Many Boox built-ins respond to `boox://` or HTTPS App Links

For apps without a registered scheme, there's no workaround on stock
KOReader. The plugin tells the user via toast when that happens.

### Discovering an app's schemes

```bash
adb shell dumpsys package <package.name> | grep -iE 'scheme|action.VIEW'
```

Look under any `android.intent.action.VIEW` filter; the `scheme=…`
lines are URIs the app handles. If an app advertises `autoVerify="true"`
on an `https://example.com` host, that App Link will also bypass the
default-browser chooser and open the target app directly.

## Exposing shortcuts to SimpleUI: Dispatcher, not a custom API

The first attempt registered each shortcut via a `QA.register()` call
on SimpleUI's `sui_quickactions` module. This silently did nothing —
SimpleUI's QuickAction picker discovers actions through KOReader's
core **Dispatcher** registry (`frontend/dispatcher.lua`), not through a
plugin-private API.

The fix: every shortcut becomes a Dispatcher action.

```lua
Dispatcher:registerAction("applauncher_" .. id, {
    category = "none",
    event    = "AppLauncherLaunch",
    arg      = uri,
    title    = label,
    general  = true,
})
```

The plugin then handles `AppLauncher:onAppLauncherLaunch(uri)` and
dispatches to `launcher.launch(uri)`. Because Dispatcher is the canonical
KOReader action registry, the shortcuts also become assignable to
gestures, profiles, and anywhere else KOReader surfaces system actions
— not just SimpleUI QuickActions.

When shortcuts are edited, the plugin calls `Dispatcher:removeAction`
for every previously-registered name and re-registers from the fresh
list, so renames and deletions stay consistent. The set of registered
names is tracked in `self.registered_names`.

## Storage

Shortcuts persist to `<koreader-data>/settings/applauncher_shortcuts.lua`
through `LuaSettings:open` (KOReader's standard pattern). Schema:

```lua
{
    shortcuts = {
        { id = "1", label = "Web search", uri = "https://duckduckgo.com/" },
        { id = "2", label = "EinkBro",    uri = "einkbros://news.ycombinator.com" },
        ...
    },
}
```

`id` is a stable string monotonically assigned at create time so that
Dispatcher action names stay stable across edits (renames don't shift
IDs). File is human-editable.

## Module layout

```
applauncher.koplugin/
├── _meta.lua              Plugin name + description (KOReader contract)
├── main.lua               WidgetContainer; Tools menu + Dispatcher registration
├── launcher.lua           Wraps Device:openLink with pcall + toast on failure
├── shortcuts.lua          CRUD + reorder against LuaSettings file
├── ui_edit.lua            Menu + ButtonDialog + MultiInputDialog editor
└── default_shortcuts.lua  Seed list created on first run
```

The split is deliberate: `launcher.lua` is the *only* place that talks
to `Device:openLink`. If a future KOReader release adds a true
`startActivityByPackage` API, swapping the implementation in one file
covers the whole plugin.

## Process / chronology

For posterity, the order this got figured out in:

1. Surveyed `android-luajit-launcher` to confirm what JNI surface
   actually exists. Ruled out package-name launching.
2. Confirmed `openLink` uses `Uri.parse` (not `Intent.parseUri`), which
   killed the `intent://…#Intent;package=…;end` shortcut.
3. Picked URL schemes as the launch primitive.
4. First QuickActions integration attempt used a private SimpleUI hook
   (`QA.register`). It compiled, ran, and did nothing — SimpleUI reads
   from KOReader's Dispatcher.
5. Switched to `Dispatcher:registerAction` / `removeAction` per
   shortcut. Shortcuts then appeared in SimpleUI's QuickAction picker,
   the Gesture manager, and Profiles.

## Known limitations

- **No icon picker.** SimpleUI uses `descriptor.icon` for the tile
  graphic and falls back to a generic icon when nil. The plugin
  currently leaves icon nil for every shortcut. A future enhancement
  would add an icon field to the edit dialog plus a file browser into
  the SimpleUI / KOReader icon directories.
- **No way to launch apps without a registered URL scheme.** This is a
  hard limit of stock KOReader; would require a Kotlin patch to
  `android-luajit-launcher` (`packageManager.getLaunchIntentForPackage`)
  and a rebuilt APK.
- **No enumeration of installed apps from Lua.** You have to know the
  target app's scheme. ADB `dumpsys package` is the easiest discovery.
- **Boox-specific deep links** vary between Boox firmware versions;
  what works on a Poke 3 may not work on a Note Air or Page.

## Verifying changes

1. Copy `applauncher.koplugin/` to `<koreader-data>/plugins/`.
2. Restart KOReader.
3. **Tools → App Launcher** lists the seed shortcuts and `Edit
   shortcuts…`. Tap any to launch.
4. **Gesture manager → Action → General** should list every shortcut
   as `<label>`. (This is also what SimpleUI's QuickAction picker draws
   from.)
5. Add a shortcut with `nosuchapp://x`; tap; expect a toast "No app
   handles `nosuchapp:`" rather than a crash. This validates the error
   path.
6. Add a shortcut for a real app (e.g. `einkbros://duckduckgo.com`);
   tap; expect that app to open at the given URL.
7. Edit/reorder/delete a shortcut. Reopen the Gesture manager picker;
   the list should reflect the change without a KOReader restart.
