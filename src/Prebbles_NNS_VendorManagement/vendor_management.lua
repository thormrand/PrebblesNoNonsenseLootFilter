-- vendor_management.lua
--
-- Companion lifecycle logic adapted from AutoLoot v4.0
-- by Veronica-Vasilieva (https://github.com/Veronica-Vasilieva/AutoLoot)
-- Used with attribution under the project's open-source license.
--
-- Self-healing watchdog redesign (2026-05-13):
--   * Single 2s watchdog reconciles companion-out reality to a desired state.
--   * No closure-based retry chains: missed summons self-heal on the next tick.
--   * Combat-recent gate (<60s since last combat / kill / regen edge).
--   * Channel/cast guard, mount guard, combat-lockdown guard inside watchdog.
--   * Retry cap of 5 attempts per state-burst; resets on state change, mount
--     transition, or fresh combat.
--   * Vendor button visibility tracks the vendor companion's actual active
--     state (FindCompanion(vendor).active == true) plus a COMPANION_UPDATE
--     event hook for instant hide on dismiss.

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
    if PNNSIM_Console_Print then
        PNNSIM_Console_Print("|cFF00CCFF[VendorMgmt]|r " .. tostring(msg))
    end
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
            local ok, err = pcall(t.fn)
            if not ok then Print("|cffff4444Timer error:|r " .. tostring(err)) end
        end
    end
end)

local function After(delay, fn)
    table.insert(pendingTimers, { remaining = delay, fn = fn })
end

-------------------------------------------------------------------------------
-- Companion helpers
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

local function IsPlayerMountedOrFlying()
    if IsFlying  and IsFlying()  then return true end
    if IsMounted and IsMounted() then return true end
    return false
end

local function IsPlayerCastingOrChanneling()
    local ok, casting = pcall(UnitCastingInfo, "player")
    if ok and casting then return true end
    local ok2, channeling = pcall(UnitChannelInfo, "player")
    if ok2 and channeling then return true end
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
-- Combat-recent tracking
-------------------------------------------------------------------------------
local lastCombatTime = 0
local COMBAT_RECENT_WINDOW = 60

local function RecentCombat()
    if UnitAffectingCombat and UnitAffectingCombat("player") then return true end
    return (time() - lastCombatTime) < COMBAT_RECENT_WINDOW
end

local function BumpCombatTime()
    local wasRecent = RecentCombat()
    lastCombatTime = time()
    return wasRecent
end

-------------------------------------------------------------------------------
-- Vendor target button (SecureActionButton)
-- Adapted from AutoLoot v4.0 by Veronica-Vasilieva
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
    if vendorBtn:IsShown() then return end
    UpdateVendorBtnMacro()
    vendorBtn:Show()
end

local function HideVendorBtn()
    if vendorBtn and vendorBtn:IsShown() then vendorBtn:Hide() end
end

local SyncVendorBtn  -- forward declaration; defined after state vars exist

-------------------------------------------------------------------------------
-- State + watchdog
-------------------------------------------------------------------------------
local S_IDLE, S_LOOTING, S_SELLING = "IDLE", "LOOTING", "SELLING"
local currentState        = S_IDLE
local triggeredSellCycle  = false   -- merchant-show should run PNNSIM_TriggerSell
local summonAttempts      = 0
local lastSummonAttempt   = 0
local lastDismissAttempt  = 0
local capWarnedThisBurst  = false
local wasMounted          = false
local wasCombatRecent     = false
local stuckCheckTimer     = 0
local STUCK_INTERVAL      = 3
local watchdogTimer       = 0
local WATCHDOG_INTERVAL   = 2
local SUMMON_BACKOFF      = 3
local MAX_SUMMON_ATTEMPTS = 5
local bagUpdateDirty      = false

-- Sync button visibility to the live vendor companion state.
-- Predicate: vendor companion is in the list AND marked active by the API.
-- Hides for: combat lockdown, mounted/flying, addon disabled, or wrong state.
SyncVendorBtn = function()
    -- Note: Show/Hide on this frame is NOT protected; only SetAttribute is
    -- (and UpdateVendorBtnMacro guards that). Do not short-circuit on
    -- InCombatLockdown() here — that was hiding the button mid-combat and
    -- only letting it appear after PLAYER_REGEN_ENABLED.
    if not IsEnabled() then HideVendorBtn(); return end
    if currentState ~= S_SELLING then HideVendorBtn(); return end
    if IsPlayerMountedOrFlying() then HideVendorBtn(); return end
    local _, active = FindCompanion(GetVendorName())
    if active then ShowVendorBtn() else HideVendorBtn() end
end

local function ResetSummonBurst(reason)
    if summonAttempts ~= 0 or capWarnedThisBurst then
        summonAttempts = 0
        capWarnedThisBurst = false
    end
end

local function SetState(state)
    if currentState == state then return end
    currentState = state
    ResetSummonBurst("state change")
end

local function DismissCompanionSafe()
    if (time() - lastDismissAttempt) < 1 then return end
    lastDismissAttempt = time()
    DismissCompanion("CRITTER")
    HideVendorBtn()
end

-- Watchdog: reconciles companion-out reality to desired state.
-- Called every WATCHDOG_INTERVAL seconds from the main OnUpdate.
local function Watchdog()
    if not IsEnabled() then
        HideVendorBtn()
        return
    end

    -- Desired companion per state
    local desiredName, otherName
    if currentState == S_SELLING then
        desiredName, otherName = GetVendorName(), GetLooterName()
    elseif currentState == S_LOOTING then
        desiredName, otherName = GetLooterName(), GetVendorName()
    end

    -- Hard gates: nothing summoned/shown if these fail
    if not RecentCombat() then
        HideVendorBtn()
        -- If a companion is out and we're long-idle, leave it alone — player may
        -- have manually summoned. Watchdog does not dismiss outside its loop.
        return
    end

    if IsPlayerMountedOrFlying() then
        HideVendorBtn()
        return
    end

    -- Button visibility tracks the live vendor-active state.
    SyncVendorBtn()

    if not desiredName then return end

    -- Raid icon on our companion
    if UnitExists("pet") then
        local petName = (UnitName("pet") or ""):lower()
        if petName == desiredName:lower() then
            SetRaidTarget("pet", 1)
        end
    end

    -- Casting/channeling guard — never summon mid-cast
    if IsPlayerCastingOrChanneling() then return end

    local idx, active = FindCompanion(desiredName)
    if active then
        summonAttempts = 0
        capWarnedThisBurst = false
        return
    end

    if not idx then
        -- Not in companion list at all — print once per burst, then back off.
        if not capWarnedThisBurst then
            Print("|cffff4444Companion '" .. desiredName .. "' not found in companion list.|r")
            capWarnedThisBurst = true
        end
        return
    end

    -- If the wrong companion is currently out, dismiss it first
    if otherName then
        local _, otherActive = FindCompanion(otherName)
        if otherActive then
            DismissCompanionSafe()
            lastSummonAttempt = time()  -- defer summon to next tick
            return
        end
    end

    -- Retry cap
    if summonAttempts >= MAX_SUMMON_ATTEMPTS then
        if not capWarnedThisBurst then
            Print("|cffff4444Summon cap reached (" .. MAX_SUMMON_ATTEMPTS .. " tries) for '" .. desiredName .. "'. Resets on next state change, mount, or new combat.|r")
            capWarnedThisBurst = true
        end
        return
    end

    -- Backoff between attempts
    if (time() - lastSummonAttempt) < SUMMON_BACKOFF then return end

    CallCompanion("CRITTER", idx)
    summonAttempts = summonAttempts + 1
    lastSummonAttempt = time()
    -- API can report summoned=0 for a frame or two after CallCompanion. Poke
    -- the visibility sync shortly after so the icon doesn't wait on the next
    -- 2s watchdog tick (or on UNIT_PET / COMPANION_UPDATE timing).
    After(0.3, SyncVendorBtn)
    After(0.8, SyncVendorBtn)
end

-------------------------------------------------------------------------------
-- Cycle transitions
-------------------------------------------------------------------------------
local function StartLootCycle()
    if not IsEnabled() then return end
    triggeredSellCycle = false
    SetState(S_LOOTING)
    -- Watchdog will summon; nothing to do here.
end

local function StartSellCycle()
    if currentState == S_SELLING then return end
    Print("Bags full — switching to vendor companion...")
    triggeredSellCycle = true
    DismissCompanionSafe()
    SetState(S_SELLING)
    -- Watchdog reconciles vendor summon + button visibility.
end

local function OnMerchantShow()
    HideVendorBtn()
    if not triggeredSellCycle then return end
    After(0.3, function()
        if not MerchantFrame or not MerchantFrame:IsShown() then return end
        if CanMerchantRepair() then
            RepairAllItems()
            Print("All items repaired.")
        end
        PNNSIM_TriggerSell()
    end)
end

local function OnMerchantClosed()
    local wasMidSell = triggeredSellCycle
    triggeredSellCycle = false

    if currentState ~= S_SELLING then return end

    local free = GetFreeSlots()
    if free > GetThreshold() then
        if wasMidSell then
            Print("Merchant closed — sell aborted. Bags OK, back to looting.")
        end
        DismissCompanionSafe()
        SetState(S_LOOTING)
    else
        if wasMidSell then
            Print("|cffffaa00Merchant closed before sell finished|r (free=" .. free .. " <= threshold=" .. GetThreshold() .. ") — staying in sell mode.")
        end
        -- Keep state SELLING; reset attempts so watchdog resummons vendor cleanly.
        ResetSummonBurst("merchant closed early")
        triggeredSellCycle = true  -- the next MERCHANT_SHOW must re-trigger sell
    end
end

-------------------------------------------------------------------------------
-- OnUpdate: mount transitions, stuck check, watchdog
-------------------------------------------------------------------------------
local mainFrame = CreateFrame("Frame", "PNNSIVM_MainFrame", UIParent)
mainFrame:SetScript("OnUpdate", function(self, elapsed)
    if not IsEnabled() then return end

    -- Mount transition: dismiss on mount, reset burst on either edge
    local nowMounted = IsPlayerMountedOrFlying()
    if nowMounted ~= wasMounted then
        wasMounted = nowMounted
        ResetSummonBurst("mount transition")
        if nowMounted then
            local _, looterActive = FindCompanion(GetLooterName())
            local _, vendorActive = FindCompanion(GetVendorName())
            if looterActive or vendorActive then
                After(1.0, function()
                    if IsPlayerMountedOrFlying() then DismissCompanionSafe() end
                end)
            end
        end
    end

    -- Combat-recent edge: false -> true resets the burst counter
    local nowCombatRecent = RecentCombat()
    if nowCombatRecent and not wasCombatRecent then
        ResetSummonBurst("combat resumed")
    end
    wasCombatRecent = nowCombatRecent

    -- Stuck distance check (LOOTING only, on ground)
    if currentState == S_LOOTING and not nowMounted and nowCombatRecent then
        stuckCheckTimer = stuckCheckTimer + elapsed
        if stuckCheckTimer >= STUCK_INTERVAL then
            stuckCheckTimer = 0
            local _, active = FindCompanion(GetLooterName())
            if active then
                local dist = GetCompanionDistance()
                if dist and dist > MAX_COMPANION_DISTANCE then
                    Print("Loot companion stuck (" .. math.floor(dist) .. " yds) — resummoning...")
                    DismissCompanionSafe()
                    ResetSummonBurst("stuck respawn")
                end
            end
        end
    else
        stuckCheckTimer = 0
    end

    -- BAG_UPDATE → check threshold on next tick (cheap)
    if bagUpdateDirty then
        bagUpdateDirty = false
        if currentState == S_LOOTING and not nowMounted and GetFreeSlots() <= GetThreshold() then
            StartSellCycle()
        end
    end

    -- Watchdog tick
    watchdogTimer = watchdogTimer + elapsed
    if watchdogTimer >= WATCHDOG_INTERVAL then
        watchdogTimer = 0
        local ok, err = pcall(Watchdog)
        if not ok then Print("|cffff4444Watchdog error:|r " .. tostring(err)) end
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
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("COMPANION_UPDATE")
eventFrame:RegisterEvent("UNIT_PET")

local playerGUID

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        playerGUID = UnitGUID("player")
        BuildVendorButton()
        if IsEnabled() then StartLootCycle() end

    elseif event == "PLAYER_ENTERING_WORLD" then
        playerGUID = UnitGUID("player")
        BuildVendorButton()
        if IsEnabled() and currentState ~= S_SELLING then
            -- Don't summon directly; just ensure state is LOOTING.
            -- Watchdog handles the summon on the next tick (combat-recent gated).
            SetState(S_LOOTING)
            triggeredSellCycle = false
        end

    elseif event == "MERCHANT_SHOW" then
        OnMerchantShow()

    elseif event == "MERCHANT_CLOSED" then
        OnMerchantClosed()

    elseif event == "BAG_UPDATE" then
        bagUpdateDirty = true

    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        BumpCombatTime()
        if event == "PLAYER_REGEN_ENABLED" then SyncVendorBtn() end

    elseif event == "COMPANION_UPDATE" or event == "UNIT_PET" then
        -- UNIT_PET is the reliable "your critter just spawned/despawned" signal
        -- in 3.3.5a; COMPANION_UPDATE covers list-level changes. Either way,
        -- re-sync immediately so the icon never waits for the 2s watchdog.
        local unit = ...
        if event ~= "UNIT_PET" or unit == "player" then
            SyncVendorBtn()
        end

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- PARTY_KILL fires when player (or party) kills a mob. UNIT_DIED has no
        -- reliable source, so we don't use it here.
        local _, subEvent, sourceGUID = ...
        if subEvent == "PARTY_KILL" and sourceGUID and playerGUID
           and sourceGUID == playerGUID then
            BumpCombatTime()
        end
    end
end)
