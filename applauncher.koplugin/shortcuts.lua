local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local logger = require("logger")

local Shortcuts = {}

local SETTINGS_FILE = DataStorage:getSettingsDir() .. "/applauncher_shortcuts.lua"

local function open_store()
    return LuaSettings:open(SETTINGS_FILE)
end

local function ensure_defaults(store)
    if store:has("shortcuts") then return end
    local defaults = require("default_shortcuts")
    store:saveSetting("shortcuts", defaults)
    store:flush()
end

function Shortcuts.load()
    local store = open_store()
    ensure_defaults(store)
    return store:readSetting("shortcuts") or {}
end

function Shortcuts.save(list)
    local store = open_store()
    store:saveSetting("shortcuts", list)
    store:flush()
end

local function next_id(list)
    local max = 0
    for _, s in ipairs(list) do
        local n = tonumber(s.id) or 0
        if n > max then max = n end
    end
    return tostring(max + 1)
end

function Shortcuts.add(list, label, uri, icon)
    local id = next_id(list)
    table.insert(list, {
        id = id,
        label = label,
        uri = uri,
        icon = icon,
    })
    Shortcuts.save(list)
    return id
end

function Shortcuts.get(list, id)
    for _, s in ipairs(list) do
        if s.id == id then return s end
    end
end

function Shortcuts.update(list, id, fields)
    for _, s in ipairs(list) do
        if s.id == id then
            for k, v in pairs(fields) do s[k] = v end
            Shortcuts.save(list)
            return true
        end
    end
    logger.warn("applauncher: update missed id", id)
    return false
end

function Shortcuts.remove(list, id)
    for i, s in ipairs(list) do
        if s.id == id then
            table.remove(list, i)
            Shortcuts.save(list)
            return true
        end
    end
    return false
end

function Shortcuts.move(list, id, delta)
    for i, s in ipairs(list) do
        if s.id == id then
            local j = i + delta
            if j < 1 or j > #list then return false end
            list[i], list[j] = list[j], list[i]
            Shortcuts.save(list)
            return true
        end
    end
    return false
end

return Shortcuts
