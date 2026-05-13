local mr_ticker = nil

local function mr_GetCharName()
    return UnitName("player")
end

local function mr_ReadConfig(key)
    if not PNNSIM_ConsoleConfig then return nil end
    return PNNSIM_ConsoleConfig[mr_GetCharName() .. "." .. key]
end

local function mr_WriteConfig(key, val)
    PNNSIM_ConsoleConfig = PNNSIM_ConsoleConfig or {}
    PNNSIM_ConsoleConfig[mr_GetCharName() .. "." .. key] = val
end

local function mr_GetFreqSeconds()
    local v = tonumber(mr_ReadConfig("tool.minimaprefresh.frequency")) or 100
    return v / 1000
end

local function mr_IsEnabled()
    return mr_ReadConfig("tool.minimaprefresh") == "1"
end

local function mr_StartTicker()
    if mr_ticker then mr_ticker:Cancel(); mr_ticker = nil end
    mr_ticker = C_Timer.NewTicker(mr_GetFreqSeconds(), function()
        if not IsMounted() then return end
        Minimap:SetZoom(Minimap:GetZoom())
    end)
end

local function mr_StopTicker()
    if mr_ticker then mr_ticker:Cancel(); mr_ticker = nil end
end

function PNNSIM_MinimapRefresh_Enable()
    mr_WriteConfig("tool.minimaprefresh", "1")
    mr_StartTicker()
    local freqMs = tonumber(mr_ReadConfig("tool.minimaprefresh.frequency")) or 100
    if PNNSIM_Console_Print then
        PNNSIM_Console_Print("Minimap refresh enabled (" .. freqMs .. " ms).")
    end
end

function PNNSIM_MinimapRefresh_Disable()
    mr_WriteConfig("tool.minimaprefresh", "0")
    mr_StopTicker()
    if PNNSIM_Console_Print then
        PNNSIM_Console_Print("Minimap refresh disabled.")
    end
end

function PNNSIM_MinimapRefresh_SetFrequency(freqMs)
    mr_WriteConfig("tool.minimaprefresh.frequency", tostring(freqMs))
    if PNNSIM_Console_Print then
        PNNSIM_Console_Print("Minimap refresh frequency set to " .. freqMs .. " ms.")
    end
    if mr_IsEnabled() and mr_ticker then
        mr_StartTicker()
    end
end

function PNNSIM_MinimapRefresh_RestartIfActive()
    if mr_IsEnabled() and mr_ticker then
        mr_StartTicker()
    end
end

local mr_frame = CreateFrame("Frame")
mr_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
mr_frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if mr_IsEnabled() then
            mr_StartTicker()
        end
    end
end)
