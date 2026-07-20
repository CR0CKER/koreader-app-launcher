-- luacheck configuration for the App Launcher KOReader plugin.
--
-- KOReader plugins execute inside KOReader's LuaJIT environment; its module
-- loader provides the `require`-able modules ("device", "ui/...", etc.) at
-- runtime, so we lint against the LuaJIT standard library only.
std = "luajit"

-- Only the plugin is Lua; scripts/ is Python (linted by ruff/mypy).
include_files = { "applauncher.koplugin" }

ignore = {
    "212/self", -- unused 'self': KOReader event handlers use self:onEvent(arg)
    "213",      -- unused loop variable, e.g. the index in `for _idx, s in ipairs(...)`
}

-- _meta.lua carries a single user-facing i18n description string that cannot
-- be wrapped without altering the translated text; length is not correctness.
max_line_length = false
