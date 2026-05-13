-- simple_mailer.lua
-- Prebbles_NNS_SimpleMailer

-------------------------------------------------------------------------------
-- Saved data / config helpers
-------------------------------------------------------------------------------
local function GetBagKeep()
    PNNSIM_SimpleMailerData = PNNSIM_SimpleMailerData or {}
    PNNSIM_SimpleMailerData.bagkeep = PNNSIM_SimpleMailerData.bagkeep or {}
    return PNNSIM_SimpleMailerData.bagkeep
end

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

local function GetRecipient()
    local r = GetConf("tool.simplemailer.recipient", "")
    if r == "" then return UnitName("player") end
    return r
end

-------------------------------------------------------------------------------
-- Print helpers
-------------------------------------------------------------------------------
local PREFIX = "|cFF00CCFF[SimpleMailer]|r "

local function Print(msg)
    if PNNSIM_Console_Print then
        PNNSIM_Console_Print(PREFIX .. tostring(msg))
    else
        print(PREFIX .. tostring(msg))
    end
end

local function PrintErr(msg)
    local errHex = "c70c15"
    if PNNSIM_ConsoleConfig then
        errHex = PNNSIM_ConsoleConfig[UnitName("player") ..
            ".console.theme.consolecolor.textcolor.error"] or errHex
    end
    if PNNSIM_Console_PrintRaw then
        PNNSIM_Console_PrintRaw("|cFF" .. errHex .. tostring(msg) .. "|r")
    else
        print(msg)
    end
end

-------------------------------------------------------------------------------
-- Timer (C_Timer unavailable in WotLK 3.3.5 — same pattern as VendorManagement)
-------------------------------------------------------------------------------
local pendingTimers = {}
local timerFrame    = CreateFrame("Frame")
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
-- Send state
-------------------------------------------------------------------------------
local sendBatches  = {}
local currentBatch = 0
local totalBatches = 0
local isSending    = false
local totalSent    = 0

local function GetItemIDFromSlot(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if not link then return nil end
    return tonumber(string.match(link, "Hitem:(%d+)"))
end

local function CollectItems()
    local keepIDs = {}
    for _, entry in ipairs(GetBagKeep()) do
        keepIDs[entry.id] = true
    end
    local items = {}
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local itemID = GetItemIDFromSlot(bag, slot)
            if itemID and not keepIDs[itemID] then
                table.insert(items, { bag = bag, slot = slot })
            end
        end
    end
    return items
end

-- Forward declaration: assigned in the UI section so send logic can call it.
local UpdatePanel

local function SendNextBatch()
    currentBatch = currentBatch + 1
    if currentBatch > totalBatches then
        isSending = false
        Print("Done. Sent " .. totalSent .. " item(s) in " .. totalBatches .. " mail(s).")
        if UpdatePanel then UpdatePanel() end
        return
    end
    Print("Sending batch " .. currentBatch .. "/" .. totalBatches .. "...")
    local batch = sendBatches[currentBatch]
    local n = 0
    for _, item in ipairs(batch) do
        n = n + 1
        PickupContainerItem(item.bag, item.slot)
        ClickSendMailItemButton(n)
        local name = GetSendMailItem(n)
        if not name then
            -- Item would not attach (soulbound / unmailable) — drop cursor and skip slot.
            ClearCursor()
            n = n - 1
        end
    end
    if n > 0 then
        totalSent = totalSent + n
        SendMail(GetRecipient(), "Items", "")
    else
        -- Entire batch unmailable; skip without waiting for MAIL_SEND_SUCCESS.
        After(0.1, SendNextBatch)
    end
end

local function OnMailSendSuccess()
    if isSending then
        After(0.5, SendNextBatch)
    end
end

local function OnMailClosed()
    if isSending then
        local remaining = 0
        for i = currentBatch + 1, totalBatches do
            remaining = remaining + #sendBatches[i]
        end
        isSending    = false
        sendBatches  = {}
        Print("Mailbox closed — send aborted (" .. remaining .. " item(s) unsent).")
        if UpdatePanel then UpdatePanel() end
    end
end

function PNNSIM_SimpleMailer_Send()
    if isSending then
        Print("Already sending. Please wait.")
        return
    end
    local items = CollectItems()
    if #items == 0 then
        Print("No sendable items found.")
        return
    end
    sendBatches = {}
    local batch = {}
    for _, item in ipairs(items) do
        table.insert(batch, item)
        if #batch == 12 then
            table.insert(sendBatches, batch)
            batch = {}
        end
    end
    if #batch > 0 then table.insert(sendBatches, batch) end
    totalBatches = #sendBatches
    currentBatch = 0
    totalSent    = 0
    isSending    = true
    Print("Sending " .. #items .. " item(s) in " .. totalBatches ..
          " mail(s) to " .. GetRecipient() .. "...")
    if UpdatePanel then UpdatePanel() end
    SendNextBatch()
end

-------------------------------------------------------------------------------
-- UI — "Simple" tab
-------------------------------------------------------------------------------
local simplePanel      = nil
local simpleTab        = nil
local tabHookInstalled = false
local panelCreated     = false

-- Assigned here — this satisfies the forward declaration above so send logic
-- can call UpdatePanel() without knowing about the UI section's existence.
UpdatePanel = function()
    if not simplePanel or not simplePanel:IsShown() then return end
    local r = GetConf("tool.simplemailer.recipient", "")
    if r == "" then
        simplePanel.recipientText:SetText(
            "To: " .. UnitName("player") .. " |cFF888888(default, not set)|r")
    else
        simplePanel.recipientText:SetText("To: " .. r)
    end
    local keep = GetBagKeep()
    if #keep == 0 then
        simplePanel.keepListText:SetText("|cFF888888(empty)|r")
    else
        local lines = {}
        for i, entry in ipairs(keep) do
            lines[i] = "[" .. i .. "] " .. (entry.name or "?") ..
                        " |cFF888888(ID: " .. entry.id .. ")|r"
        end
        simplePanel.keepListText:SetText(table.concat(lines, "\n"))
    end
    if isSending then
        simplePanel.sendBtn:SetText("Sending...")
        simplePanel.sendBtn:Disable()
    else
        simplePanel.sendBtn:SetText("Send All")
        simplePanel.sendBtn:Enable()
    end
end

local function CreatePanel()
    if panelCreated then return end
    panelCreated = true

    -- InboxFrame's BOTTOMRIGHT extends below MailFrame's visual chrome, so use
    -- MailFrame for the bottom anchor to stay inside the visible content area.
    simplePanel = CreateFrame("Frame", "PNNSIM_SimpleMailPanel", MailFrame)
    simplePanel:SetPoint("TOPLEFT",     InboxFrame, "TOPLEFT")
    simplePanel:SetPoint("BOTTOMRIGHT", MailFrame,  "BOTTOMRIGHT")
    simplePanel:Hide()

    local recipientText = simplePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    recipientText:SetPoint("TOPLEFT", simplePanel, "TOPLEFT", 10, -10)
    simplePanel.recipientText = recipientText

    local keepHeader = simplePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    keepHeader:SetPoint("TOPLEFT", recipientText, "BOTTOMLEFT", 0, -10)
    keepHeader:SetText("|cFFFFCC00Bag keep (not sent):|r")

    local keepListText = simplePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    keepListText:SetPoint("TOPLEFT", keepHeader, "BOTTOMLEFT", 0, -4)
    keepListText:SetWidth(280)
    keepListText:SetJustifyH("LEFT")
    keepListText:SetJustifyV("TOP")
    simplePanel.keepListText = keepListText

    local sendBtn = CreateFrame("Button", "PNNSIM_SimpleMailSendBtn",
                                simplePanel, "UIPanelButtonTemplate")
    sendBtn:SetSize(100, 22)
    sendBtn:SetPoint("BOTTOMLEFT", simplePanel, "BOTTOMLEFT", 10, 8)
    sendBtn:SetText("Send All")
    sendBtn:SetScript("OnClick", function() PNNSIM_SimpleMailer_Send() end)
    simplePanel.sendBtn = sendBtn
end

local function CreateTab()
    if simpleTab then return end
    PanelTemplates_SetNumTabs(MailFrame, 3)
    simpleTab = CreateFrame("Button", "MailFrameTab3", MailFrame,
                            "FriendsFrameTabTemplate")
    simpleTab:SetID(3)
    simpleTab:SetText("Simple")
    simpleTab:SetPoint("LEFT", MailFrameTab2, "RIGHT", -16, 0)
    simpleTab:SetScript("OnClick", function(self) MailFrameTab_OnClick(self) end)
    PanelTemplates_TabResize(simpleTab, 0)
end

local function InstallTabHook()
    if tabHookInstalled then return end
    tabHookInstalled = true
    hooksecurefunc("MailFrameTab_OnClick", function(self, tabID)
        if not tabID then tabID = self and self:GetID() end
        if tabID == 3 then
            -- The original MailFrameTab_OnClick shows SendMailFrame for any tab != 1.
            -- Hide both native frames and show ours instead.
            InboxFrame:Hide()
            SendMailFrame:Hide()
            if simplePanel then
                simplePanel:Show()
                UpdatePanel()
            end
        else
            if simplePanel then simplePanel:Hide() end
        end
    end)
end

local function OnMailShow()
    CreateTab()
    CreatePanel()
    InstallTabHook()
end

-------------------------------------------------------------------------------
-- Command handler — called via dispatch guard in tools_commands.lua
-------------------------------------------------------------------------------
function PNNSIM_SimpleMailer_HandleCommand(msg, isConsole)
    local function Out(s)
        if isConsole and PNNSIM_Console_Print then
            PNNSIM_Console_Print(PREFIX .. s)
        else
            print(PREFIX .. s)
        end
    end
    local function Err(s)
        local errHex = "c70c15"
        if PNNSIM_ConsoleConfig then
            errHex = PNNSIM_ConsoleConfig[
                UnitName("player") .. ".console.theme.consolecolor.textcolor.error"
            ] or errHex
        end
        if isConsole and PNNSIM_Console_PrintRaw then
            PNNSIM_Console_PrintRaw("|cFF" .. errHex .. s .. "|r")
        else
            print(s)
        end
    end

    -- Preserve original casing so character names round-trip correctly.
    local cmd_part, args_part = string.match(msg, "^(%S+)%s*(.*)$")
    local cmd_lower = string.lower(cmd_part or "")
    args_part = strtrim(args_part or "")

    -- tool.simplemailer.recipient [charname]
    if cmd_lower == "tool.simplemailer.recipient" then
        if args_part == "" then
            local r = GetConf("tool.simplemailer.recipient", "")
            if r == "" then
                Out("recipient: " .. UnitName("player") .. " (default, not set)")
            else
                Out("recipient: " .. r)
            end
        else
            SetConf("tool.simplemailer.recipient", args_part)
            Out("recipient set to: " .. args_part)
            UpdatePanel()
        end
        return
    end

    -- tool.simplemailer.bagkeep.list
    if cmd_lower == "tool.simplemailer.bagkeep.list" then
        local keep = GetBagKeep()
        if #keep == 0 then
            Out("Bagkeep is empty.")
        else
            Out("Bagkeep (" .. #keep .. " item(s)):")
            for i, entry in ipairs(keep) do
                Out("  [" .. i .. "] " .. (entry.name or "?") ..
                    " (ID: " .. entry.id .. ")")
            end
        end
        return
    end

    -- tool.simplemailer.bagkeep.add [itemlink or item ID]
    if cmd_lower == "tool.simplemailer.bagkeep.add" then
        if args_part == "" then
            Err("Usage: tool.simplemailer.bagkeep.add [itemlink or item ID]")
            return
        end
        local itemID
        local idStr = string.match(args_part, "[Hh]item:(%d+)")
        if idStr then
            itemID = tonumber(idStr)
        else
            itemID = tonumber(args_part)
        end
        if not itemID then
            Err("Cannot parse item ID from: " .. args_part)
            return
        end
        local keep = GetBagKeep()
        for _, entry in ipairs(keep) do
            if entry.id == itemID then
                Out("ID " .. itemID .. " is already in bagkeep.")
                return
            end
        end
        local itemName = GetItemInfo(itemID) or ("Item " .. itemID)
        table.insert(keep, { id = itemID, name = itemName })
        Out("Added to bagkeep: " .. itemName .. " (ID: " .. itemID .. ")")
        UpdatePanel()
        return
    end

    -- tool.simplemailer.bagkeep.rem [index]
    if cmd_lower == "tool.simplemailer.bagkeep.rem" then
        local idx = tonumber(args_part)
        if not idx then
            Err("Usage: tool.simplemailer.bagkeep.rem [index]")
            return
        end
        local keep = GetBagKeep()
        if not keep[idx] then
            Err("No bagkeep entry at index " .. idx .. ".")
            return
        end
        local removed = table.remove(keep, idx)
        Out("Removed from bagkeep: " .. (removed.name or "?") ..
            " (ID: " .. removed.id .. ")")
        UpdatePanel()
        return
    end

    -- tool.simplemailer.send
    if cmd_lower == "tool.simplemailer.send" then
        PNNSIM_SimpleMailer_Send()
        return
    end

    Out("Simple Mailer commands:")
    Out("  tool.simplemailer.recipient [charname]")
    Out("  tool.simplemailer.bagkeep.list")
    Out("  tool.simplemailer.bagkeep.add [itemlink or item ID]")
    Out("  tool.simplemailer.bagkeep.rem [index]")
    Out("  tool.simplemailer.send")
end

-------------------------------------------------------------------------------
-- ADDON_LOADED init + event dispatch
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("MAIL_SHOW")
eventFrame:RegisterEvent("MAIL_CLOSED")
eventFrame:RegisterEvent("MAIL_SEND_SUCCESS")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Prebbles_NNS_SimpleMailer" then
            PNNSIM_SimpleMailerData = PNNSIM_SimpleMailerData or {}
            PNNSIM_SimpleMailerData.bagkeep = PNNSIM_SimpleMailerData.bagkeep or {}
        end
    elseif event == "MAIL_SHOW" then
        OnMailShow()
    elseif event == "MAIL_CLOSED" then
        OnMailClosed()
    elseif event == "MAIL_SEND_SUCCESS" then
        OnMailSendSuccess()
    end
end)
