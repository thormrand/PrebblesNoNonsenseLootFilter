-- farminvite.lua

-------------------------------------------------------------------------------
-- Config helpers
-------------------------------------------------------------------------------
local function GetConf(key, default)
    if not PNNSIM_ConsoleConfig then return default end
    local val = PNNSIM_ConsoleConfig[UnitName("player") .. "." .. key]
    if val == nil then return default end
    return tostring(val)
end

local function SetConf(key, value)
    if not PNNSIM_ConsoleConfig then return end
    PNNSIM_ConsoleConfig[UnitName("player") .. "." .. key] = tostring(value)
end

local function IsEnabled()
    return GetConf("tool.farminvite", "0") == "1"
end

local function Print(msg)
    if PNNSIM_Console_Print then
        PNNSIM_Console_Print("|cFFFFAA00[FarmInvite]|r " .. tostring(msg))
    end
end

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------
local lastSpamTime = 0

-------------------------------------------------------------------------------
-- Message building
-------------------------------------------------------------------------------
local function BuildMessage()
    local customMsg = GetConf("tool.farminvite.spam.message", "auto")
    if customMsg ~= "auto" then
        return customMsg
    end

    local autokick = GetConf("tool.farminvite.autokick", "0")
    local level    = GetConf("tool.farminvite.autokick.level", "80")
    local torment  = GetConf("tool.farminvite.torment", "3")
    local safeword = GetConf("tool.farminvite.safeword", "inv")

    if autokick == "1" then
        return "Farming/boosting in IC until I'm tired. Autokick at " .. level .. ". Requirements: don't be " .. level .. ", be in HC" .. torment .. " & have flying. Tipping is not needed but will redistribute profits to new players! /w with " .. safeword .. " to get autoinvited."
    else
        return "Farming/boosting in IC until I'm tired. Requirements: don't be 80 be in HC" .. torment .. " & have flying. Tipping is not needed but will redistribute profits to new players! /w with " .. safeword .. " to get autoinvited."
    end
end

-------------------------------------------------------------------------------
-- SendSpam
-------------------------------------------------------------------------------
function PNNSIM_FarmInvite_SendSpam()
    if not IsEnabled() then return end

    local msg = BuildMessage()

    local testingOnly = GetConf("tool.farminvite.spam.testingonly", "0")
    if testingOnly == "1" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[FarmInvite]|r [Preview] " .. msg)
        return
    end

    local prevention = tonumber(GetConf("tool.farminvite.spam.prevention", "60")) or 60
    local elapsed = GetTime() - lastSpamTime
    if lastSpamTime > 0 and elapsed < prevention then
        local remaining = math.ceil(prevention - elapsed)
        Print("Spam prevention: " .. remaining .. " seconds remaining.")
        return
    end

    local channels = GetConf("tool.farminvite.spam.channels", "6,g")
    for token in string.gmatch(channels .. ",", "([^,]+),") do
        token = strtrim(token)
        local n = tonumber(token)
        if n then
            local chanName = GetChannelName(n)
            if chanName and chanName ~= "" then
                SendChatMessage(msg, "CHANNEL", nil, n)
            else
                Print("Channel " .. token .. " not joined — skipped.")
            end
        elseif token == "g" then
            if IsInGuild() then
                SendChatMessage(msg, "GUILD")
            else
                Print("Not in a guild — 'g' channel skipped.")
            end
        elseif token == "p" then
            SendChatMessage(msg, "PARTY")
        elseif token == "r" then
            SendChatMessage(msg, "RAID")
        elseif token == "s" then
            SendChatMessage(msg, "SAY")
        elseif token == "y" then
            SendChatMessage(msg, "YELL")
        end
    end

    lastSpamTime = GetTime()
end

-------------------------------------------------------------------------------
-- Ignore list
-------------------------------------------------------------------------------
local IGNORE_KEY = "tool.farminvite.autokick.ignoreplayerlist"

local function GetIgnoreList()
    local raw = GetConf(IGNORE_KEY, "")
    local names = {}
    if raw ~= "" then
        for name in string.gmatch(raw .. ",", "([^,]+),") do
            local n = strtrim(name)
            if n ~= "" then table.insert(names, n) end
        end
    end
    return names
end

local function SaveIgnoreList(names)
    SetConf(IGNORE_KEY, table.concat(names, ","))
end

function PNNSIM_FarmInvite_IgnoreAdd(name)
    local lower = string.lower(strtrim(name))
    if lower == "" then Print("Missing name."); return end
    local names = GetIgnoreList()
    for _, n in ipairs(names) do
        if n == lower then
            Print(lower .. " is already in the ignore list.")
            return
        end
    end
    table.insert(names, lower)
    SaveIgnoreList(names)
    Print(lower .. " added to autokick ignore list.")
end

function PNNSIM_FarmInvite_IgnoreRem(name)
    local lower = string.lower(strtrim(name))
    if lower == "" then Print("Missing name."); return end
    local names = GetIgnoreList()
    local removed = false
    for i = #names, 1, -1 do
        if names[i] == lower then
            table.remove(names, i)
            removed = true
        end
    end
    if removed then
        SaveIgnoreList(names)
        Print(lower .. " removed from autokick ignore list.")
    else
        Print(lower .. " not found in autokick ignore list.")
    end
end

function PNNSIM_FarmInvite_IgnoreList()
    local names = GetIgnoreList()
    if #names == 0 then
        Print("Autokick ignore list: Empty.")
        return
    end
    Print("Autokick ignore list:")
    for i, n in ipairs(names) do
        Print("  " .. i .. ". " .. n)
    end
end

-------------------------------------------------------------------------------
-- Minimap icon
-- Parented to Minimap, positioned on the edge using angle math.
-- Left-drag moves it; left-click sends spam.
-------------------------------------------------------------------------------
local minimapBtn
local minimapAngle = 220
local isDragging   = false

local function UpdateMinimapPos()
    local angle = math.rad(minimapAngle)
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(angle), 80 * math.sin(angle))
end

function PNNSIM_FarmInvite_RefreshIcon()
    if not minimapBtn then return end
    if IsEnabled() and GetConf("tool.farminvite.spam.icon", "1") == "1" then
        minimapBtn:Show()
    else
        minimapBtn:Hide()
    end
end

local function BuildMinimapIcon()
    if minimapBtn then return end

    local saved = tonumber(GetConf("tool.farminvite.spam.iconangle", "220"))
    if saved then minimapAngle = saved end

    local btn = CreateFrame("Frame", "PNNSFI_MinimapBtn", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Minimap\\Tracking\\Mailbox")
    icon:SetAlpha(0.85)

    local hi = btn:CreateTexture(nil, "HIGHLIGHT")
    hi:SetAllPoints()
    hi:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hi:SetBlendMode("ADD")

    btn:SetScript("OnDragStart", function(self)
        isDragging = true
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale  = UIParent:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
            UpdateMinimapPos()
        end)
    end)

    btn:SetScript("OnDragStop", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
        SetConf("tool.farminvite.spam.iconangle", tostring(math.floor(minimapAngle)))
    end)

    btn:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and not isDragging then
            PNNSIM_FarmInvite_SendSpam()
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cFFFFAA00Farm Invite|r")
        GameTooltip:AddLine("|cffaaaaaaLeft-click to send spam|r")
        GameTooltip:AddLine("|cffaaaaaaaDrag to reposition|r")
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    minimapBtn = btn
    UpdateMinimapPos()
    PNNSIM_FarmInvite_RefreshIcon()
end

-------------------------------------------------------------------------------
-- Whisper invite
-------------------------------------------------------------------------------
local function HandleWhisper(msg, author)
    if not IsEnabled() then return end
    local safeword = GetConf("tool.farminvite.safeword", "inv")
    if string.find(string.lower(msg), string.lower(safeword), 1, true) == nil then return end
    local sender = author and author:match("^([^%-]+)") or author
    if not sender or sender == "" then return end
    local lowerSender = string.lower(sender)
    local ignore = GetIgnoreList()
    for _, n in ipairs(ignore) do
        if n == lowerSender then return end
    end
    InviteUnit(sender)
    Print("Invited " .. sender .. " (safeword match).")
end

-------------------------------------------------------------------------------
-- PLAYER_LOGIN wiring
-------------------------------------------------------------------------------
local loaderFrame = CreateFrame("Frame", "PNNSFI_Loader", UIParent)
-------------------------------------------------------------------------------
-- Raid conversion poller
-------------------------------------------------------------------------------
local raidPollElapsed = 0
local raidPollFrame = CreateFrame("Frame", "PNNSFI_RaidPoller", UIParent)
raidPollFrame:SetScript("OnUpdate", function(self, elapsed)
    raidPollElapsed = raidPollElapsed + elapsed
    if raidPollElapsed < 1 then return end
    raidPollElapsed = 0
    if not IsEnabled() then return end
    if GetConf("tool.farminvite.raid", "1") ~= "1" then return end
    if GetNumPartyMembers() > 0 and GetNumRaidMembers() == 0 and UnitIsPartyLeader("player") then
        ConvertToRaid()
        self:SetScript("OnUpdate", nil)
    end
end)

loaderFrame:RegisterEvent("PLAYER_LOGIN")
loaderFrame:RegisterEvent("CHAT_MSG_WHISPER")
loaderFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_WHISPER" then
        HandleWhisper(...)
        return
    end
    self:UnregisterEvent("PLAYER_LOGIN")

    local ok, err = pcall(BuildMinimapIcon)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[FarmInvite] minimap error: " .. tostring(err) .. "|r")
    end

    -- Portrait click: hook PlayerFrame, fire only when cursor is inside portrait bounds.
    if PlayerFrame and PlayerPortrait then
        local ok2, err2 = pcall(function()
            PlayerFrame:HookScript("OnMouseDown", function(self, button)
                if button ~= "LeftButton" or not IsEnabled() then return end
                local px, py = PlayerPortrait:GetCenter()
                if not px then return end
                local pw2 = PlayerPortrait:GetWidth()  / 2
                local ph2 = PlayerPortrait:GetHeight() / 2
                local cx, cy = GetCursorPosition()
                local scale  = UIParent:GetEffectiveScale()
                cx, cy = cx / scale, cy / scale
                if cx >= px - pw2 and cx <= px + pw2 and cy >= py - ph2 and cy <= py + ph2 then
                    PNNSIM_FarmInvite_SendSpam()
                end
            end)
        end)
        if not ok2 then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[FarmInvite] portrait hook error: " .. tostring(err2) .. "|r")
        end
    end
end)
