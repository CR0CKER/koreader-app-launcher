local Dispatcher = require("dispatcher")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local Launcher = require("launcher")
local Shortcuts = require("shortcuts")
local Editor = require("ui_edit")

local AppLauncher = WidgetContainer:extend{
    name = "applauncher",
    is_doc_only = false,
}

local function action_name(id)
    return "applauncher_" .. tostring(id)
end

function AppLauncher:init()
    self.shortcuts = Shortcuts.load()
    self.registered_names = {}
    self:onDispatcherRegisterActions()
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end

function AppLauncher:onDispatcherRegisterActions()
    for _idx, s in ipairs(self.shortcuts) do
        local name = action_name(s.id)
        Dispatcher:registerAction(name, {
            category = "none",
            event = "AppLauncherLaunch",
            arg = s.uri,
            title = s.label or s.uri,
            general = true,
        })
        self.registered_names[name] = true
    end
end

function AppLauncher:refresh()
    for name in pairs(self.registered_names) do
        Dispatcher:removeAction(name)
    end
    self.registered_names = {}
    self.shortcuts = Shortcuts.load()
    self:onDispatcherRegisterActions()
end

function AppLauncher:onAppLauncherLaunch(uri)
    Launcher.launch(uri)
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
