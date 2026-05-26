local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local _ = require("gettext")

local Launcher = require("launcher")
local Shortcuts = require("shortcuts")
local Editor = require("ui_edit")

local AppLauncher = WidgetContainer:extend{
    name = "applauncher",
    is_doc_only = false,
}

function AppLauncher:init()
    self.shortcuts = Shortcuts.load()
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
    self:registerWithSimpleUI()
end

function AppLauncher:refresh()
    self.shortcuts = Shortcuts.load()
    self:registerWithSimpleUI()
end

function AppLauncher:registerWithSimpleUI()
    local ok, QA = pcall(require, "sui_quickactions")
    if not ok or type(QA) ~= "table" or type(QA.register) ~= "function" then
        return
    end
    for _idx, s in ipairs(self.shortcuts) do
        local uri = s.uri
        local descriptor = {
            id = "applauncher_" .. tostring(s.id),
            label = s.label,
            icon = s.icon,
            execute = function() Launcher.launch(uri) end,
        }
        local ok_reg, err = pcall(QA.register, descriptor)
        if not ok_reg then
            logger.warn("applauncher: SimpleUI QA.register failed", err)
        end
    end
end

function AppLauncher:buildSubItems()
    local items = {}
    for _idx, s in ipairs(self.shortcuts) do
        local uri = s.uri
        table.insert(items, {
            text = s.label or "?",
            keep_menu_open = false,
            callback = function() Launcher.launch(uri) end,
        })
    end
    if #items == 0 then
        table.insert(items, {
            text = _("(no shortcuts \u{2014} add one below)"),
            enabled = false,
        })
    end
    table.insert(items, {
        text = _("Edit shortcuts\u{2026}"),
        keep_menu_open = true,
        separator = true,
        callback = function() Editor.show(self) end,
    })
    return items
end

function AppLauncher:addToMainMenu(menu_items)
    menu_items.applauncher = {
        text = _("App Launcher"),
        sorting_hint = "tools",
        sub_item_table_func = function() return self:buildSubItems() end,
    }
end

return AppLauncher
