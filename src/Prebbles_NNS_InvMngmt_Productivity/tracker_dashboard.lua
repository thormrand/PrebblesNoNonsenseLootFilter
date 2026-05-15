-- tracker_dashboard.lua
-- Prebbles_NNS_InvMngmt_Productivity

local DASH_FONT          = "Interface\\AddOns\\Prebbles_NNS_InvMngmt\\assets\\fonts\\VCR_OSD_MONO_1.001.ttf"
local DASH_FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"

local dashChatFrame = nil
local dashOverlay   = nil
local dashText      = nil
local dashReset     = nil

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function ApplyDashFont(obj, size, flags)
    local ok = pcall(function() obj:SetFont(DASH_FONT, size, flags) end)
    if not ok then obj:SetFont(DASH_FALLBACK_FONT, size, flags) end
end

local function FormatTime(secs)
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = math.floor(secs % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function FormatTimeFull(secs)
    local d = math.floor(secs / 86400)
    local h = math.floor((secs % 86400) / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = math.floor(secs % 60)
    if d > 0 then
        return string.format("%dd %02d:%02d:%02d", d, h, m, s)
    end
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function FormatCoin(copper)
    copper = math.max(0, math.floor(copper or 0))
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then
        return string.format("%dg %02ds %02dc", g, s, c)
    elseif s > 0 then
        return string.format("%ds %02dc", s, c)
    else
        return string.format("%dc", c)
    end
end

local function PadLeft(str, width)
    local pad = width - #str
    if pad <= 0 then return str end
    return string.rep(" ", pad) .. str
end

local function FormatAsh(n)
    n = math.max(0, math.floor(tonumber(n) or 0))
    if n >= 1000000000 then
        return string.format("%.2fb", n / 1000000000)
    elseif n >= 1000000 then
        return string.format("%.2fm", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.2fk", n / 1000)
    else
        return string.format("%d", n)
    end
end

local function ParseMoneyMessage(msg)
    local lower = msg:lower()
    local g = tonumber(lower:match("(%d+) gold"))   or 0
    local s = tonumber(lower:match("(%d+) silver")) or 0
    local c = tonumber(lower:match("(%d+) copper")) or 0
    return g * 10000 + s * 100 + c
end

local function IsDashboardEnabled()
    if not PNNSIM_ConsoleConfig then return false end
    return PNNSIM_ConsoleConfig[UnitName("player") .. ".tracker.dashboard"] == "1"
end

local function SetOverlayShown(shown)
    if not dashOverlay then return end
    if shown then dashOverlay:Show() else dashOverlay:Hide() end
end

local dashTabHookInstalled = false
local function EnsureTabHook()
    if dashTabHookInstalled then return end
    dashTabHookInstalled = true
    hooksecurefunc("FCF_Tab_OnClick", function(tab)
        if not dashChatFrame or not IsDashboardEnabled() then return end
        local trackerTab = _G[dashChatFrame:GetName() .. "Tab"]
        SetOverlayShown(trackerTab ~= nil and tab == trackerTab)
    end)
end

-- ── Tab management ────────────────────────────────────────────────────────────

local function StripChatFrame(cf)
    ChatFrame_RemoveAllMessageGroups(cf)
    cf:EnableMouseWheel(false)
    cf:EnableMouse(false)
    local sb = _G[cf:GetName() .. "ScrollBar"]
    if sb then sb:Hide() end
end

local function EnsureTrackerTab()
    -- Fast path: already have a valid frame
    if dashChatFrame then
        local tab = _G[dashChatFrame:GetName() .. "Tab"]
        if tab and tab:GetText() == "Tracker" then
            return  -- frame exists; let WoW's dock system own its visibility
        end
        dashChatFrame = nil  -- stale reference, reset and re-scan
    end

    -- Scan existing frames for a Tracker tab
    for i = 1, 20 do
        local cf  = _G["ChatFrame" .. i]
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if cf and tab and tab:GetText() == "Tracker" then
            dashChatFrame = cf
            StripChatFrame(cf)
            if dashOverlay then dashOverlay:SetParent(cf) end
            return
        end
    end

    -- Not found — create it once; FCF_OpenTemporaryWindow already shows it
    local newFrame = FCF_OpenTemporaryWindow("SAY")
    if not newFrame then return end

    StripChatFrame(newFrame)
    FCF_SetWindowName(newFrame, "Tracker")

    dashChatFrame = newFrame
    if dashOverlay then dashOverlay:SetParent(dashChatFrame) end
end

-- ── Overlay ───────────────────────────────────────────────────────────────────

local function CreateOverlay()
    if dashOverlay then return end

    dashOverlay = CreateFrame("Frame", "PNNSIM_DashOverlay", dashChatFrame)
    dashOverlay:SetPoint("TOPLEFT", dashChatFrame, "TOPLEFT", 0, 2)
    dashOverlay:SetSize(32, 32)  -- placeholder; ticker will correct once frame is laid out
    dashOverlay:SetFrameStrata("HIGH")
    dashOverlay:SetFrameLevel(dashChatFrame:GetFrameLevel() + 10)
    dashOverlay:EnableMouse(true)

    local bg = dashOverlay:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0, 0, 0, 0.9)

    dashText = dashOverlay:CreateFontString(nil, "OVERLAY")
    dashText:SetPoint("TOPLEFT",     dashOverlay, "TOPLEFT",     3,  0)
    dashText:SetPoint("BOTTOMRIGHT", dashOverlay, "BOTTOMRIGHT", 0, 0)
    dashText:SetJustifyH("LEFT")
    dashText:SetJustifyV("TOP")
    ApplyDashFont(dashText, 10, "OUTLINE")

    -- Reset button
    dashReset = CreateFrame("Button", "PNNSIM_DashReset", dashOverlay)
    dashReset:SetSize(100, 14)
    dashReset:SetPoint("BOTTOMRIGHT", dashOverlay, "BOTTOMRIGHT", -3, 3)
    dashReset:EnableMouse(true)

    local resetLabel = dashReset:CreateFontString(nil, "OVERLAY")
    resetLabel:SetAllPoints()
    resetLabel:SetJustifyH("RIGHT")
    ApplyDashFont(resetLabel, 10, "OUTLINE")
    resetLabel:SetText("|cFFFF6666[Reset Session]|r")

    dashReset:SetScript("OnEnter", function()
        resetLabel:SetText("|cFFFF9999[Reset Session]|r")
    end)
    dashReset:SetScript("OnLeave", function()
        resetLabel:SetText("|cFFFF6666[Reset Session]|r")
    end)
    dashReset:SetScript("OnClick", function()
        PNNSIM_SessionTracker.sold          = 0
        PNNSIM_SessionTracker.deleted       = 0
        PNNSIM_SessionTracker.soldItems     = 0
        PNNSIM_SessionTracker.deletedItems  = 0
        PNNSIM_SessionTracker.looted        = 0
        PNNSIM_SessionTracker.kills         = 0
        PNNSIM_SessionTracker.ashes         = 0
        PNNSIM_SessionTracker.startTime     = GetTime()
        if PNNSIM_CharData then
            PNNSIM_CharData["tracker.session.sold"]         = nil
            PNNSIM_CharData["tracker.session.deleted"]      = nil
            PNNSIM_CharData["tracker.session.soldItems"]    = nil
            PNNSIM_CharData["tracker.session.deletedItems"] = nil
            PNNSIM_CharData["tracker.session.looted"]       = nil
            PNNSIM_CharData["tracker.session.kills"]        = nil
            PNNSIM_CharData["tracker.session.ashes"]        = nil
            PNNSIM_CharData["tracker.session.elapsed"]      = nil
        end
    end)

    dashOverlay:Hide()  -- hidden until the user clicks the Tracker tab
    EnsureTabHook()
end

-- ── Display ───────────────────────────────────────────────────────────────────

-- Column layout (monospace, [ at position 12 for data rows):
-- Genesis1d 04:32:12
-- Sold (%5d) [%coin]      label(5) + (%5d) + space + [
-- Loot (%5d) [%coin]
-- Del  (%5d) [%coin]
-- Session00:12:34
-- Sold (%5d) [%coin]
-- Loot (%5d) [%coin]
-- Del  (%5d) [%coin]
-- Tot        +[%coin]     Tot(3) + 8sp + sign(1) + [
-- GPH         [%coin]     GPH(3) + 9sp + [
local function UpdateDashboard()
    if not dashText then return end

    local sessElapsed = math.max(1, GetTime() - (PNNSIM_SessionTracker.startTime or GetTime()))

    local genBaseTime  = (PNNSIM_CharData and PNNSIM_CharData["tracker.genesis.time"])         or 0
    local genSold      = (PNNSIM_CharData and PNNSIM_CharData["tracker.genesis.sold"])         or 0
    local genDel       = (PNNSIM_CharData and PNNSIM_CharData["tracker.genesis.deleted"])      or 0
    local genSoldItems = (PNNSIM_CharData and PNNSIM_CharData["tracker.genesis.item.sold"])    or 0
    local genDelItems  = (PNNSIM_CharData and PNNSIM_CharData["tracker.genesis.item.deleted"]) or 0
    local genLooted    = (PNNSIM_CharData and PNNSIM_CharData["tracker.genesis.looted"])       or 0
    local genKills     = (PNNSIM_CharData and PNNSIM_CharData["tracker.genesis.kills"])        or 0

    local sessSold      = PNNSIM_SessionTracker.sold         or 0
    local sessDel       = PNNSIM_SessionTracker.deleted      or 0
    local sessSoldItems = PNNSIM_SessionTracker.soldItems    or 0
    local sessDelItems  = PNNSIM_SessionTracker.deletedItems or 0
    local sessLooted    = PNNSIM_SessionTracker.looted       or 0
    local sessKills     = PNNSIM_SessionTracker.kills        or 0

    local genAshes  = (PNNSIM_CharData and PNNSIM_CharData["tracker.genesis.ashes"]) or 0
    local sessAshes = PNNSIM_SessionTracker.ashes or 0

    local sessNet = sessSold + sessLooted - sessDel
    local sessGPH = math.abs(sessNet) / sessElapsed * 3600

    local genNet  = genSold + genLooted - genDel
    local sessHrs = sessElapsed / 3600
    local sessAPH = (sessHrs > 0) and (sessAshes / sessHrs) or 0

    -- Quantity strings
    local qGenSold   = tostring(genSoldItems)
    local qGenDel    = tostring(genDelItems)
    local qGenKills  = tostring(genKills)
    local qSessSold  = tostring(sessSoldItems)
    local qSessDel   = tostring(sessDelItems)
    local qSessKills = tostring(sessKills)

    -- Currency strings (raw, unpadded)
    local cGenSold   = FormatCoin(genSold)
    local cGenLoot   = FormatCoin(genLooted)
    local cGenDel    = FormatCoin(genDel)
    local cGenNet    = FormatCoin(math.abs(genNet))
    local cGenAsh    = FormatAsh(genAshes)
    local cSessSold  = FormatCoin(sessSold)
    local cSessLoot  = FormatCoin(sessLooted)
    local cSessDel   = FormatCoin(sessDel)
    local cSessNet   = FormatCoin(math.abs(sessNet))
    local cSessGPH   = FormatCoin(sessGPH)
    local cSessAsh   = FormatAsh(sessAshes)
    local cSessAPH   = FormatAsh(sessAPH)

    -- Max width for quantity column
    local qw = 0
    for _, q in ipairs({qGenSold, "N/A", qGenDel, qGenKills,
                        qSessSold, "N/A", qSessDel, qSessKills}) do
        if #q > qw then qw = #q end
    end

    -- Max width for currency column
    local cw = 0
    for _, c in ipairs({cGenSold, cGenLoot, cGenDel, cGenNet, cGenAsh,
                        cSessSold, cSessLoot, cSessDel, cSessNet,
                        cSessGPH, cSessAsh, cSessAPH}) do
        if #c > cw then cw = #c end
    end

    local G   = "|cFFFFD700"
    local GR  = "|cFF888888"
    local LB  = "|cFFCCCCCC"
    local R   = "|r"
    local emp = string.rep(" ", qw)

    dashText:SetText(
        G.."Genesis "..R..GR..FormatTimeFull(genBaseTime + sessElapsed)..R.."\n"..
        LB.."Sold  "..PadLeft(qGenSold,  qw).."  "..PadLeft(cGenSold, cw)..R.."\n"..
        LB.."Loot  "..PadLeft("N/A",     qw).."  "..PadLeft(cGenLoot, cw)..R.."\n"..
        LB.."Del   "..PadLeft(qGenDel,   qw).."  "..PadLeft(cGenDel,  cw)..R.."\n"..
        LB.."Tot   "..emp               .."  "..PadLeft(cGenNet,  cw)..R.."\n"..
        LB.."Ash   "..PadLeft(qGenKills, qw).."  "..PadLeft(cGenAsh,  cw)..R.."\n"..
        "\n"..
        G.."Session "..R..GR..FormatTime(sessElapsed)..R.."\n"..
        LB.."Sold  "..PadLeft(qSessSold,  qw).."  "..PadLeft(cSessSold, cw)..R.."\n"..
        LB.."Loot  "..PadLeft("N/A",      qw).."  "..PadLeft(cSessLoot, cw)..R.."\n"..
        LB.."Del   "..PadLeft(qSessDel,   qw).."  "..PadLeft(cSessDel,  cw)..R.."\n"..
        LB.."Tot   "..emp                .."  "..PadLeft(cSessNet,  cw)..R.."\n"..
        LB.."GPH   "..emp                .."  "..PadLeft(cSessGPH,  cw)..R.."\n"..
        LB.."Ash   "..PadLeft(qSessKills, qw).."  "..PadLeft(cSessAsh,  cw)..R.."\n"..
        LB.."APH   "..emp                .."  "..PadLeft(cSessAPH,  cw)..R
    )
end

function PNNSIM_UpdateTrackerUI()
    UpdateDashboard()
end

-- ── Events ────────────────────────────────────────────────────────────────────

local PNNS_PrevMoney        = nil
local PNNS_InVendorSession  = false

local dashEvents = CreateFrame("Frame")
dashEvents:RegisterEvent("PLAYER_LOGIN")
dashEvents:RegisterEvent("PLAYER_MONEY")
dashEvents:RegisterEvent("MERCHANT_SHOW")
dashEvents:RegisterEvent("MERCHANT_CLOSED")
dashEvents:RegisterEvent("CHAT_MSG_ADDON")
dashEvents:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

local PNNSIM_TaggedUnits = {}
local PNNSIM_PendingAshKills = {}  -- queue of GetTime() timestamps awaiting an ash delta
local PNNSIM_PendingKillWindow = 5 -- seconds to wait for ash event after death

dashEvents:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
    local msg = arg1
    if event == "PLAYER_LOGIN" then
        if PNNSIM_CharData then
            PNNSIM_CharData["tracker.genesis.looted"] =
                PNNSIM_CharData["tracker.genesis.looted"] or 0
            PNNSIM_CharData["tracker.genesis.kills"] =
                PNNSIM_CharData["tracker.genesis.kills"] or 0
        end

        PNNS_PrevMoney = GetMoney()

        if IsDashboardEnabled() then
            EnsureTrackerTab()
            if dashChatFrame and not dashOverlay then
                CreateOverlay()
            end
        end

    elseif event == "MERCHANT_SHOW" then
        PNNS_InVendorSession = true

    elseif event == "MERCHANT_CLOSED" then
        PNNS_InVendorSession = false
        PNNS_PrevMoney = GetMoney()

    elseif event == "PLAYER_MONEY" then
        local current = GetMoney()
        if PNNS_PrevMoney and not PNNS_InVendorSession then
            local delta = current - PNNS_PrevMoney
            if delta > 0 then
                PNNSIM_SessionTracker.looted = (PNNSIM_SessionTracker.looted or 0) + delta
                PNNSIM_TempSellLastKillTime = GetTime()
                if PNNSIM_CharData then
                    PNNSIM_CharData["tracker.genesis.looted"] =
                        (PNNSIM_CharData["tracker.genesis.looted"] or 0) + delta
                end
            end
        end
        PNNS_PrevMoney = current

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local subEvent     = arg2
        local sourceFlags  = arg5
        local destGUID     = arg6
        local destFlags    = arg8
        if subEvent == "UNIT_DIED" then
            if destGUID and PNNSIM_TaggedUnits[destGUID] then
                PNNSIM_TaggedUnits[destGUID] = nil
                if destFlags and bit.band(destFlags, 0x00000040) ~= 0 then
                    table.insert(PNNSIM_PendingAshKills, GetTime())
                end
            end
        elseif destGUID and sourceFlags and bit.band(sourceFlags, 0x00000007) ~= 0 then
            -- Source is mine, party, or raid — tag the unit so we credit its death
            PNNSIM_TaggedUnits[destGUID] = true
        end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, payload = arg1, arg2
        if prefix ~= "AAM0x9" or not payload or payload == "" then return end
        local evtStr, body = payload:match("^(%d+)\t(.*)$")
        if not evtStr or tonumber(evtStr) ~= 13 then return end
        local sp = tonumber(body:match("^([^;]+)"))
        if not sp then return end
        if PNNSIM_AshTrackerLastSP == nil then
            PNNSIM_AshTrackerLastSP = sp
            return
        end
        local delta = sp - PNNSIM_AshTrackerLastSP
        PNNSIM_AshTrackerLastSP = sp
        if delta <= 0 then return end
        PNNSIM_SessionTracker.ashes = (PNNSIM_SessionTracker.ashes or 0) + delta
        if PNNSIM_CharData then
            PNNSIM_CharData["tracker.genesis.ashes"] =
                (PNNSIM_CharData["tracker.genesis.ashes"] or 0) + delta
        end
        -- One ash event = one kill credit (server emits per ash-awarding kill).
        -- Expire stale pending deaths, then pop the oldest still in window.
        local now = GetTime()
        while PNNSIM_PendingAshKills[1]
              and (now - PNNSIM_PendingAshKills[1]) > PNNSIM_PendingKillWindow do
            table.remove(PNNSIM_PendingAshKills, 1)
        end
        if PNNSIM_PendingAshKills[1] then
            table.remove(PNNSIM_PendingAshKills, 1)
            PNNSIM_SessionTracker.kills = (PNNSIM_SessionTracker.kills or 0) + 1
            PNNSIM_TempSellLastKillTime = now
            if PNNSIM_CharData then
                PNNSIM_CharData["tracker.genesis.kills"] =
                    (PNNSIM_CharData["tracker.genesis.kills"] or 0) + 1
            end
        end
    end
end)

-- ── Ticker ────────────────────────────────────────────────────────────────────

local dashTicker = CreateFrame("Frame")
dashTicker:SetScript("OnUpdate", function(self, elapsed)
    self.timer = (self.timer or 0) + elapsed
    if self.timer < 0.5 then return end
    self.timer = 0

    if not IsDashboardEnabled() then
        if dashOverlay and dashOverlay:IsShown() then dashOverlay:Hide() end
        return
    end

    EnsureTrackerTab()
    if dashChatFrame and not dashOverlay then
        CreateOverlay()
    end
    if dashOverlay and dashChatFrame then
        local w, h = dashChatFrame:GetWidth(), dashChatFrame:GetHeight()
        if w > 1 and h > 1 then
            dashOverlay:SetSize(w + 3, 195)
        end
    end
    if dashOverlay and dashOverlay:IsShown() then
        UpdateDashboard()
    end
end)
