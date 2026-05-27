# Contributing

Bug reports, feature suggestions, and pull requests are all welcome.

## Filing issues

Please include:

- KOReader version (Help → About).
- Device and Android version (e.g. Boox Page, Android 11).
- The shortcut URI you tested, and what happened (toast text,
  silent no-op, crash, wrong app opened, etc.).
- Whether the same URI works when pasted into an Android browser
  address bar — useful for separating "URI is wrong" from "KOReader
  can't reach the app".

## Pull requests

- Branch off `main`.
- Keep the diff focused: one concern per PR.
- Match the existing Lua style (two-space indent, `local`-first,
  `pcall` around anything that can fail at the KOReader/device
  boundary).
- For UI changes, describe the manual test you ran on-device — there
  are no automated tests for this plugin.
- Update [DESIGN.md](DESIGN.md) when a change shifts an architectural
  decision (e.g. "we now register via X instead of Y, because Z").

## Scope

The plugin deliberately stays small: it's a thin wrapper around
`Device:openLink`. Features that would require a custom KOReader
build or a Kotlin patch to `android-luajit-launcher` are out of
scope here — see [DESIGN.md](DESIGN.md) for the reasoning.
