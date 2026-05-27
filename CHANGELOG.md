# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-05-27

### Added

- Initial public release.
- Shortcut editor (add / edit / reorder / delete) under
  **Tools → App Launcher** in KOReader.
- Per-shortcut KOReader Dispatcher registration so shortcuts are
  assignable to gestures, profiles, and SimpleUI QuickAction tiles.
- Graceful failure path: a toast ("No app handles `scheme:`") replaces
  the crash you'd otherwise get when no installed app handles the URI.
- Human-editable shortcut storage at
  `<koreader-data>/settings/applauncher_shortcuts.lua`.
- `scripts/flatten_arcticons.py` — converts Arcticons SVGs to a form
  KOReader's NanoSVG renderer can display (flattens `<style>` blocks
  into inline `style="…"` attributes).
- `DESIGN.md` documenting the URL-scheme approach, Dispatcher
  integration, NanoSVG quirks, and Android package-visibility limits.

[0.1.0]: https://github.com/CR0CKER/koreader-app-launcher/releases/tag/v0.1.0
