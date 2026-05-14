-- tools_settings.lua

PNNSIM_ConfigDefaults = {
    -- Console memory
    ["console.memory.linecount"]                     = { default = "200",    type = "posint", min = 10,  max = 10000 },
    ["console.memory.previouscommands"]              = { default = "50",     type = "posint", min = 5,   max = 500   },

    -- Console theme
    ["console.theme.textsize"]                       = { default = "14",     type = "posint", min = 6,   max = 30    },
    ["console.theme.textsize.title"]                 = { default = "14",     type = "posint", min = 6,   max = 30    },
    ["console.theme.consolecolor.bg"]                = { default = "000000", type = "hex"    },
    ["console.theme.consolecolor.border"]            = { default = "008000", type = "hex"    },
    ["console.theme.consolecolor.input.bg"]          = { default = "000000", type = "hex"    },
    ["console.theme.consolecolor.user"]              = { default = "00cc00", type = "hex"    },
    ["console.theme.consolecolor.textcolor.command"] = { default = "00ff00", type = "hex"    },
    ["console.theme.consolecolor.textcolor.output"]  = { default = "00cc00", type = "hex"    },
    ["console.theme.consolecolor.textcolor.error"]   = { default = "c70c15", type = "hex"    },

    -- Console behaviour
    ["console.autosell"]                             = { default = "0",      type = "bool"   },
    ["console.autosell.batchsize"]                   = { default = "50",     type = "posint", min = 1 },
    ["console.graydelete"]                           = { default = "0",      type = "bool"   },
    ["console.verbose"]                              = { default = "0",      type = "bool"   },
    ["console.delnovalue"]                           = { default = "0",      type = "bool"   },
    ["console.activeprofile"]                        = { default = "void",   type = "string" },
    ["console.defaultprofile"]                       = { default = "void",   type = "string" },

    -- Tracker dashboard
    ["tracker.dashboard"]                            = { default = "0",      type = "bool"   },

    -- Tracker genesis (per-character; writable for manual correction)
    ["tracker.genesis.sold"]                         = { default = "0",      type = "int"    },
    ["tracker.genesis.deleted"]                      = { default = "0",      type = "int"    },
    ["tracker.genesis.item.sold"]                    = { default = "0",      type = "int"    },
    ["tracker.genesis.item.deleted"]                 = { default = "0",      type = "int"    },
    ["tracker.genesis.time"]                         = { default = "0",      type = "int"    },

    -- Bag space indicator
    ["tool.bagspace"]                                = { default = "1",      type = "bool"                       },
    ["tool.bagspace.threshold.empty"]                = { default = "0",      type = "posint", min = 0, max = 100 },
    ["tool.bagspace.threshold.low"]                  = { default = "10",     type = "posint", min = 0, max = 100 },
    ["tool.bagspace.threshold.mid"]                  = { default = "50",     type = "posint", min = 0, max = 100 },
    ["tool.bagspace.color.empty"]                    = { default = "ff0000", type = "hex"                        },
    ["tool.bagspace.color.mid"]                      = { default = "ffff00", type = "hex"                        },
    ["tool.bagspace.color.high"]                     = { default = "00ff00", type = "hex"                        },

    -- Vendor management
    ["tool.vendormanagement"]                           = { default = "0",      type = "bool"   },
    ["tool.vendormanagement.lootername"]                = { default = "Greedy Scavenger", type = "name" },
    ["tool.vendormanagement.vendorname"]                = { default = "Goblin Merchant",  type = "name" },
    ["tool.vendormanagement.threshold"]                 = { default = "5",      type = "posint", min = 0 },

    -- Simple mailer
    ["tool.simplemailer.recipient"]                     = { default = "",       type = "string" },

    -- Minimap refresh
    ["tool.minimaprefresh.frequency"]                = { default = "100",    type = "posint", min = 50  },
}

-- Returns nil on success, or an error string on failure.
local function ValidateSetting(key, value)
    local entry = PNNSIM_ConfigDefaults[key]
    if not entry then return "Unknown setting: " .. key end

    local t = entry.type

    if t == "bool" then
        if value ~= "0" and value ~= "1" then
            return 'Invalid type entered. Expected "bool" received "' .. value .. '"'
        end

    elseif t == "int" then
        local n = tonumber(value)
        if not n or math.floor(n) ~= n then
            return 'Invalid type entered. Expected "int" received "' .. value .. '"'
        end

    elseif t == "posint" then
        local n = tonumber(value)
        if not n or math.floor(n) ~= n then
            return 'Invalid type entered. Expected "posint" received "' .. value .. '"'
        end
        local min = entry.min or 1
        local max = entry.max
        if n < min or (max and n > max) then
            local rangeStr = max and ("between " .. tostring(min) .. " and " .. tostring(max)) or ("at least " .. tostring(min))
            return "Value out of range. " .. key .. " must be " .. rangeStr
        end

    elseif t == "string" then
        if not string.match(value, "^[%w%-%_]+$") then
            return 'Invalid type entered. Expected "string" received "' .. value .. '"'
        end

    elseif t == "name" then
        if value == "" then
            return 'Invalid type entered. Expected "name" received empty string'
        end

    elseif t == "hex" then
        local stripped = string.gsub(value, "#", "")
        if not string.match(stripped, "^%x%x%x%x%x%x$") then
            return 'Invalid type entered. Expected "hex" received "' .. value .. '"'
        end
    end

    return nil
end

-- Returns the actual stored char name matching the lowercased input, or nil.
local function FindCharName(lowerSeg)
    if PNNSIM_Profiles then
        for charName in pairs(PNNSIM_Profiles) do
            if string.lower(charName) == lowerSeg then return charName end
        end
    end
    if PNNSIM_ConsoleConfig then
        for k in pairs(PNNSIM_ConsoleConfig) do
            local prefix = string.match(k, "^([^%.]+)%.")
            if prefix and string.lower(prefix) == lowerSeg then return prefix end
        end
    end
    return nil
end

-- Splits raw input into (charName, settingKey, valuePart).
-- charName is the actual stored name (e.g. "Prebble").
-- settingKey is the bare key (e.g. "console.autosell"), lowercased.
-- valuePart is trimmed, or nil.
local function ResolvePath(text)
    local lower = string.lower(text)
    local pathPart, valuePart = string.match(lower, "^(%S+)%s+(.+)$")
    if not pathPart then pathPart = lower end
    if valuePart then valuePart = string.match(valuePart, "^%s*(.-)%s*$") end

    -- Check if first segment is a char name
    local firstSeg, rest = string.match(pathPart, "^([^%.]+)%.(.*)$")
    if firstSeg then
        local found = FindCharName(firstSeg)
        if found then
            return found, rest, valuePart
        end
    end

    -- Default to current char
    return UnitName("player"), pathPart, valuePart
end

-- Returns the error color hex from config, falling back to default.
local function ErrorHex()
    local entry = PNNSIM_ConfigDefaults["console.theme.consolecolor.textcolor.error"]
    local charName = UnitName("player")
    local fullKey = charName .. ".console.theme.consolecolor.textcolor.error"
    if PNNSIM_ConsoleConfig and PNNSIM_ConsoleConfig[fullKey] then
        return PNNSIM_ConsoleConfig[fullKey]
    end
    return entry and entry.default or "c70c15"
end

local function PrintError(msg)
    if PNNSIM_Console_PrintRaw then
        PNNSIM_Console_PrintRaw("|cFF" .. ErrorHex() .. msg .. "|r")
    end
end

local function OutHex()
    local e = PNNSIM_ConfigDefaults["console.theme.consolecolor.textcolor.output"]
    local k = UnitName("player") .. ".console.theme.consolecolor.textcolor.output"
    if PNNSIM_ConsoleConfig and PNNSIM_ConsoleConfig[k] then return PNNSIM_ConsoleConfig[k] end
    return e and e.default or "00cc00"
end

local function CmdHex()
    local e = PNNSIM_ConfigDefaults["console.theme.consolecolor.textcolor.command"]
    local k = UnitName("player") .. ".console.theme.consolecolor.textcolor.command"
    if PNNSIM_ConsoleConfig and PNNSIM_ConsoleConfig[k] then return PNNSIM_ConsoleConfig[k] end
    return e and e.default or "00ff00"
end

-- Collects all display lines for a given char scope and key prefix.
-- charName = nil means all chars.
-- keyPrefix = "" means all settings.
local function BuildListing(charScope, keyPrefix)
    local lines = {}
    local outHex = OutHex()
    local cmdHex = CmdHex()

    local function collectAllChars()
        local chars = {}
        local charSeen = {}
        if PNNSIM_ConsoleConfig then
            for k in pairs(PNNSIM_ConsoleConfig) do
                local c = string.match(k, "^([^%.]+)%.")
                if c and not charSeen[c] then charSeen[c] = true; table.insert(chars, c) end
            end
        end
        if PNNSIM_Profiles then
            for c in pairs(PNNSIM_Profiles) do
                if not charSeen[c] then charSeen[c] = true; table.insert(chars, c) end
            end
        end
        table.sort(chars)
        return chars
    end

    -- Collect setting lines from PNNSIM_ConsoleConfig
    local seen = {}
    if PNNSIM_ConsoleConfig then
        local keys = {}
        for k in pairs(PNNSIM_ConsoleConfig) do table.insert(keys, k) end
        table.sort(keys)
        for _, k in ipairs(keys) do
            -- k is like "Prebble.console.autosell"
            local kChar, kProp = string.match(k, "^([^%.]+)%.(.+)$")
            if kChar and kProp then
                local charMatch = (charScope == nil) or (string.lower(kChar) == string.lower(charScope))
                local propMatch = string.sub(kProp, 1, string.len(keyPrefix)) == keyPrefix
                if charMatch and propMatch and PNNSIM_ConfigDefaults[kProp] then
                    local entry = PNNSIM_ConfigDefaults[kProp]
                    local line = string.format(
                        "|cFF%s%s.%s|r: |cFF%s%s|r (default: %s)",
                        cmdHex, kChar, kProp, outHex,
                        tostring(PNNSIM_ConsoleConfig[k]), tostring(entry.default)
                    )
                    table.insert(lines, line)
                    seen[string.lower(kChar) .. "." .. kProp] = true
                end
            end
        end
    end

    -- Also emit settings that are at default (not stored in PNNSIM_ConsoleConfig)
    -- Only for the scoped char(s)
    local function emitDefaultsForChar(cName)
        local currentPlayer = UnitName("player")
        local sortedKeys = {}
        for k in pairs(PNNSIM_ConfigDefaults) do table.insert(sortedKeys, k) end
        table.sort(sortedKeys)
        for _, k in ipairs(sortedKeys) do
            local seenKey = string.lower(cName) .. "." .. k
            if not seen[seenKey] and string.sub(k, 1, string.len(keyPrefix)) == keyPrefix then
                local entry = PNNSIM_ConfigDefaults[k]
                local displayVal
                if string.sub(k, 1, 15) == "tracker.genesis" and cName == currentPlayer then
                    displayVal = tostring(PNNSIM_CharData and PNNSIM_CharData[k] or entry.default)
                else
                    displayVal = tostring(entry.default)
                end
                local line = string.format(
                    "|cFF%s%s.%s|r: |cFF%s%s|r (default: %s)",
                    cmdHex, cName, k, outHex, displayVal, tostring(entry.default)
                )
                table.insert(lines, line)
            end
        end
    end

    if charScope then
        emitDefaultsForChar(charScope)
    else
        local chars = collectAllChars()
        for _, c in ipairs(chars) do emitDefaultsForChar(c) end
    end

    -- Emit profiles
    local function emitProfilesForChar(cName)
        local charProfiles = PNNSIM_Profiles and PNNSIM_Profiles[cName]
        if not charProfiles then return end
        local pKeys = {}
        for pk in pairs(charProfiles) do table.insert(pKeys, pk) end
        table.sort(pKeys)
        local activePKey = nil
        if PNNSIM_GetActiveProfile then
            activePKey = PNNSIM_GetActiveProfile()
        end
        for _, pk in ipairs(pKeys) do
            local pData = charProfiles[pk]
            local dispName = pData.displayName or pk
            local activeMarker = (activePKey == pk) and " [active]" or ""
            local line = string.format(
                "|cFF%s%s.vendorprofile.%s|r%s",
                cmdHex, cName, dispName, activeMarker
            )
            table.insert(lines, line)
        end
    end

    local vpPrefix = "vendorprofile"
    local kLen = string.len(keyPrefix)
    local vLen = string.len(vpPrefix)
    local showProfiles = keyPrefix == ""
        or (kLen <= vLen and string.sub(vpPrefix, 1, kLen) == keyPrefix)
        or (kLen > vLen and string.sub(keyPrefix, 1, vLen) == vpPrefix)

    if showProfiles then
        if charScope then
            emitProfilesForChar(charScope)
        else
            local chars = collectAllChars()
            for _, c in ipairs(chars) do emitProfilesForChar(c) end
        end
    end

    return lines
end

function PNNSIM_HandleSettingsInput(text)
    local lower = string.lower(text)

    if lower == "." or string.sub(lower, -1) == "." then
        local charScope, keyPrefix
        if lower == "." then
            charScope = nil
            keyPrefix = ""
        else
            -- Strip trailing dot, resolve char scope
            local pathNoTrail = string.sub(lower, 1, -2)
            local firstSeg, rest = string.match(pathNoTrail, "^([^%.]+)%.(.*)$")
            if firstSeg then
                local found = FindCharName(firstSeg)
                if found then
                    charScope = found
                    keyPrefix = rest
                else
                    charScope = UnitName("player")
                    keyPrefix = pathNoTrail
                end
            else
                -- Single segment with trailing dot e.g. "console."
                local found = FindCharName(pathNoTrail)
                if found then
                    charScope = found
                    keyPrefix = ""
                else
                    charScope = UnitName("player")
                    keyPrefix = pathNoTrail .. "."
                end
            end
        end

        -- Vendorprofile command discovery: intercept before BuildListing
        local vpTail = string.match(keyPrefix, "^vendorprofile(.*)$")
        if vpTail ~= nil then
            local ch = CmdHex()
            local oh = OutHex()
            -- Strip leading dot to get the rest of the path
            local vpRest = string.match(vpTail, "^%.(.*)$") or vpTail

            if vpRest == "" then
                -- vendorprofile. → show global commands then list profiles for scoped char
                PNNSIM_Console_Print("|cFF" .. ch .. "vendorprofile global commands:|r")
                PNNSIM_Console_Print("  vendorprofile.list")
                PNNSIM_Console_Print("  vendorprofile.create [name]")
                PNNSIM_Console_Print("  vendorprofile.keep.list")
                PNNSIM_Console_Print("  vendorprofile.sell.list")
                local targetChar = charScope or UnitName("player")
                local charProfiles = PNNSIM_Profiles and PNNSIM_Profiles[targetChar]
                if not charProfiles or next(charProfiles) == nil then
                    PNNSIM_Console_Print("|cFF" .. oh .. "No profiles for " .. targetChar .. ".|r")
                else
                    PNNSIM_Console_Print("|cFF" .. ch .. "profiles:|r")
                    local pKeys = {}
                    for pk in pairs(charProfiles) do table.insert(pKeys, pk) end
                    table.sort(pKeys)
                    local activePKey = nil
                    if PNNSIM_GetActiveProfile then
                        activePKey = PNNSIM_GetActiveProfile()
                    end
                    for _, pk in ipairs(pKeys) do
                        local pData = charProfiles[pk]
                        local dispName = pData.displayName or pk
                        local activeMarker = (activePKey == pk) and " [active]" or ""
                        local autoStr = (pData.autoSell ~= false) and "autosell:on" or "autosell:off"
                        local keepCt = pData.keep and #pData.keep or 0
                        local sellCt = pData.sell and #pData.sell or 0
                        PNNSIM_Console_Print(string.format(
                            "|cFF%s%s.vendorprofile.%s|r%s  %s  keep:%d sell:%d",
                            ch, targetChar, dispName, activeMarker, autoStr, keepCt, sellCt
                        ))
                    end
                end
            else
                -- vpRest = "NAME" or "NAME.subpath"
                local profileSeg, subPath = string.match(vpRest, "^([^%.]+)%.?(.*)$")
                local targetChar = charScope or UnitName("player")
                local charProfiles = PNNSIM_Profiles and PNNSIM_Profiles[targetChar]
                local pKey, pData
                if charProfiles and profileSeg then
                    for pk, pd in pairs(charProfiles) do
                        local dn = pd.displayName or pk
                        if string.lower(dn) == profileSeg or string.lower(pk) == profileSeg then
                            pKey = pk; pData = pd; break
                        end
                    end
                end
                if not pData then
                    PNNSIM_Console_Print("|cFF" .. oh .. "Profile '" .. (profileSeg or "") .. "' not found.|r")
                else
                    local dispName = pData.displayName or pKey
                    if subPath == "" then
                        PNNSIM_Console_Print("|cFF" .. ch .. "vendorprofile." .. dispName .. " commands:|r")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".activate")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".deactivate")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".autosell.on")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".autosell.off")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".keep.list")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".keep.add [item]")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".keep.rem [id]")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".keep.mod [id] [value]")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".sell.list")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".sell.add [item]")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".sell.rem [id]")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".sell.mod [id] [value]")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".search [query]")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".cleanup")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".delete")
                    elseif subPath == "autosell" then
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".autosell.on")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".autosell.off")
                    elseif subPath == "keep" then
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".keep.list")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".keep.add [item]")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".keep.rem [id]")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".keep.mod [id] [value]")
                    elseif subPath == "sell" then
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".sell.list")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".sell.add [item]")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".sell.rem [id]")
                        PNNSIM_Console_Print("  vendorprofile." .. dispName .. ".sell.mod [id] [value]")
                    else
                        PNNSIM_Console_Print("|cFF" .. oh .. "Unknown sub-path '" .. subPath .. "'. Try vendorprofile." .. dispName .. ".|r")
                    end
                end
            end
            return true
        end

        local lines = BuildListing(charScope, keyPrefix)

        -- Inject non-setting commands so they appear alongside settings in path discovery
        local allCmds = {
            "console.help",
            "console.permclear",
            "console.save",
            "console.show",
            "console.tracker.genesis.gold.reset",
            "console.tracker.genesis.item.reset",
            "console.tracker.session.gold.reset",
            "console.tracker.session.item.reset",
            "console.tracker.show",
            "tool.getproperties",
            "tool.sortbags",
            "tool.minimaprefresh",
            "tool.bagspace",
            "tool.vendormanagement",
            "tool.vendormanagement.lootername",
            "tool.vendormanagement.vendorname",
            "tool.vendormanagement.threshold",
            "tool.simplemailer.recipient",
            "tool.simplemailer.bagkeep.list",
            "tool.simplemailer.bagkeep.add",
            "tool.simplemailer.bagkeep.rem",
            "tool.simplemailer.send",
        }
        local ck = CmdHex()
        for _, cmd in ipairs(allCmds) do
            if keyPrefix == "" or string.sub(cmd, 1, #keyPrefix) == keyPrefix then
                table.insert(lines, "|cFF" .. ck .. cmd .. "|r  [command]")
            end
        end

        if #lines == 0 then
            PNNSIM_Console_Print("No settings or profiles found.")
        else
            for _, line in ipairs(lines) do
                PNNSIM_Console_Print(line)
            end
        end
        return true
    end

    local charName, settingKey, valuePart = ResolvePath(text)

    -- Is this a known setting?
    local entry = PNNSIM_ConfigDefaults[settingKey]
    if not entry then return false end

    local isTrackerKey = string.sub(settingKey, 1, 15) == "tracker.genesis"
    if isTrackerKey and charName ~= UnitName("player") then
        PrintError("tracker.genesis settings are per-character. Log in as " .. charName .. " to modify them.")
        return true
    end

    local fullKey = charName .. "." .. settingKey
    local current
    if isTrackerKey then
        current = (PNNSIM_CharData and PNNSIM_CharData[settingKey]) or entry.default
    else
        current = (PNNSIM_ConsoleConfig and PNNSIM_ConsoleConfig[fullKey]) or entry.default
    end

    local outHex = OutHex
    local cmdHex = CmdHex

    -- Point query: no value → print current and default
    if not valuePart then
        PNNSIM_Console_Print(string.format(
            "|cFF%s%s|r: |cFF%s%s|r (default: %s)",
            cmdHex(), fullKey, outHex(), tostring(current), tostring(entry.default)
        ))
        return true
    end

    -- Reset to default
    if valuePart == "default" then
        local alreadyDefault
        if isTrackerKey then
            alreadyDefault = not (PNNSIM_CharData and PNNSIM_CharData[settingKey])
        else
            alreadyDefault = not (PNNSIM_ConsoleConfig and PNNSIM_ConsoleConfig[fullKey])
        end
        if alreadyDefault then
            PNNSIM_Console_Print("|cFF" .. outHex() .. "Already at default: " .. tostring(entry.default) .. "|r")
        else
            if isTrackerKey then
                PNNSIM_CharData[settingKey] = nil
            else
                PNNSIM_ConsoleConfig[fullKey] = nil
            end
            PNNSIM_Console_Print("|cFF" .. outHex() .. fullKey .. " reset to default: " .. tostring(entry.default) .. "|r")
            if PNNSIM_InitConsoleTheme then PNNSIM_InitConsoleTheme() end
        end
        return true
    end

    -- Set operation: validate then write
    local err = ValidateSetting(settingKey, valuePart)
    if err then
        PrintError(err)
        return true
    end

    if settingKey == "console.activeprofile" and valuePart ~= "void" then
        local targetChar = charName
        local charProfiles = PNNSIM_Profiles and PNNSIM_Profiles[targetChar]
        if not charProfiles or not charProfiles[string.lower(valuePart)] then
            PrintError("Profile '" .. valuePart .. "' does not exist for " .. targetChar .. ".")
            return true
        end
    end

    if settingKey == "console.defaultprofile" and valuePart ~= "void" then
        local charProfiles = PNNSIM_Profiles and PNNSIM_Profiles[charName]
        if not charProfiles or not charProfiles[string.lower(valuePart)] then
            PrintError("Profile '" .. valuePart .. "' does not exist for " .. charName .. ".")
            return true
        end
    end

    -- Strip # from hex values before writing
    local writeVal = valuePart
    if entry.type == "hex" then
        writeVal = string.gsub(writeVal, "#", "")
    end

    if isTrackerKey then
        PNNSIM_CharData = PNNSIM_CharData or {}
        PNNSIM_CharData[settingKey] = writeVal
    else
        PNNSIM_ConsoleConfig = PNNSIM_ConsoleConfig or {}
        PNNSIM_ConsoleConfig[fullKey] = writeVal
    end
    if settingKey == "tool.minimaprefresh.frequency" then
        if PNNSIM_MinimapRefresh_RestartIfActive then PNNSIM_MinimapRefresh_RestartIfActive() end
    end
    PNNSIM_Console_Print("|cFF" .. outHex() .. fullKey .. " = " .. writeVal .. "|r")
    if PNNSIM_InitConsoleTheme then PNNSIM_InitConsoleTheme() end
    return true
end
