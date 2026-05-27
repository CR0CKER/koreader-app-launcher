local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local Launcher = require("launcher")
local Shortcuts = require("shortcuts")

local Editor = {}

local function row_text(s)
    return string.format("%s  \u{2192}  %s", s.label or "?", s.uri or "")
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
                        Shortcuts.add(plugin.shortcuts, label, uri)
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
