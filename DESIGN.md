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

## URL schemes as the launch primitive (and the Android 11+ catch)

`openLink("foo://bar")` *should* be enough to launch any app that has
registered an `intent-filter` for that scheme. In practice, on every
modern Boox (Android 11+), custom-scheme dispatch from KOReader is
broken — and the failure is silent. Here's the actual launchability
matrix on stock KOReader:

| What the target app declares                                       | Works? |
|--------------------------------------------------------------------|--------|
| Verified App Link (`assetlinks.json` on its `https://` domain)     | ✅ Yes |
| `http`/`https` scheme + user has it set as default browser         | ✅ Yes |
| Custom URI scheme only (`einkbros://`, `obsidian://`, etc.)        | ❌ No  |
| Nothing                                                            | ❌ No  |

Two compounding reasons custom schemes fail:

1. **No `<queries>` element in KOReader's `AndroidManifest.xml`.**
   Android 11 (API 30) introduced package visibility restrictions: an
   app cannot resolve activities of other apps unless they're declared
   in `<queries>` (or matched by a small implicit allowlist). KOReader
   declares no `<queries>`. Android's allowlist *does* include browser
   queries (any handler of `http`/`https`), which is exactly why
   default-browser dispatch works. Custom schemes get no implicit
   allowance, so the target app is invisible to `startActivity()` and
   the framework throws `ActivityNotFoundException` — surfaced to the
   user as our "No app handles `…:`" toast.
2. **`openLink` is minimal.** The Kotlin is literally
   `Intent(ACTION_VIEW, Uri.parse(url)); startActivity(intent)` — no
   `addCategory(BROWSABLE)`, no `setPackage`. Even on pre-11 Android
   where (1) wouldn't bite, the missing BROWSABLE reduces match
   reliability against filters that declare it.

Both are KOReader/APK-level issues; no Lua workaround exists. A future
patch to `android-luajit-launcher` could add `<queries>` for common
schemes plus `intent.addCategory(BROWSABLE)`, but that's a custom-APK
path.

### Checking if a given app is launchable (30 seconds, no ADB)

```bash
curl -fsSL https://<app-domain>/.well-known/assetlinks.json
```

If you see a JSON array with a `delegate_permission/common.handle_all_urls`
entry, the app publishes a verified App Link — you can launch it with
`https://<app-domain>/` regardless of default-browser setting. Examples
confirmed during development:

- **Readwise Reader** → `read.readwise.io` publishes assetlinks for
  package `com.readermobile`. Shortcut `https://read.readwise.io/`
  works directly.
- **EinkBro** → no assetlinks. Only launchable by setting it as the
  default browser and using `https://…` URIs.

### Tab reuse (EinkBro-specific, but informative)

EinkBro's `ACTION_VIEW` handler calls `getUrlMatchedBrowser(url)` and
reuses an existing tab if the URL matches. So repeated launches of the
same shortcut URL don't proliferate tabs — *unless* the user has
navigated away in that tab, in which case the match fails and a fresh
tab opens. Practical advice: use a sentinel start-page URL you won't
navigate away from.

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

## Icon rendering: NanoSVG quirks

KOReader uses NanoSVG to render SVGs, which only understands a subset
of the spec. The two gotchas hit during development:

- **No `<style>` block support.** NanoSVG ignores CSS-style class
  rules, so any element relying on `class="…"` to get its stroke/fill
  renders with the SVG default (`fill: black, stroke: none`). For
  outlined/stroke-based icon sets like Arcticons, this means every
  icon collapses to a solid silhouette or — when the icon is just
  strokes — a single filled blob (the circular frame becomes a black
  dot, the rest disappears). Fix: pre-process the SVG to flatten
  `<style>` rules into inline `style="…"` attributes per element. See
  `scripts/flatten_arcticons.py`; works on the entire ~14k-icon
  Arcticons set, and the same approach generalises to other
  CSS-styled icon packs.
- **Stroke widths don't auto-scale.** Arcticons strokes default to
  `1` on a 48×48 viewBox, which reads too thin next to KOReader's
  built-in UI icons (which feel closer to `2`). For shortcuts where
  the visual weight matters, append `stroke-width:2` to each element's
  inline style. One sed/Edit pass per icon. 1.5 reads "elegant", 2
  reads "matches KOReader", 2.5 reads "bold."

## Known limitations

- **No per-shortcut icon.** A picker existed briefly and was removed:
  SimpleUI exposes our shortcuts through Dispatcher and wraps each one
  in a Custom QA (`simpleui_cqa_<n>`). `QA.getEntry()` resolves
  Custom QAs from their own `cfg.icon` and never consults
  `QA.getDefaultActionIcon`, so pushing icons via
  `QA.setDefaultActionIcon("applauncher_<id>", path)` was a silent
  no-op on the SimpleUI tiles — which is the surface anyone actually
  cared about. SimpleUI's QuickAction editor already has an icon
  picker; use that. (If a future change moves us off the
  custom-QA-wrapping path — e.g. registering directly through
  `QA.register` — the default-icon override would start applying again.)
- **No way to launch apps without a registered URL scheme.** This is a
  hard limit of stock KOReader; would require a Kotlin patch to
  `android-luajit-launcher` (`packageManager.getLaunchIntentForPackage`)
  and a rebuilt APK.
- **Custom URI schemes don't work on Android 11+** for the reasons in
  the "URL schemes" section above. Use App Links or
  default-browser-routed `https://…` instead.
- **No enumeration of installed apps from Lua.** You have to know the
  target app's launchable URL. The assetlinks.json curl check is the
  fastest way to decide whether a given app is reachable.
- **No way to launch an app "bare" (no URL).** `ACTION_MAIN +
  CATEGORY_LAUNCHER` isn't exposed; every launch must carry a URL.
  For tab-based apps like EinkBro this means at least one tab is
  always touched on launch.
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
