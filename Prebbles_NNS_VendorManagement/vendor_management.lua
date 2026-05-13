-- vendor_management.lua
--
-- Companion lifecycle logic adapted from AutoLoot v4.0
-- by Veronica-Vasilieva (https://github.com/Veronica-Vasilieva/AutoLoot)
-- Used with attribution under the project's open-source license.

-------------------------------------------------------------------------------
-- Config helpers
-------------------------------------------------------------------------------
local function GetConf(key, default)
    if not PNNSIM_ConsoleConfig then return default end
    local val = PNNSIM_ConsoleConfig[UnitName("player") .. "." .. key]
    if val == nil then return default end
    return tostring(val)
end

local function IsEnabled()
    return GetConf("tool.vendormanagement", "0") == "1"
end

local function GetLooterName()
    return GetConf("tool.vendormanagement.lootername", "Greedy Scavenger")
end

local function GetVendorName()
    return GetConf("tool.vendormanagement.vendorname", "Goblin Merchant")
end

local function GetThreshold()
    return tonumber(GetConf("tool.vendormanagement.threshold", "5")) or 5
end

local function SetConf(key, value)
    if not PNNSIM_ConsoleConfig then return end
    PNNSIM_ConsoleConfig[UnitName("player") .. "." .. key] = tostring(value)
end

-------------------------------------------------------------------------------
-- Utility
-------------------------------------------------------------------------------
local function Print(msg)
    PNNSIM_Console_Print("|cFF00CCFF[VendorMgmt]|r " .. tostring(msg))
end

local function GetFreeSlots()
    local free = 0
    for bag = 0, 4 do
        local f = GetContainerNumFreeSlots(bag)
        if f then free = free + f end
    end
    return free
end

-------------------------------------------------------------------------------
-- Timer helper (C_Timer unavailable in WotLK 3.3.5a)
-- Adapted from AutoLoot v4.0 by Veronica-Vasilieva
-------------------------------------------------------------------------------
local pendingTimers = {}
local timerFrame = CreateFrame("Frame")
timerFrame:SetScript("OnUpdate", function(self, elapsed)
    if #pendingTimers == 0 then return end
    for i = #pendingTimers, 1, -1 do
        local t = pendingTimers[i]
        t.remaining = t.remaining - elapsed
        if t.remaining <= 0 then
            table.remove(pendingTimers, i)
            t.fn()
        end
    end
end)

local function After(delay, fn)
    table.insert(pendingTimers, { remaining = delay, fn = fn })
end

-------------------------------------------------------------------------------
-- Companion logic
-- Adapted from AutoLoot v4.0 by Veronica-Vasilieva
-------------------------------------------------------------------------------
local MAX_COMPANION_DISTANCE = 5

local function FindCompanion(name)
    if not name or name == "" then return nil, false end
    local nameLower = name:lower()
    local n = GetNumCompanions("CRITTER")
    for i = 1, n do
        local _, cName, _, _, summoned = GetCompanionInfo("CRITTER", i)
        if cName and cName:lower() == nameLower then
            return i, (summoned == 1 or summoned == true)
        end
    end
    return nil, false
end

PNNSIVM_SummoningLock = false

local function SummonWithVerify(name, onSuccess, onFail)
    local idx, active = FindCompanion(name)
    if not idx then
        onFail("notfound")
        return
    end
    if active then
        onSuccess()
        return
    end

    local attempts = 0
    local channelWaited = 0
    PNNSIVM_SummoningLock = true

    local function tryOnce()
        attempts = attempts + 1

        local function waitIfChanneling(thenSummon)
            local ok, channeling, casting = pcall(function()
                return UnitChannelInfo("player"), UnitCastingInfo("player")
            end)
            if ok and (channeling or casting) then
                channelWaited = channelWaited + 0.5
                if channelWaited >= 10 then
                    PNNSIVM_SummoningLock = false
                    return
                end
                After(0.5, function() waitIfChanneling(thenSummon) end)
            else
                thenSummon()
            end
        end

        waitIfChanneling(function()
            CallCompanion("CRITTER", idx)
            After(2, function()
                local _, nowActive = FindCompanion(name)
                if nowActive then
                    PNNSIVM_SummoningLock = false
                    onSuccess()
                elseif attempts < 3 then
                    tryOnce()
                else
                    PNNSIVM_SummoningLock = false
                    onFail("exhausted")
                end
            end)
        end)
    end

    tryOnce()
end

local function SummonVM(name)
    SummonWithVerify(name,
        function() end,
        function(reason)
            if reason == "notfound" then
                Print("Companion '" .. (name or "?") .. "' not found in companion list.")
            else
                Print("Companion '" .. (name or "?") .. "' failed to appear after 3 attempts.")
            end
        end
    )
end

local function DismissVM()
    DismissCompanion("CRITTER")
end

local function IsPlayerMountedOrFlying()
    if IsFlying  and IsFlying()  then return true end
    if IsMounted and IsMounted() then return true end
    return false
end

local function GetCompanionDistance()
    if not UnitPosition then return nil end
    local px, py = UnitPosition("player")
    local cx, cy = UnitPosition("pet")
    if not px or not cx then return nil end
    local dx, dy = px - cx, py - cy
    return math.sqrt(dx * dx + dy * dy)
end

-------------------------------------------------------------------------------
-- Vendor target button (SecureActionButton)
-- Adapted from AutoLoot v4.0 by Veronica-Vasilieva
-- WoW protects InteractUnit() — addons cannot auto-open the merchant window.
-- A SecureActionButton's /target macrotext runs only on real mouse click,
-- after which the player presses Interact-with-Target to open the vendor.
-------------------------------------------------------------------------------
local vendorBtn

local function UpdateVendorBtnMacro()
    if not vendorBtn or InCombatLockdown() then return end
    vendorBtn:SetAttribute("macrotext", "/target " .. GetVendorName())
end

local function BuildVendorButton()
    if vendorBtn then return vendorBtn end

    local x = tonumber(GetConf("tool.vendormanagement.btnx", "200")) or 200
    local y = tonumber(GetConf("tool.vendormanagement.btny", "-200")) or -200

    local btn = CreateFrame("Button", "PNNSIVM_VendorBtn", UIParent,
                            "SecureActionButtonTemplate")
    btn:SetSize(60, 60)
    btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForClicks("AnyUp")
    btn:SetFrameStrata("MEDIUM")

    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", "/target " .. GetVendorName())

    local tex = btn:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:SetWidth(66); border:SetHeight(66)
    border:SetPoint("CENTER")
    border:SetVertexColor(1, 0.75, 0.1, 0.85)

    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("BOTTOM", btn, "TOP", 0, 2)
    lbl:SetText("|cffff9900Target Vendor|r")

    btn:SetScript("OnMouseDown", function(self)
        if IsAltKeyDown() then self:StartMoving() end
    end)
    btn:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        SetConf("tool.vendormanagement.btnx", self:GetLeft())
        SetConf("tool.vendormanagement.btny", self:GetTop() - UIParent:GetHeight())
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("|cffff9900Target " .. GetVendorName() .. "|r")
        GameTooltip:AddLine("|cffaaaaaaClick to target the vendor companion|r")
        GameTooltip:AddLine("|cffaaaaaaThen press Interact with Target to sell|r")
        GameTooltip:AddLine("|cffaaaaaaAlt+Drag to reposition|r")
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:Hide()
    vendorBtn = btn
    return btn
end

local function ShowVendorBtn()
    if not vendorBtn then return end
    UpdateVendorBtnMacro()
    vendorBtn:Show()
end

local function HideVendorBtn()
    if vendorBtn then vendorBtn:Hide() end
end

-------------------------------------------------------------------------------
-- State machine
-------------------------------------------------------------------------------
local S_IDLE, S_LOOTING, S_SELLING = "IDLE", "LOOTING", "SELLING"
local currentState       = S_IDLE
local waitingForMerchant = false
local triggeredSellCycle = false

local function SetState(state)
    currentState = state
end

local function StartLootCycle()
    if not IsEnabled() then return end
    SetState(S_LOOTING)
    SummonVM(GetLooterName())
end

local function StartSellCycle()
    if currentState == S_SELLING then return end
    SetState(S_SELLING)
    triggeredSellCycle = true
    Print("Bags full — switching to vendor companion...")
    DismissVM()
    After(1.5, function()
        if currentState ~= S_SELLING then return end
        SummonWithVerify(GetVendorName(),
            function()
                waitingForMerchant = true
                ShowVendorBtn()
                if InCombatLockdown() then
                    Print("|cffffd700In combat:|r click |cffffff00Target Vendor|r, then press your |cffffff00Interact with Target|r keybind.")
                end
                After(8, function()
                    if waitingForMerchant and currentState == S_SELLING then
                        PlaySound("igMainMenuOptionCheckBoxOn")
                        Print("|cffffd700Reminder:|r click |cffffff00Target Vendor|r, then press Interact with Target.")
                    end
                end)
            end,
            function(reason)
                waitingForMerchant = false
                HideVendorBtn()
                if reason == "notfound" then
                    Print("|cffff4444Vendor '" .. GetVendorName() .. "' not found in companion list.|r")
                else
                    Print("|cffff4444Vendor companion failed to appear after 3 attempts.|r")
                end
            end
        )
    end)
end

local function OnMerchantShow()
    waitingForMerchant = false
    HideVendorBtn()
    if not triggeredSellCycle then return end
    After(0.3, function()
        if CanMerchantRepair() then
            RepairAllItems()
            Print("All items repaired.")
        end
        PNNSIM_TriggerSell()
    end)
end

local function OnMerchantClosed()
    triggeredSellCycle = false
    HideVendorBtn()
    if currentState ~= S_SELLING then return end
    if GetFreeSlots() > 0 then
        DismissVM()
        After(1.5, function()
            if currentState == S_SELLING then StartLootCycle() end
        end)
    else
        -- Bags still full: sell was incomplete — retry the sell cycle instead of going idle.
        -- Reset to IDLE first so StartSellCycle() doesn't bail out (it guards against re-entry).
        SetState(S_IDLE)
        After(1.5, function()
            StartSellCycle()
        end)
    end
end

-------------------------------------------------------------------------------
-- OnUpdate: mount detection + stuck check
-- Adapted from AutoLoot v4.0 by Veronica-Vasilieva
-------------------------------------------------------------------------------
local btnPollTimer = 0
local raidIconSet = false
local wasMounted      = false
local stuckCheckTimer = 0
local STUCK_INTERVAL  = 3
local bagUpdateDirty  = false

local mainFrame = CreateFrame("Frame", "PNNSIVM_MainFrame", UIParent)
mainFrame:SetScript("OnUpdate", function(self, elapsed)
    if not IsEnabled() then return end

    local nowMounted = IsPlayerMountedOrFlying()
    if nowMounted ~= wasMounted then
        wasMounted = nowMounted
        if nowMounted then
            local _, looterActive = FindCompanion(GetLooterName())
            local _, vendorActive = FindCompanion(GetVendorName())
            if looterActive or vendorActive then
                DismissVM()
            end
        else
            if currentState == S_LOOTING then
                After(1.5, function()
                    if currentState == S_LOOTING then
                        local _, looterActive = FindCompanion(GetLooterName())
                        if not looterActive then SummonVM(GetLooterName()) end
                    end
                end)
            elseif currentState == S_SELLING then
                waitingForMerchant = true
                After(1.5, function()
                    if currentState == S_SELLING then
                        local _, vendorActive = FindCompanion(GetVendorName())
                        if not vendorActive then SummonVM(GetVendorName()) end
                    end
                end)
            end
        end
    end

    if currentState == S_LOOTING and not nowMounted then
        stuckCheckTimer = stuckCheckTimer + elapsed
        if stuckCheckTimer >= STUCK_INTERVAL then
            stuckCheckTimer = 0
            local dist = GetCompanionDistance()
            if not dist then
                -- distance unavailable; skip this tick
            elseif dist > MAX_COMPANION_DISTANCE then
                Print("Loot companion stuck (" .. math.floor(dist) .. " yds) — resummoning...")
                DismissVM()
                After(0.5, function()
                    if currentState == S_LOOTING then SummonVM(GetLooterName()) end
                end)
            end
        end
    else
        stuckCheckTimer = 0
    end

    -- BAG_UPDATE sets the dirty flag; consume once per tick to avoid thrashing.
    if bagUpdateDirty then
        bagUpdateDirty = false
        if currentState == S_LOOTING and not nowMounted and GetFreeSlots() <= GetThreshold() then
            StartSellCycle()
        end
    end

    btnPollTimer = btnPollTimer + elapsed
    if btnPollTimer >= 1 then
        btnPollTimer = 0

        -- Button sync
        local _, vendorActive = FindCompanion(GetVendorName())
        local _, looterActive = FindCompanion(GetLooterName())
        if vendorActive then
            ShowVendorBtn()
        else
            HideVendorBtn()
        end

        -- Raid icon: set on whichever companion is currently summoned.
        -- Use FindCompanion (authoritative) to gate the block; UnitName("pet")
        -- may refer to a combat pet on Hunter/Warlock/DK, so compare
        -- case-insensitively to handle config-name capitalisation differences.
        if vendorActive or looterActive then
            if UnitExists("pet") then
                local petName = (UnitName("pet") or ""):lower()
                if petName == GetVendorName():lower() or petName == GetLooterName():lower() then
                    SetRaidTarget("pet", 1)
                    raidIconSet = true
                end
            end
        elseif raidIconSet then
            raidIconSet = false
        end
    end
end)

-------------------------------------------------------------------------------
-- Event frame
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame", "PNNSIVM_EventFrame", UIParent)
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_CLOSED")
eventFrame:RegisterEvent("BAG_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        BuildVendorButton()
        if IsEnabled() then
            StartLootCycle()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Fires on login, reload, and zone changes. Ensure looter is summoned
        -- if we're idle/looting; SummonVM is a no-op when already active.
        -- PLAYER_LOGIN does not fire on /reload, so build the button here too.
        BuildVendorButton()
        if IsEnabled() and currentState ~= S_SELLING then
            After(1.0, function()
                if currentState ~= S_SELLING and IsEnabled() then
                    StartLootCycle()
                end
            end)
        end
    elseif event == "MERCHANT_SHOW" then
        OnMerchantShow()
    elseif event == "MERCHANT_CLOSED" then
        OnMerchantClosed()
    elseif event == "BAG_UPDATE" then
        bagUpdateDirty = true
    end
end)
