local Device = require("device")
local Notification = require("ui/widget/notification")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local T = require("ffi/util").template
local logger = require("logger")

local Launcher = {}

local function scheme_of(uri)
    return uri:match("^([%w%+%-%.]+):") or uri
end

local function notify(text)
    UIManager:show(Notification:new{ text = text })
end

function Launcher.launch(uri)
    if not uri or uri == "" then
        notify(_("App Launcher: shortcut has no URI"))
        return false
    end
    if not Device:isAndroid() then
        notify(_("App Launcher: only works on Android"))
        return false
    end
    if not Device.openLink then
        notify(_("App Launcher: this KOReader build has no openLink"))
        return false
    end
    local ok, result = pcall(function() return Device:openLink(uri) end)
    if not ok then
        logger.warn("applauncher: openLink threw", result)
        notify(T(_("No app handles %1"), scheme_of(uri)))
        return false
    end
    if result == false then
        notify(T(_("No app handles %1"), scheme_of(uri)))
        return false
    end
    return true
end

return Launcher
