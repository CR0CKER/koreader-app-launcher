local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local PathChooser = require("ui/widget/pathchooser")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local _ = require("gettext")

local Launcher = require("launcher")
local Shortcuts = require("shortcuts")

local Editor = {}

local function is_image_path(path)
    if not path then return false end
    local lower = path:lower()
    return lower:match("%.svg$") or lower:match("%.png$")
        or lower:match("%.jpg$") or lower:match("%.jpeg$")
end

local function pick_start_dir()
    local candidates = {
        "/sdcard/icons/arcticons-black",
        "/sdcard/icons/arcticons-white",
        "/sdcard/icons/arcticons",
        "/sdcard/icons",
        DataStorage:getSettingsDir() .. "/simpleui/sui_icons",
        DataStorage:getSettingsDir() .. "/simpleui",
        DataStorage:getDataDir() .. "/plugins/simpleui.koplugin/icons/custom",
        DataStorage:getDataDir() .. "/plugins/simpleui.koplugin/icons",
        DataStorage:getDataDir(),
    }
    for _, p in ipairs(candidates) do
        local attr = lfs.attributes(p)
        if attr and attr.mode == "directory" then return p end
    end
    return nil
end

local function row_text(s)
    local icon_marker = (s.icon and s.icon ~= "") and " \u{1F5BC} " or "    "
    return string.format("%s%s  \u{2192}  %s", icon_marker, s.label or "?", s.uri or "")
end

local function build_items(plugin, on_change)
    local items = {}
    for idx, s in ipairs(plugin.shortcuts) do
        table.insert(items, {
            text = row_text(s),
            callback = function() Editor.openRowMenu(plugin, idx, on_change) end,
        })
    end
    table.insert(items, {
        text = _("+ Add shortcut\u{2026}"),
        callback = function() Editor.openEditDialog(plugin, nil, on_change) end,
    })
    return items
end

function Editor.show(plugin)
    local menu
    local function refresh()
        menu:switchItemTable(_("Edit shortcuts"), build_items(plugin, refresh))
    end
    menu = Menu:new{
        title = _("Edit shortcuts"),
        item_table = build_items(plugin, function() if menu then refresh() end end),
        is_borderless = true,
        is_popout = false,
        width = Screen:getWidth(),
        height = Screen:getHeight(),
        close_callback = function() plugin:refresh() end,
    }
    UIManager:show(menu)
end

function Editor.openRowMenu(plugin, idx, on_change)
    local s = plugin.shortcuts[idx]
    if not s then return end
    local dialog
    dialog = ButtonDialog:new{
        title = s.label or "?",
        title_align = "center",
        buttons = {
            {
                { text = _("Test"), callback = function()
                    UIManager:close(dialog)
                    Launcher.launch(s.uri)
                end },
                { text = _("Edit"), callback = function()
                    UIManager:close(dialog)
                    Editor.openEditDialog(plugin, idx, on_change)
                end },
            },
            {
                { text = _("Set icon\u{2026}"), callback = function()
                    UIManager:close(dialog)
                    Editor.pickIcon(plugin, s.id, on_change)
                end },
                { text = _("Clear icon"), enabled = s.icon ~= nil and s.icon ~= "", callback = function()
                    UIManager:close(dialog)
                    Shortcuts.update(plugin.shortcuts, s.id, { icon = nil })
                    on_change()
                end },
            },
            {
                { text = _("Move up"), enabled = idx > 1, callback = function()
                    UIManager:close(dialog)
                    Shortcuts.move(plugin.shortcuts, s.id, -1)
                    on_change()
                end },
                { text = _("Move down"), enabled = idx < #plugin.shortcuts, callback = function()
                    UIManager:close(dialog)
                    Shortcuts.move(plugin.shortcuts, s.id, 1)
                    on_change()
                end },
            },
            {
                { text = _("Delete"), callback = function()
                    UIManager:close(dialog)
                    UIManager:show(ConfirmBox:new{
                        text = _("Delete this shortcut?"),
                        ok_callback = function()
                            Shortcuts.remove(plugin.shortcuts, s.id)
                            on_change()
                        end,
                    })
                end },
                { text = _("Cancel"), callback = function() UIManager:close(dialog) end },
            },
        },
    }
    UIManager:show(dialog)
end

function Editor.pickIcon(plugin, id, on_change)
    local start = pick_start_dir()
    local chooser
    chooser = PathChooser:new{
        title = _("Select icon (SVG / PNG / JPG)"),
        select_directory = false,
        select_file = true,
        path = start,
        file_filter = function(path) return is_image_path(path) end,
        onConfirm = function(path)
            if not is_image_path(path) then
                UIManager:show(InfoMessage:new{
                    text = _("That file isn't an SVG / PNG / JPG."),
                })
                return
            end
            Shortcuts.update(plugin.shortcuts, id, { icon = path })
            on_change()
        end,
    }
    UIManager:show(chooser)
end

function Editor.openEditDialog(plugin, idx, on_change)
    local existing = idx and plugin.shortcuts[idx] or nil
    local dialog
    dialog = MultiInputDialog:new{
        title = existing and _("Edit shortcut") or _("Add shortcut"),
        fields = {
            {
                description = _("Label"),
                text = existing and existing.label or "",
                hint = _("e.g. Obsidian"),
            },
            {
                description = _("URI"),
                text = existing and existing.uri or "",
                hint = _("e.g. obsidian://open"),
            },
        },
        buttons = {
            {
                { text = _("Cancel"), id = "close", callback = function()
                    UIManager:close(dialog)
                end },
                { text = _("Test"), callback = function()
                    local fields = dialog:getFields()
                    Launcher.launch(fields[2])
                end },
                { text = _("Save"), callback = function()
                    local fields = dialog:getFields()
                    local label = (fields[1] or ""):gsub("^%s+", ""):gsub("%s+$", "")
                    local uri = (fields[2] or ""):gsub("^%s+", ""):gsub("%s+$", "")
                    if label == "" or uri == "" then
                        UIManager:show(InfoMessage:new{
                            text = _("Label and URI are both required."),
                        })
                        return
                    end
                    if existing then
                        Shortcuts.update(plugin.shortcuts, existing.id,
                            { label = label, uri = uri })
                    else
                        Shortcuts.add(plugin.shortcuts, label, uri, nil)
                    end
                    UIManager:close(dialog)
                    on_change()
                end },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

return Editor
