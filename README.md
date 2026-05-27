# koreader-app-launcher

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: Android](https://img.shields.io/badge/platform-Android-green.svg)](#requirements)
[![KOReader plugin](https://img.shields.io/badge/KOReader-plugin-blue.svg)](https://github.com/koreader/koreader)

Launch other Android apps straight from KOReader.

Built for Android e-readers (Boox, Onyx, Likebook, etc.) where switching
between a book and a notes app, browser, dictionary, or email client
would otherwise mean exiting to the launcher.

![SimpleUI QuickAction strip with two App Launcher shortcuts (globe = browser, R = Readwise Reader) alongside SimpleUI's built-in library and home tiles](docs/quickactions.png)

*Two App Launcher shortcuts (rightmost: a browser, and Readwise Reader)
shown on a SimpleUI QuickAction strip next to SimpleUI's built-in
library and home tiles.*

## Features

- Add, edit, reorder, and delete launch shortcuts from inside KOReader.
- Shortcuts appear under **Tools → App Launcher** and as KOReader
  **Dispatcher** actions — so they're also assignable to gestures,
  profiles, and (if installed) [SimpleUI][simpleui] QuickAction tiles.
- One-tap **Test** button in the editor to verify a URI before saving.
- Graceful failure: if no installed app handles the URI, KOReader
  shows a toast instead of crashing.
- Human-editable storage: shortcuts live in a plain Lua file you can
  hand-edit or sync between devices.

## Requirements

- KOReader running on Android (any recent build).
- The target apps must register an Android URL scheme or a verified
  App Link — see [Will my app launch?](#will-my-app-launch-no-adb-30-seconds)
  below.

The plugin loads on other platforms (Linux, macOS, Kindle, Kobo) but
every launch attempt is a no-op there, because the underlying
`Device:openLink` is Android-only in practice.

## Install

1. Download or clone this repo:
   ```bash
   git clone https://github.com/CR0CKER/koreader-app-launcher.git
   ```
2. Copy `applauncher.koplugin/` into your KOReader plugins directory:
   ```
   <koreader-data>/plugins/applauncher.koplugin/
   ```
   On Android this is typically `/sdcard/koreader/plugins/`.
3. Restart KOReader. The plugin appears under **Tools → App Launcher**.

## Usage

- **Tools → App Launcher** lists every shortcut. Tap to launch.
- **Edit shortcuts…** opens the editor: add, edit, reorder, delete.
- Each shortcut has a **Label** (shown in menus) and a **URI**
  (whatever scheme the target app handles).
- The editor's **Test** button immediately launches the URI so you
  can verify it before saving.

Because every shortcut is also a Dispatcher action, you'll find each
one under **Settings → Gesture manager → Action → General** and in
SimpleUI's QuickAction picker. Dispatcher registrations refresh
automatically when you add, edit, or delete shortcuts.

### Icons

Icons aren't part of this plugin by design — SimpleUI's QuickAction
editor already has an icon picker, and it wins over any default we
could push from here (see [DESIGN.md](DESIGN.md#known-limitations)).
Set the icon there.

For high-quality SVG sources, [Arcticons][arcticons] works well; run
the raw SVGs through `scripts/flatten_arcticons.py` first to make
them [NanoSVG][nanosvg]-compatible, then point SimpleUI's picker at
the output directory.

## Will my app launch? (no ADB, 30 seconds)

On Android 11+ (every modern Boox), the only reliable launch paths
are:

1. The target app publishes a verified App Link on its `https://`
   domain. Check via:
   ```bash
   curl -fsSL https://<app-domain>/.well-known/assetlinks.json
   ```
   A JSON array with `delegate_permission/common.handle_all_urls`
   means yes — use `https://<app-domain>/` as the shortcut URI.
2. The target app is the user's **default browser**, in which case
   any `https://…` URL routes to it.

Custom URI schemes like `obsidian://` or `einkbros://` are *not*
reliably launchable from stock KOReader on Android 11+ due to package
visibility restrictions. See [DESIGN.md](DESIGN.md) for the gory
details.

### Tested examples

| App                | Working URI                       | Why                            |
|--------------------|-----------------------------------|--------------------------------|
| Default browser    | `https://duckduckgo.com/`         | http/https implicit allowance  |
| Email client       | `mailto:`                         | mailto allowance               |
| Readwise Reader    | `https://read.readwise.io/`       | Verified App Link              |
| EinkBro (browser)  | `https://start.duckduckgo.com/`   | Only if default browser        |

## Storage

Shortcuts live in `<koreader-data>/settings/applauncher_shortcuts.lua`
as a list of `{ id, label, uri }` records. Safe to edit by hand or
sync between devices.

## Limitations

- **Android only** in practice.
- **Custom URI schemes don't work on Android 11+.** Use App Links or
  default-browser routing instead.
- **No package-name launch, no arbitrary intents, no "bare" launch
  without a URL.** These would need a Kotlin patch to
  `android-luajit-launcher` and a rebuilt APK. See [DESIGN.md](DESIGN.md).
- **No enumeration of installed apps** — you have to know the
  target app's URL.

## Contributing

Bug reports, suggestions, and PRs are welcome. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the short version.

## Architecture & design decisions

See [DESIGN.md](DESIGN.md) for the reasoning behind the URL-scheme
approach, why shortcuts register with KOReader's Dispatcher (rather
than a SimpleUI-private hook), the storage format, and known
limitations.

## Acknowledgements

- [KOReader][koreader] — the document reader this plugin extends.
- [SimpleUI][simpleui] — homescreen launcher whose QuickActions
  surface this plugin's shortcuts.
- [Arcticons][arcticons] — the line-art icon set the flattener
  script targets.

## License

MIT — see [LICENSE](LICENSE).

[koreader]: https://github.com/koreader/koreader
[simpleui]: https://github.com/doctorhetfield-cmd/simpleui.koplugin
[arcticons]: https://github.com/Donnnno/Arcticons
[nanosvg]: https://github.com/memononen/nanosvg
