-- tools_zonemonitor.lua

local lastConflictZone = nil

local function EvaluateZone(fromZoneChange)
    local charName = UnitName("player")
    if not charName then return end

    local currentZone = string.lower(GetRealZoneText() or "")
    if currentZone == "" then return end

    local charProfiles = PNNSIM_Profiles and PNNSIM_Profiles[charName]
    if not charProfiles then return end

    PNNSIM_ConsoleConfig = PNNSIM_ConsoleConfig or {}
    local activeKey = PNNSIM_ConsoleConfig[charName .. ".console.activeprofile"] or "void"

    if fromZoneChange then
        PNNSIM_ZoneMonitor_ManualActivation = false
    end

    -- Collect zoneEnabled profiles whose zone list contains currentZone
    local matches = {}
    for pKey, profile in pairs(charProfiles) do
        if profile.zoneEnabled and profile.zones then
            for _, z in ipairs(profile.zones) do
                if z == currentZone then
                    matches[#matches + 1] = pKey
                    break
                end
            end
        end
    end

    if #matches == 1 then
        local matchKey = matches[1]
        if activeKey ~= matchKey then
            PNNSIM_ConsoleConfig[charName .. ".console.activeprofile"] = matchKey
            PNNSIM_ZoneMonitor_ManualActivation = false
            if PNNSIM_UpdateConsoleTitleBar then PNNSIM_UpdateConsoleTitleBar() end
            local dispName = charProfiles[matchKey].displayName or matchKey
            if PNNSIM_Console_Print then
                PNNSIM_Console_Print("Zone monitor: activated profile '" .. dispName .. "'.")
            end
        end
    elseif #matches >= 2 then
        if currentZone ~= lastConflictZone then
            lastConflictZone = currentZone
            if PNNSIM_Console_Print then
                PNNSIM_Console_Print("|cFFc70c15Zone monitor: conflict — multiple zone-enabled profiles share zone '" .. currentZone .. "'. Activate manually.|r")
            end
        end
    else
        -- 0 matches
        lastConflictZone = nil
        local shouldDeactivate = fromZoneChange or not PNNSIM_ZoneMonitor_ManualActivation
        if shouldDeactivate then
            -- Deactivate active profile if it has real zones (not VOID)
            if activeKey ~= "void" and charProfiles[activeKey] then
                local activeProfile = charProfiles[activeKey]
                local hasRealZones = false
                for _, z in ipairs(activeProfile.zones or {}) do
                    if z ~= "0000-0000-0000" then hasRealZones = true; break end
                end
                if hasRealZones then
                    PNNSIM_ConsoleConfig[charName .. ".console.activeprofile"] = "void"
                    activeKey = "void"
                    if PNNSIM_UpdateConsoleTitleBar then PNNSIM_UpdateConsoleTitleBar() end
                end
            end
            -- Fall back to default profile if set
            local defaultKey = string.lower(PNNSIM_ConsoleConfig[charName .. ".console.defaultprofile"] or "void")
            if defaultKey ~= "void" and charProfiles[defaultKey] and activeKey == "void" then
                PNNSIM_ConsoleConfig[charName .. ".console.activeprofile"] = defaultKey
                if PNNSIM_UpdateConsoleTitleBar then PNNSIM_UpdateConsoleTitleBar() end
                local dispName = charProfiles[defaultKey].displayName or defaultKey
                if PNNSIM_Console_Print then
                    PNNSIM_Console_Print("Zone monitor: no zone match — activated default profile '" .. dispName .. "'.")
                end
            end
        end
    end
end

PNNSIM_ZoneMonitor_ManualActivation = false

local PNNSIM_ZoneMonitorFrame = CreateFrame("Frame")
PNNSIM_ZoneMonitorFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
PNNSIM_ZoneMonitorFrame:RegisterEvent("PLAYER_LOGIN")

PNNSIM_ZoneMonitorFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.NewTicker(20, function() EvaluateZone(false) end)
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        EvaluateZone(true)
    end
end)
