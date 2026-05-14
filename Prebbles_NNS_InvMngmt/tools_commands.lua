-- tools_commands.lua

local PNNSIM_Loader = CreateFrame("Frame")
PNNSIM_Loader:RegisterEvent("ADDON_LOADED")
PNNSIM_Loader:SetScript("OnEvent", function(self, event, addon)
    if addon == "Prebbles_NNS_InvMngmt" then
        PNNSIM_Profiles = PNNSIM_Profiles or {}
        local charName = UnitName("player")
        PNNSIM_Profiles[charName] = PNNSIM_Profiles[charName] or {}
        if PNNSIM_InitConsoleTheme then
            PNNSIM_InitConsoleTheme()
        end
    end
end)

local function GetSafeItemLink(id)
    local _, link = GetItemInfo(id)
    if link then return link end
    
    local hiddenTooltip = PNNSIM_HiddenTooltip or CreateFrame("GameTooltip", "PNNSIM_HiddenTooltip", nil, "GameTooltipTemplate")
    hiddenTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    hiddenTooltip:SetHyperlink("item:"..id)
    
    _, link = GetItemInfo(id)
    if link then return link end
    
    return "\124cffffffff\124Hitem:"..id..":0:0:0:0:0:0:0\124h[Item ID "..id.." (Not Cached)]\124h\124r"
end

local function FormatListEntry(entry)
    local fsStr = entry.fs and " [--fs]" or ""
    local ptsStr = entry.pts and " [--pts]" or ""
    if entry.type == "id" then
        return "ID: " .. GetSafeItemLink(entry.value) .. fsStr .. ptsStr
    elseif entry.type == "exact" then
        return "Exact: *" .. tostring(entry.value) .. "*" .. fsStr .. ptsStr
    elseif entry.type == "match" then
        return "Match: *" .. tostring(entry.value) .. "*" .. fsStr .. ptsStr
    elseif entry.type == "filter" then
        return "Filter: " .. tostring(entry.value) .. fsStr .. ptsStr
    end
    return "Unknown Entry"
end

local KNOWN_FLAGS = { "fs", "pts" }

local function ExtractFlags(str)
    local flags = {}
    local changed = true
    while changed do
        changed = false
        for _, flag in ipairs(KNOWN_FLAGS) do
            if string.match(str, "%s*%-%-" .. flag .. "$") then
                flags[flag] = true
                str = strtrim(string.gsub(str, "%s*%-%-" .. flag .. "$", ""))
                changed = true
            end
        end
    end
    return strtrim(str), flags
end

local function DetermineInputType(input)
    local id = string.match(input, "Hitem:(%d+)")
    if not id and tonumber(input) then id = tonumber(input) end
    if id then return "id", tonumber(id) end

    local exactMatch = string.match(input, "^item%.name%.exact%(\"(.*)\"%)$")
    if exactMatch then return "exact", exactMatch end

    local partialMatch = string.match(input, "^item%.name%.match%(\"(.*)\"%)$")
    if partialMatch then return "match", partialMatch end

    local wildcard = string.match(input, "^%*(.+)%*$")
    if wildcard then return "match", wildcard end

    -- Check [Bracketed Name] before operator sniff so names containing ( = > < are not mis-classified as filters
    local bracketed = string.match(input, "^%[(.-)%]$")
    if bracketed then return "exact", bracketed end

    if string.find(input, "=") or string.find(input, ">") or string.find(input, "<") or string.find(input, "%(") then
        return "filter", input
    end

    return "exact", input
end

local function EntryToInputString(entry)
    if entry.type == "id" then return "Hitem:" .. entry.value end
    if entry.type == "exact" then return "[" .. tostring(entry.value) .. "]" end
    if entry.type == "match" then return "*" .. tostring(entry.value) .. "*" end
    if entry.type == "filter" then return tostring(entry.value) end
    return tostring(entry.value)
end

StaticPopupDialogs["PNNSIM_TEMPSELL_CONFIRM"] = {
    text = "WARNING: Enabling Temp Sell mode will sell or delete ALL items in your bags, except those protected by --pts or named Hearthstone. Your keep profile will be completely ignored.",
    button1 = "Confirm",
    button2 = "Cancel",
    OnAccept = function()
        local charName = UnitName("player")
        PNNSIM_TempSellActive = true
        PNNSIM_TempSellEpochSnapshot = PNNSIM_ProfilesEpoch or 0
        PNNSIM_TempSellLastKillTime = GetTime()
        if PNNSIM_ConsoleConfig then
            PNNSIM_ConsoleConfig[charName .. ".console.tempsell"] = "1"
        end
        local msg = "Temp Sell mode ENABLED. All bags will be emptied at each vendor."
        if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
    end,
    OnCancel = function()
        local msg = "Temp Sell mode cancelled."
        if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function PNNSIM_ProcessCommand(PNNSIM_msg, PNNSIM_isConsole)
    local function PNNSIM_Print(PNNSIM_s)
        if PNNSIM_isConsole and PNNSIM_Console_Print then
            PNNSIM_Console_Print(PNNSIM_s)
        else
            print(PNNSIM_s)
        end
    end

    local function PrintErr(PNNSIM_s)
        local errHex = "c70c15"
        if PNNSIM_ConsoleConfig then
            local k = UnitName("player") .. ".console.theme.consolecolor.textcolor.error"
            errHex = PNNSIM_ConsoleConfig[k] or errHex
        end
        if PNNSIM_isConsole and PNNSIM_Console_PrintRaw then
            PNNSIM_Console_PrintRaw("|cFF" .. errHex .. PNNSIM_s .. "|r")
        else
            print(PNNSIM_s)
        end
    end

    if not PNNSIM_msg or PNNSIM_msg == "" then
        if PNNSIM_isConsole then return end
        PNNSIM_Print("|cff00ff00[PNNSIM]|r Type /nps help for commands.")
        return
    end

    local PNNSIM_cmd_lower = string.lower(PNNSIM_msg)

    if string.sub(PNNSIM_cmd_lower, 1, 7) == "console" and not string.match(PNNSIM_cmd_lower, "vendorprofile") then
        local subcmd = string.match(PNNSIM_cmd_lower, "^console[%.%s](.+)$")
        if subcmd == "show" and not PNNSIM_isConsole then
            if PNNSIM_Console then
                if PNNSIM_Console:IsShown() then PNNSIM_Console:Hide() else PNNSIM_Console:Show() end
            end
            return
        elseif subcmd == "help" then
            if PNNSIM_isConsole then
                PNNSIM_Print("These shell commands are defined internally.  Type `help' to see this list.")
            end
            PNNSIM_Print("Console Usage:")
            PNNSIM_Print("  Mousewheel to scroll through outputs.")
            PNNSIM_Print("  exit to close console.")
            PNNSIM_Print("  Clr/Cls/Clear to clear console screen.")
            PNNSIM_Print("  console.save to force UI reload and save state.")
            PNNSIM_Print("  console.permclear to permanently clear output and history.")
            return
        elseif subcmd == "tracker.show" then
            local genSold = (PNNSIM_CharData and PNNSIM_CharData["tracker.genesis.sold"]) or 0
            local genDel = (PNNSIM_CharData and PNNSIM_CharData["tracker.genesis.deleted"]) or 0
            local genItemSold = (PNNSIM_CharData and PNNSIM_CharData["tracker.genesis.item.sold"]) or 0
            local genItemDel = (PNNSIM_CharData and PNNSIM_CharData["tracker.genesis.item.deleted"]) or 0
            local sessHours = (GetTime() - PNNSIM_SessionTracker.startTime) / 3600
            local sessSoldPH = sessHours > 0 and (PNNSIM_SessionTracker.sold / sessHours) or 0
            local sessDelPH = sessHours > 0 and (PNNSIM_SessionTracker.deleted / sessHours) or 0
            PNNSIM_Print("--- PNNSIM Trackers ---")
            PNNSIM_Print("Session Items Sold: " .. PNNSIM_SessionTracker.soldItems .. " | Value: " .. GetCoinTextureString(PNNSIM_SessionTracker.sold) .. " (" .. GetCoinTextureString(math.floor(sessSoldPH)) .. "/hr)")
            PNNSIM_Print("Session Items Deleted: " .. PNNSIM_SessionTracker.deletedItems .. " | Value: " .. GetCoinTextureString(PNNSIM_SessionTracker.deleted) .. " (" .. GetCoinTextureString(math.floor(sessDelPH)) .. "/hr)")
            PNNSIM_Print("Genesis Items Sold: " .. genItemSold .. " | Value: " .. GetCoinTextureString(genSold))
            PNNSIM_Print("Genesis Items Deleted: " .. genItemDel .. " | Value: " .. GetCoinTextureString(genDel))
            return
        elseif subcmd == "tracker.genesis.gold.reset" then
            if PNNSIM_CharData then
                PNNSIM_CharData["tracker.genesis.sold"] = 0
                PNNSIM_CharData["tracker.genesis.deleted"] = 0
                PNNSIM_Print("Genesis gold tracker has been reset.")
                if PNNSIM_UpdateTrackerUI then PNNSIM_UpdateTrackerUI() end
            end
            return
        elseif subcmd == "tracker.session.gold.reset" then
            PNNSIM_SessionTracker.sold = 0
            PNNSIM_SessionTracker.deleted = 0
            PNNSIM_SessionTracker.startTime = GetTime()
            PNNSIM_Print("Session gold tracker has been reset.")
            if PNNSIM_UpdateTrackerUI then PNNSIM_UpdateTrackerUI() end
            return
        elseif subcmd == "tracker.genesis.item.reset" then
            if PNNSIM_CharData then
                PNNSIM_CharData["tracker.genesis.item.sold"] = 0
                PNNSIM_CharData["tracker.genesis.item.deleted"] = 0
                PNNSIM_Print("Genesis item tracker has been reset.")
                if PNNSIM_UpdateTrackerUI then PNNSIM_UpdateTrackerUI() end
            end
            return
        elseif subcmd == "tracker.session.item.reset" then
            PNNSIM_SessionTracker.soldItems = 0
            PNNSIM_SessionTracker.deletedItems = 0
            PNNSIM_Print("Session item tracker has been reset.")
            if PNNSIM_UpdateTrackerUI then PNNSIM_UpdateTrackerUI() end
            return
        end
    end

    if string.match(PNNSIM_cmd_lower, "^help") then
        PNNSIM_Print("Commands:")
        PNNSIM_Print("  vendorprofile.list")
        PNNSIM_Print("  vendorprofile.keep.list")
        PNNSIM_Print("  vendorprofile.sell.list")
        PNNSIM_Print("  vendorprofile.create [name]")
        PNNSIM_Print("  vendorprofile.[name].delete")
        PNNSIM_Print("  vendorprofile.[name].deactivate")
        PNNSIM_Print("  vendorprofile.[name].cleanup")
        PNNSIM_Print("  vendorprofile.[name].autosell.on")
        PNNSIM_Print("  vendorprofile.[name].autosell.off")
        PNNSIM_Print("  vendorprofile.[name].[keep/sell].add [target/filter] [--fs] [--pts]")
        PNNSIM_Print("  vendorprofile.[name].[keep/sell].rem [target/filter]")
        PNNSIM_Print("  vendorprofile.[name].[keep/sell].rem ID:#####")
        PNNSIM_Print("  vendorprofile.[name].[keep/sell].rem --listid [ids]")
        PNNSIM_Print("  vendorprofile.[name].[keep/sell].mod ID:#####")
        PNNSIM_Print("  vendorprofile.[name].keep.list")
        PNNSIM_Print("  vendorprofile.[name].sell.list")
        PNNSIM_Print("  vendorprofile.[name].search [item/text]")
        PNNSIM_Print("  vendorprofile.[name].activate")
        PNNSIM_Print("  vendorprofile.[name].zone.list")
        PNNSIM_Print("  vendorprofile.[name].zone.register")
        PNNSIM_Print("  vendorprofile.[name].zone.add [zone,zone,...]")
        PNNSIM_Print("  vendorprofile.[name].zone.delete [zone,...] or *")
        PNNSIM_Print("  vendorprofile.[name].zone.enable")
        PNNSIM_Print("  vendorprofile.[name].zone.disable")
        PNNSIM_Print("  vendorprofile.tempsell [0/1]")
        PNNSIM_Print("  console.show")
        PNNSIM_Print("  console.save")
        PNNSIM_Print("  console.permclear")
        PNNSIM_Print("  console.help")
        PNNSIM_Print("  console.activeprofile [profilename|void]")
        PNNSIM_Print("  console.defaultprofile [profilename|void]")
        PNNSIM_Print("  console.autosell [0/1]")
        PNNSIM_Print("  console.autosell.batchsize [N] (items per batch, default: 50)")
        PNNSIM_Print("  console.graydelete [0/1]")
        PNNSIM_Print("  console.delnovalue [0/1]")
        PNNSIM_Print("  console.verbose [0/1]")
        PNNSIM_Print("  console.tracker.show")
        PNNSIM_Print("  console.tracker.genesis.gold.reset")
        PNNSIM_Print("  console.tracker.genesis.item.reset")
        PNNSIM_Print("  console.tracker.session.gold.reset")
        PNNSIM_Print("  console.tracker.session.item.reset")
        PNNSIM_Print("  tracker.dashboard [0/1]")
        PNNSIM_Print("  tool.getproperties [itemlink/ID]")
        PNNSIM_Print("  tool.sortbags")
        PNNSIM_Print("  tool.bagspace [0/1]")
        PNNSIM_Print("  tool.minimaprefresh [1/0]")
        PNNSIM_Print("  tool.minimaprefresh [ms] (default: 100)")
        PNNSIM_Print("  tool.vendormanagement [0/1]")
        PNNSIM_Print("  tool.vendormanagement.lootername [name]")
        PNNSIM_Print("  tool.vendormanagement.vendorname [name]")
        PNNSIM_Print("  tool.vendormanagement.threshold [N] (free slots to trigger sell, default: 5)")
        PNNSIM_Print("  tool.simplemailer.recipient [charname]")
        PNNSIM_Print("  tool.simplemailer.bagkeep.list")
        PNNSIM_Print("  tool.simplemailer.bagkeep.add [itemlink or item ID]")
        PNNSIM_Print("  tool.simplemailer.bagkeep.rem [index]")
        PNNSIM_Print("  tool.simplemailer.send")
        return
    end

    if PNNSIM_cmd_lower == "vendorprofile.list" then
        PNNSIM_Print("All Vendor Profiles:")
        for charName, charProfiles in pairs(PNNSIM_Profiles) do
            for pKey, pData in pairs(charProfiles) do
                PNNSIM_Print("  " .. charName .. ".vendorprofile." .. (pData.displayName or pKey))
            end
        end
        return
    end

    if PNNSIM_cmd_lower == "vendorprofile.sell.list" then
        PNNSIM_Print("Available Vendor Profiles:")
        local charProfiles = PNNSIM_Profiles[UnitName("player")] or {}
        for pKey, pData in pairs(charProfiles) do
            PNNSIM_Print("  - " .. (pData.displayName or pKey))
        end
        return
    end

    if PNNSIM_cmd_lower == "vendorprofile.keep.list" then
        PNNSIM_Print("Vendor Profiles with Keep Rules:")
        local charProfiles = PNNSIM_Profiles[UnitName("player")] or {}
        for pKey, pData in pairs(charProfiles) do
            if pData.keep and #pData.keep > 0 then
                PNNSIM_Print("  - " .. (pData.displayName or pKey))
            end
        end
        return
    end

    if PNNSIM_cmd_lower == "vendorprofile." or PNNSIM_cmd_lower == "vendorprofile" then
        PNNSIM_Print("Vendorprofile Commands:")
        PNNSIM_Print("  vendorprofile.list")
        PNNSIM_Print("  vendorprofile.keep.list")
        PNNSIM_Print("  vendorprofile.sell.list")
        PNNSIM_Print("  vendorprofile.create [name]")
        PNNSIM_Print("  vendorprofile.[name].delete")
        PNNSIM_Print("  vendorprofile.[name].deactivate")
        PNNSIM_Print("  vendorprofile.[name].cleanup")
        PNNSIM_Print("  vendorprofile.[name].autosell.on")
        PNNSIM_Print("  vendorprofile.[name].autosell.off")
        PNNSIM_Print("  vendorprofile.[name].[keep/sell].add [target/filter] [--fs] [--pts]")
        PNNSIM_Print("  vendorprofile.[name].[keep/sell].rem [target/filter]")
        PNNSIM_Print("  vendorprofile.[name].[keep/sell].rem ID:#####")
        PNNSIM_Print("  vendorprofile.[name].[keep/sell].rem --listid [ids]")
        PNNSIM_Print("  vendorprofile.[name].[keep/sell].mod ID:#####")
        PNNSIM_Print("  vendorprofile.[name].keep.list")
        PNNSIM_Print("  vendorprofile.[name].sell.list")
        PNNSIM_Print("  vendorprofile.[name].search [item/text]")
        PNNSIM_Print("  vendorprofile.[name].activate")
        PNNSIM_Print("  vendorprofile.[name].zone.list")
        PNNSIM_Print("  vendorprofile.[name].zone.register")
        PNNSIM_Print("  vendorprofile.[name].zone.add [zone,zone,...]")
        PNNSIM_Print("  vendorprofile.[name].zone.delete [zone,...] or *")
        PNNSIM_Print("  vendorprofile.[name].zone.enable")
        PNNSIM_Print("  vendorprofile.[name].zone.disable")
        PNNSIM_Print("  vendorprofile.tempsell [0/1]")
        return
    end

    local cmd_part, args_part = string.match(PNNSIM_msg, "^(%S+)%s*(.*)$")
    if not cmd_part then return end
    local cmd_lower = string.lower(cmd_part)

    if cmd_lower == "vendorprofile.create" then
        local vp_name = strtrim(args_part)
        if vp_name == "" then
            PrintErr("Missing profile name.")
            return
        end
        if not string.match(vp_name, "^[%w_%-]+$") then
            PrintErr("Invalid profile name '" .. vp_name .. "'. Use only letters, numbers, underscores, or dashes.")
            return
        end
        local pKey = string.lower(vp_name)
        local charName = UnitName("player")
        PNNSIM_Profiles[charName] = PNNSIM_Profiles[charName] or {}
        PNNSIM_Profiles[charName][pKey] = PNNSIM_Profiles[charName][pKey] or { sell = {}, keep = {}, zones = {"0000-0000-0000"}, zoneEnabled = false, nextListID = 1, displayName = vp_name, autoSell = true }
        PNNSIM_ConsoleConfig = PNNSIM_ConsoleConfig or {}
        PNNSIM_ConsoleConfig[charName .. ".console.activeprofile"] = pKey
        if PNNSIM_UpdateConsoleTitleBar then PNNSIM_UpdateConsoleTitleBar() end
        PNNSIM_ProfilesEpoch = (PNNSIM_ProfilesEpoch or 0) + 1
        PNNSIM_Print("Profile '" .. vp_name .. "' created and activated for current character.")
        return
    end

    if cmd_lower == "vendorprofile.tempsell" then
        local val = strtrim(args_part)
        if val == "0" then
            PNNSIM_TempSellActive = false
            if PNNSIM_ConsoleConfig then
                PNNSIM_ConsoleConfig[UnitName("player") .. ".console.tempsell"] = "0"
            end
            PNNSIM_Print("Temp Sell mode disabled.")
        elseif val == "1" then
            StaticPopup_Show("PNNSIM_TEMPSELL_CONFIRM")
        else
            PrintErr("Usage: vendorprofile.tempsell [0/1]")
        end
        return
    end

    local vp_prefix, vp_name, vp_subcmd = string.match(cmd_lower, "^(vendorprofile)%.([^%.]+)%.(.*)$")
    
    if vp_prefix == "vendorprofile" and vp_name and vp_subcmd then
        local pKey = string.lower(vp_name)
        local charName = UnitName("player")
        local charProfiles = PNNSIM_Profiles[charName]
        if not charProfiles or not charProfiles[pKey] then
            PrintErr("Profile '" .. vp_name .. "' does not exist.")
            return
        end

        local profile = charProfiles[pKey]
        local pDisp = profile.displayName or vp_name
        profile.nextListID = profile.nextListID or 1
        local vp_args = strtrim(args_part)

        if vp_subcmd == "cleanup" then
            local function CleanupList(list)
                local seen = {}
                local count = 0
                local i = 1
                while i <= #list do
                    local entry = list[i]
                    local hash = entry.type .. "_" .. tostring(entry.value) .. "_" .. tostring(entry.fs) .. "_" .. tostring(entry.pts)
                    if seen[hash] then
                        table.remove(list, i)
                        count = count + 1
                    else
                        seen[hash] = true
                        i = i + 1
                    end
                end
                return count
            end
            local keepRem = CleanupList(profile.keep)
            local sellRem = CleanupList(profile.sell)
            PNNSIM_Print("Profile '" .. pDisp .. "' cleaned. Removed " .. keepRem .. " duplicate KEEP rules and " .. sellRem .. " duplicate SELL rules.")
            return
        elseif vp_subcmd == "delete" then
            if string.lower(strtrim(vp_args)) == pKey then
                charProfiles[pKey] = nil
                PNNSIM_ProfilesEpoch = (PNNSIM_ProfilesEpoch or 0) + 1
                if PNNSIM_ConsoleConfig and PNNSIM_ConsoleConfig[charName..".console.activeprofile"] == pKey then
                    PNNSIM_ConsoleConfig[charName..".console.activeprofile"] = "void"
                end
                if PNNSIM_UpdateConsoleTitleBar then PNNSIM_UpdateConsoleTitleBar() end
                PNNSIM_Print("Profile '" .. pDisp .. "' has been completely deleted.")
            else
                PNNSIM_Print("Confirm deletion by typing the profile name:")
                PNNSIM_Print("  vendorprofile." .. pKey .. ".delete " .. pKey)
            end
            return
        elseif vp_subcmd == "deactivate" then
            PNNSIM_ConsoleConfig = PNNSIM_ConsoleConfig or {}
            local curKey = PNNSIM_ConsoleConfig[charName .. ".console.activeprofile"]
            if curKey == pKey then
                PNNSIM_ConsoleConfig[charName .. ".console.activeprofile"] = "void"
                if PNNSIM_UpdateConsoleTitleBar then PNNSIM_UpdateConsoleTitleBar() end
                PNNSIM_Print("Profile '" .. pDisp .. "' deactivated.")
            else
                PNNSIM_Print("Profile '" .. pDisp .. "' is not currently active.")
            end
            return
        elseif vp_subcmd == "autosell.activate" or vp_subcmd == "autosell.on" then
            profile.autoSell = true
            PNNSIM_Print("Autosell ENABLED for profile '" .. pDisp .. "'.")
            return
        elseif vp_subcmd == "autosell.disable" or vp_subcmd == "autosell.off" then
            profile.autoSell = false
            PNNSIM_Print("Autosell DISABLED for profile '" .. pDisp .. "'.")
            return
        elseif vp_subcmd == "search" then
            if not vp_args or vp_args == "" then
                PrintErr("Missing search arguments.")
                return
            end
            
            local testIDStr = string.match(vp_args, "Hitem:(%d+)")
            local testID = testIDStr and tonumber(testIDStr) or tonumber(vp_args)
            
            local itemData = nil
            if testID then
                local linkToUse = string.match(vp_args, "Hitem:") and vp_args or select(2, GetItemInfo(testID))
                if not linkToUse then linkToUse = GetSafeItemLink(testID) end
                if linkToUse then
                    itemData = PNNSIM_BuildItemData(testID, linkToUse)
                end
            end

            local cleanText = string.match(vp_args, "%[(.-)%]") or vp_args
            cleanText = string.lower(strtrim(string.gsub(cleanText, "^%*(.*)%*$", "%1")))

            PNNSIM_Print("Search Results for Profile '" .. pDisp .. "':")
            local foundAny = false

            local function CheckList(listName, list)
                for _, entry in ipairs(list) do
                    local matched = false
                    
                    if itemData and PNNSIM_IsItemInList(itemData, {entry}) then
                        matched = true
                    else
                        local entryValStr = string.lower(tostring(entry.value))
                        if (entry.type == "exact" or entry.type == "match" or entry.type == "filter") and string.find(entryValStr, cleanText, 1, true) then
                            matched = true
                        elseif entry.type == "id" then
                            local eName = GetItemInfo(entry.value)
                            if not eName then
                                local fallbackLink = GetSafeItemLink(entry.value)
                                eName = string.match(fallbackLink, "%[(.-)%]") or ("Item ID " .. entry.value)
                            end
                            if eName and string.find(string.lower(eName), cleanText, 1, true) then
                                matched = true
                            end
                        end
                    end

                    if matched then
                        PNNSIM_Print("  [" .. string.upper(listName) .. "] [ID: " .. entry.listid .. "] " .. FormatListEntry(entry))
                        foundAny = true
                    end
                end
            end

            CheckList("keep", profile.keep)
            CheckList("sell", profile.sell)

            if not foundAny then
                PNNSIM_Print("  No matching rules found.")
            end
            return
        elseif vp_subcmd == "enable" or vp_subcmd == "activate" then
            PNNSIM_ConsoleConfig = PNNSIM_ConsoleConfig or {}
            PNNSIM_ConsoleConfig[charName .. ".console.activeprofile"] = pKey
            PNNSIM_ZoneMonitor_ManualActivation = true
            if PNNSIM_UpdateConsoleTitleBar then PNNSIM_UpdateConsoleTitleBar() end
            PNNSIM_Print("Profile '" .. pDisp .. "' activated.")
            return
        elseif vp_subcmd == "keep.list" or vp_subcmd == "sell.list" then
            local listType = string.match(vp_subcmd, "^([^%.]+)")
            local targetList = profile[listType]
            PNNSIM_Print("Profile '" .. pDisp .. "' " .. string.upper(listType) .. " list:")
            if #targetList == 0 then
                PNNSIM_Print("  (Empty)")
            else
                for _, entry in ipairs(targetList) do
                    PNNSIM_Print("  [ID: " .. entry.listid .. "] " .. FormatListEntry(entry))
                end
            end
            return
        elseif vp_subcmd == "keep.mod" or vp_subcmd == "sell.mod" then
            local listType = string.match(vp_subcmd, "^([^%.]+)")
            local targetID = string.match(vp_args, "^ID:(%d+)$")
            if not targetID then
                PrintErr("Invalid format. Use: vendorprofile.[name].["..listType.."].mod ID:#####")
                return
            end
            targetID = tonumber(targetID)
            
            local targetList = profile[listType]
            local foundEntry = nil
            for _, entry in ipairs(targetList) do
                if entry.listid == targetID then
                    foundEntry = entry
                    break
                end
            end
            
            if not foundEntry then
                PrintErr("Rule ID " .. targetID .. " not found in " .. listType .. " list.")
                return
            end
            
            local ruleStr = EntryToInputString(foundEntry)
            local fsStr = foundEntry.fs and " --fs" or ""
            local ptsStr = foundEntry.pts and " --pts" or ""
            local fullRule = ruleStr .. fsStr .. ptsStr
            
            PNNSIM_Print("Editing rule " .. targetID .. ": " .. fullRule)
            if PNNSIM_ConsoleInput and PNNSIM_ConsoleInput:IsVisible() then
                PNNSIM_ConsoleInput:SetText("vendorprofile." .. pKey .. "." .. listType .. ".mod.commit ID:" .. targetID .. " " .. fullRule)
                PNNSIM_ConsoleInput:SetFocus()
            end
            return
        elseif vp_subcmd == "keep.mod.commit" or vp_subcmd == "sell.mod.commit" then
            local listType = string.match(vp_subcmd, "^([^%.]+)")
            local targetIDStr, newRule = string.match(vp_args, "^ID:(%d+)%s+(.+)$")
            if not targetIDStr or not newRule then
                PrintErr("Invalid commit format.")
                return
            end
            local targetID = tonumber(targetIDStr)
            local targetList = profile[listType]
            
            local foundIndex = nil
            for i, entry in ipairs(targetList) do
                if entry.listid == targetID then
                    foundIndex = i
                    break
                end
            end
            
            if not foundIndex then
                PrintErr("Rule ID " .. targetID .. " not found for modification.")
                return
            end

            local forceSell = false
            local protectTempSell = false
            if listType == "keep" then
                local extracted_flags
                newRule, extracted_flags = ExtractFlags(newRule)
                forceSell = extracted_flags.fs or false
                protectTempSell = extracted_flags.pts or false
            end

            local iType, iVal = DetermineInputType(newRule)

            if iType == "filter" then
                local filterErr = PNNSIM_ValidateFilter(iVal)
                if filterErr then
                    PrintErr(filterErr)
                    return
                end
            end

            targetList[foundIndex].type = iType
            targetList[foundIndex].value = iVal
            targetList[foundIndex].fs = forceSell
            targetList[foundIndex].pts = protectTempSell

            local fsStr = forceSell and " [--fs]" or ""
            local ptsStr = protectTempSell and " [--pts]" or ""
            PNNSIM_Print("Modified Rule ID " .. targetID .. " -> " .. iType .. ": " .. tostring(iVal) .. fsStr .. ptsStr)
            return
        elseif vp_subcmd == "keep.add" or vp_subcmd == "sell.add" then
            if not vp_args or vp_args == "" then
                PrintErr("Missing arguments for add command.")
                return
            end
            local listType = string.match(vp_subcmd, "^([^%.]+)")
            
            local forceSell = false
            local protectTempSell = false
            if listType == "keep" then
                local extracted_flags
                vp_args, extracted_flags = ExtractFlags(vp_args)
                forceSell = extracted_flags.fs or false
                protectTempSell = extracted_flags.pts or false
            end

            local foundLinks = false
            for idStr in string.gmatch(vp_args, "Hitem:(%d+)") do
                foundLinks = true
                local itemID = tonumber(idStr)
                
                local isDup = false
                for _, entry in ipairs(profile[listType]) do
                    if entry.type == "id" and entry.value == itemID then
                        PNNSIM_Print("Duplicate skipped: " .. GetSafeItemLink(itemID))
                        isDup = true
                        break
                    end
                end
                
                if not isDup then
                    table.insert(profile[listType], { listid = profile.nextListID, type = "id", value = itemID, fs = forceSell, pts = protectTempSell })
                    local fsStr = forceSell and " [--fs]" or ""
                    local ptsStr = protectTempSell and " [--pts]" or ""
                    PNNSIM_Print("Added to " .. listType .. " (ListID: " .. profile.nextListID .. ") -> " .. GetSafeItemLink(itemID) .. fsStr .. ptsStr)
                    profile.nextListID = profile.nextListID + 1
                end
            end

            if not foundLinks then
                local iType, iVal = DetermineInputType(vp_args)

                if iType == "filter" then
                    local filterErr = PNNSIM_ValidateFilter(iVal)
                    if filterErr then
                        PrintErr(filterErr)
                        return
                    end
                end

                local isDup = false
                for _, entry in ipairs(profile[listType]) do
                    if entry.type == iType and tostring(entry.value) == tostring(iVal) then
                        PrintErr("Error: Rule already exists in " .. listType .. " (ListID: " .. entry.listid .. ")")
                        isDup = true
                        break
                    end
                end

                if not isDup then
                    table.insert(profile[listType], { listid = profile.nextListID, type = iType, value = iVal, fs = forceSell, pts = protectTempSell })
                    local fsStr = forceSell and " [--fs]" or ""
                    local ptsStr = protectTempSell and " [--pts]" or ""
                    PNNSIM_Print("Added to " .. listType .. " (ListID: " .. profile.nextListID .. ") -> " .. iType .. ": " .. tostring(iVal) .. fsStr .. ptsStr)
                    profile.nextListID = profile.nextListID + 1
                end
            end
            return
        elseif vp_subcmd == "zone.enable" then
            local activeKey = PNNSIM_ConsoleConfig and PNNSIM_ConsoleConfig[charName .. ".console.activeprofile"]
            if activeKey ~= pKey then
                PrintErr("Profile must be active before enabling zone monitoring.")
                return
            end
            local hasRealZones = false
            for _, z in ipairs(profile.zones or {}) do
                if z ~= "0000-0000-0000" then hasRealZones = true; break end
            end
            if not hasRealZones then
                PrintErr("Add at least one zone before enabling zone monitoring.")
                return
            end
            profile.zoneEnabled = true
            PNNSIM_Print("Zone monitoring ENABLED for profile '" .. pDisp .. "'.")
            return
        elseif vp_subcmd == "zone.disable" then
            profile.zoneEnabled = false
            PNNSIM_Print("Zone monitoring DISABLED for profile '" .. pDisp .. "'.")
            return
        elseif vp_subcmd == "zone.list" then
            profile.zones = profile.zones or {"0000-0000-0000"}
            local statusStr = profile.zoneEnabled and " [zone-enabled]" or " [zone-disabled]"
            PNNSIM_Print("Profile '" .. pDisp .. "' zones:" .. statusStr)
            for _, z in ipairs(profile.zones) do
                PNNSIM_Print("  " .. (z == "0000-0000-0000" and "VOID" or z))
            end
            return
        elseif vp_subcmd == "zone.register" then
            profile.zones = profile.zones or {"0000-0000-0000"}
            local zoneName = string.lower(strtrim(GetRealZoneText() or ""))
            if zoneName == "" then
                PrintErr("Could not determine current zone.")
                return
            end
            for _, z in ipairs(profile.zones) do
                if z == zoneName then
                    PrintErr("Zone '" .. zoneName .. "' is already registered.")
                    return
                end
            end
            -- Remove VOID sentinel if present when adding a real zone
            for i = #profile.zones, 1, -1 do
                if profile.zones[i] == "0000-0000-0000" then
                    table.remove(profile.zones, i)
                end
            end
            table.insert(profile.zones, zoneName)
            PNNSIM_Print("Zone '" .. zoneName .. "' registered to profile '" .. pDisp .. "'.")
            return
        elseif vp_subcmd == "zone.add" then
            if not vp_args or vp_args == "" then
                PrintErr("Missing zone name(s). Use: vendorprofile.[name].zone.add [zone,zone,...]")
                return
            end
            profile.zones = profile.zones or {"0000-0000-0000"}
            local added = 0
            for segment in string.gmatch(vp_args .. ",", "([^,]+),") do
                local zoneName = string.lower(strtrim(segment))
                if zoneName ~= "" then
                    local isDup = false
                    for _, z in ipairs(profile.zones) do
                        if z == zoneName then isDup = true; break end
                    end
                    if isDup then
                        PNNSIM_Print("Duplicate skipped: '" .. zoneName .. "'")
                    else
                        -- Remove VOID sentinel if present when adding a real zone
                        for i = #profile.zones, 1, -1 do
                            if profile.zones[i] == "0000-0000-0000" then
                                table.remove(profile.zones, i)
                            end
                        end
                        table.insert(profile.zones, zoneName)
                        PNNSIM_Print("Zone '" .. zoneName .. "' added to profile '" .. pDisp .. "'.")
                        added = added + 1
                    end
                end
            end
            if added == 0 and vp_args ~= "" then
                PrintErr("No new zones added.")
            end
            return
        elseif vp_subcmd == "zone.delete" then
            if not vp_args or vp_args == "" then
                PrintErr("Missing argument. Use: vendorprofile.[name].zone.delete [zone,...] or *")
                return
            end
            profile.zones = profile.zones or {"0000-0000-0000"}
            if strtrim(vp_args) == "*" then
                profile.zones = {"0000-0000-0000"}
                PNNSIM_Print("All zones cleared from profile '" .. pDisp .. "'. Set to VOID.")
            else
                local removed = 0
                for segment in string.gmatch(vp_args .. ",", "([^,]+),") do
                    local zoneName = string.lower(strtrim(segment))
                    if zoneName ~= "" then
                        for i = #profile.zones, 1, -1 do
                            if profile.zones[i] == zoneName then
                                table.remove(profile.zones, i)
                                removed = removed + 1
                                PNNSIM_Print("Zone '" .. zoneName .. "' removed from profile '" .. pDisp .. "'.")
                            end
                        end
                    end
                end
                if removed == 0 then
                    PrintErr("No matching zone(s) found to delete.")
                end
                if #profile.zones == 0 then
                    table.insert(profile.zones, "0000-0000-0000")
                    PNNSIM_Print("No zones remain. Profile '" .. pDisp .. "' set to VOID.")
                end
            end
            return
        elseif vp_subcmd == "keep.rem" or vp_subcmd == "sell.rem" then
            if not vp_args or vp_args == "" then
                PrintErr("Missing arguments for remove command.")
                return
            end
            local listType = string.match(vp_subcmd, "^([^%.]+)")
            local targetList = profile[listType]
            local removedCount = 0

            local useListID = string.match(vp_args, "^%-%-listid%s+(.+)$")
            local explicitID = not useListID and string.match(vp_args, "^ID:(%d+)$")

            if useListID or explicitID then
                local idsToRemove = {}
                if explicitID then
                    idsToRemove[tonumber(explicitID)] = true
                else
                    for idStr in string.gmatch(useListID, "%d+") do
                        idsToRemove[tonumber(idStr)] = true
                    end
                end
                for i = #targetList, 1, -1 do
                    if idsToRemove[targetList[i].listid] then
                        table.remove(targetList, i)
                        removedCount = removedCount + 1
                    end
                end
                PNNSIM_Print("Removed " .. removedCount .. " entry(s) from " .. listType .. " by ListID.")
            else
                local iType, iVal = DetermineInputType(vp_args)
                for i = #targetList, 1, -1 do
                    if targetList[i].type == iType and targetList[i].value == iVal then
                        table.remove(targetList, i)
                        removedCount = removedCount + 1
                    end
                end
                PNNSIM_Print("Removed " .. removedCount .. " exact matching entry(s) from " .. listType .. ".")
            end
            return
        end
    end

    if cmd_lower == "tool.getproperties" then
        local input = strtrim(args_part)
        if input == "" then
            PrintErr("Usage: tool.getproperties [itemlink or item ID]")
            return
        end

        local itemID, itemLink
        local idStr = string.match(input, "Hitem:(%d+)")
        if idStr then
            itemID = tonumber(idStr)
            itemLink = input
        elseif tonumber(input) then
            itemID = tonumber(input)
            itemLink = GetSafeItemLink(itemID)
        else
            PrintErr("Usage: tool.getproperties [itemlink or item ID]")
            return
        end

        local d = PNNSIM_BuildItemData(itemID, itemLink)
        if not d then
            PrintErr("Item not cached. Try opening it in a tooltip first.")
            return
        end

        PNNSIM_Print("--- Item Properties: " .. itemLink .. " ---")
        PNNSIM_Print("  ID        = " .. tostring(d.ID))
        PNNSIM_Print("  NAME      = " .. tostring(d.NAME))
        PNNSIM_Print("  QUALITY   = " .. tostring(d.QUALITY))
        PNNSIM_Print("  ILVL      = " .. tostring(d.ILVL))
        PNNSIM_Print("  REQLEVEL  = " .. tostring(d.REQLEVEL))
        PNNSIM_Print("  TYPE      = " .. tostring(d.TYPE))
        PNNSIM_Print("  SUBTYPE   = " .. tostring(d.SUBTYPE))
        PNNSIM_Print("  STACK     = " .. tostring(d.STACK))
        PNNSIM_Print("  EQUIPLOC  = " .. tostring(d.EQUIPLOC))
        PNNSIM_Print("  PRICE     = " .. tostring(d.PRICE))
        PNNSIM_Print("  INTOOLTIP = " .. tostring(d.INTOOLTIP))
        return
    end

    if cmd_lower == "tool.sortbags" then
        PNNSIM_SortBags()
        return
    end

    if cmd_lower == "tool.minimaprefresh" then
        local raw = strtrim(args_part)
        local val = tonumber(raw)
        if not val then
            PrintErr("Usage: tool.minimaprefresh [1/0] or tool.minimaprefresh [ms]")
            return
        end
        if val == 0 then
            if PNNSIM_MinimapRefresh_Disable then PNNSIM_MinimapRefresh_Disable() end
        elseif val == 1 then
            if PNNSIM_MinimapRefresh_Enable then PNNSIM_MinimapRefresh_Enable() end
        elseif val > 1 then
            if PNNSIM_MinimapRefresh_SetFrequency then
                PNNSIM_MinimapRefresh_SetFrequency(math.floor(val))
            end
        else
            PrintErr("Usage: tool.minimaprefresh [1/0] or tool.minimaprefresh [ms]")
        end
        return
    end

    if string.sub(cmd_lower, 1, 17) == "tool.simplemailer" then
        if PNNSIM_SimpleMailer_HandleCommand then
            PNNSIM_SimpleMailer_HandleCommand(PNNSIM_msg, PNNSIM_isConsole)
        end
        return
    end

    if not PNNSIM_isConsole then
        PNNSIM_Print("|cff00ff00[PNNSIM]|r Unknown command. Type /nps help for commands.")
    else
        local pName = UnitName("player")
        local userHex = (PNNSIM_ConsoleConfig and PNNSIM_ConsoleConfig[pName .. ".console.theme.consolecolor.user"]) or "00cc00"
        local errHex = (PNNSIM_ConsoleConfig and PNNSIM_ConsoleConfig[pName .. ".console.theme.consolecolor.textcolor.error"]) or "c70c15"
        PNNSIM_Print("|cFF" .. userHex .. "bash:|r |cFF" .. errHex .. tostring(PNNSIM_msg) .. ": command not found|r")
    end
end

SLASH_PNNSIM1 = "/nps"
SlashCmdList["PNNSIM"] = function(PNNSIM_msg)
    PNNSIM_ProcessCommand(PNNSIM_msg, false)
end