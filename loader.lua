local lfs = require("lfs")
local io = require("io")

local Loader = {}

Loader._path_substitutions = {}
Loader._translations = {}
Loader.data = {}

function load_language_file(path, language)
    local file = io.open(path, "r")
    for line in file:lines() do
        local group_match = line:match("^%[([^%]]+)%]$")
        if group_match then
            group = group_match
        else
            local key, value = line:match("^([^=]+)=(.*)$")
            if key then
                if group then key = group .. "." .. key end
                Loader._translations[language][key] = value
            end
        end
    end
    file:close()
end

function load_languages(path)
    for language in lfs.dir(path) do
        local language_path = path .. "/" .. language
        if lfs.attributes(language_path, "mode") == "directory" then
            if Loader._translations[language] == nil then
                Loader._translations[language] = {}
            end
            for file in lfs.dir(language_path) do
                local path = path .. "/" .. language .. "/" .. file
                if path:match("%.cfg$") then
                    load_language_file(path, language)
                end
            end
        end
    end
end

local function contains(table, val)
   for i=1, #table do
      if table[i] == val then 
         return true
      end
   end
   return false
end

function clean_globals()
    important = {"settings", "table", "io", "math", "debug", "package", "_G", "python", "string", "os", "coroutine", "bit32", "util", "autoplace_utils"}
    for k, v in pairs(_G.package.loaded) do
        if not contains(important, k) then
            _G.package.loaded[k] = nil
        end
    end
end

function string.ends(String,End)
   return End=='' or string.sub(String,-string.len(End))==End
end

function check_exec_settings(path)
    if settings == nil then
        settings = {}
        settings.startup = {}
    end

    if lfs.attributes(path .. "/settings.lua") then
        print(path .. "/settings.lua")
        dofile(path .. "/settings.lua")
    end
    if lfs.attributes(path .. "/settings-updates.lua") then
        print(path .. "/settings-updates.lua")
        dofile(path .. "/settings-updates.lua")
    end
    
    for type, t_val in pairs(data.raw) do
        if string.ends(type, '-setting') then
            for k, v in pairs(data.raw[type]) do
                settings.startup[v.name] = {
                    value = v.default_value
                }
            end
        end
    end
end

--- Loads Factorio data files from a list of mods.
--
-- Paths contain a list of mods that are loaded, first one has to be core.
--
-- This function  hides the global table data, and instead exports
-- whats internaly data.raw as Loader.data
function Loader.load_data(paths)
    local old_data = data
    for i = 1, #paths do
        if i == 1 then
            package.path = paths[i] .. "/lualib/?.lua;" .. package.path
            require("dataloader")
        end

        local old_path = package.path
        package.path = paths[i] .. "/?.lua;./?.lua;" .. package.path

        if lfs.attributes(paths[i] .. "/data.lua") then
            check_exec_settings(paths[i])
            dofile(paths[i] .. "/data.lua")
            clean_globals()
        end

        local extended_path = "./" .. paths[i]

        Loader._path_substitutions["__" .. extended_path:gsub("^.*/([^/]+)/?$", "%1") .. "__"] = paths[i]

        if lfs.attributes(paths[i] .. "/locale/") then
            load_languages(paths[i] .. "/locale/")
        end

        package.path = old_path
    end
    for i = 1, #paths do
        local old_path = package.path
        package.path = paths[i] .. "/?.lua;" .. package.path

        if lfs.attributes(paths[i] .. "/data-updates.lua") then
            check_exec_settings(paths[i])
            dofile(paths[i] .. "/data-updates.lua")
            clean_globals()
        end

        package.path = old_path
    end
    for i = 1, #paths do
        local old_path = package.path
        package.path = paths[i] .. "/?.lua;" .. package.path

        if lfs.attributes(paths[i] .. "/data-final-fixes.lua") then
            check_exec_settings(paths[i])
            dofile(paths[i] .. "/data-final-fixes.lua")
            clean_globals()
        end

        package.path = old_path
    end
    
    Loader.data = data.raw
    data = old_data
end

--- Replace __mod__ references in path.
function Loader.expand_path(path)
    return path:gsub("__[a-zA-Z0-9-_]*__", Loader._path_substitutions)
end

function Loader.translate(string, language)
    if not Loader._translations[language] then
        return nil
    end

    return Loader._translations[language][string]
end

Loader.item_types = { "item", "ammo", "blueprint", "capsule",
                      "deconstruction-item", "gun", "module",
                      "armor", "mining-tool", "repair-tool" }

return Loader
