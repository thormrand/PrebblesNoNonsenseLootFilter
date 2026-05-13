-- console.lua
-- Changes applied between lines 68-230 for UI layout, Tracker relocation, and Minimize Toggle

local PNNSIM_Font = "Interface\\AddOns\\Prebbles_NNS_InvMngmt\\assets\\fonts\\VCR_OSD_MONO_1.001.ttf"
local PNNSIM_FallbackFont = "Fonts\\FRIZQT__.TTF"

local function HexToRGB(hex)
    if not hex then return 1, 1, 1 end
    hex = string.gsub(hex, "#", "")
    if string.len(hex) ~= 6 then return 1, 1, 1 end
    local r = tonumber(string.sub(hex, 1, 2), 16) / 255
    local g = tonumber(string.sub(hex, 3, 4), 16) / 255
    local b = tonumber(string.sub(hex, 5, 6), 16) / 255
    return r, g, b
end

local function PNNSIM_ApplyFont(fontObj, size, flags)
    size = tonumber(size) or 14
    local success = pcall(function() fontObj:SetFont(PNNSIM_Font, size, flags) end)
    if not success then
        fontObj:SetFont(PNNSIM_FallbackFont, size, flags)
    end
end

local PNNSIM_CachedPlayerName = nil
local function GetCachedPlayerName()
    if not PNNSIM_CachedPlayerName then
        PNNSIM_CachedPlayerName = UnitName("player")
    end
    return PNNSIM_CachedPlayerName
end

local function GetConfKey(prop)
    local charName = GetCachedPlayerName()
    if string.sub(prop, 1, 8) == "console." or string.sub(prop, 1, 8) == "tracker." then
        return charName .. "." .. prop
    end
    return prop
end

local function GetBaseProp(prop)
    local charName = GetCachedPlayerName()
    local charPrefix = charName .. "."
    if string.sub(prop, 1, string.len(charPrefix)) == charPrefix then
        return string.sub(prop, string.len(charPrefix) + 1)
    end
    return prop
end

local function GetConfVal(prop)
    local fullKey = GetConfKey(prop)
    if PNNSIM_ConsoleConfig and PNNSIM_ConsoleConfig[fullKey] then
        return PNNSIM_ConsoleConfig[fullKey]
    end
    local base = GetBaseProp(prop)
    local entry = PNNSIM_ConfigDefaults and PNNSIM_ConfigDefaults[base]
    return entry and entry.default or nil
end

local function FormatTime(secs)
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = math.floor(secs % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

PNNSIM_Console = CreateFrame("Frame", "PNNSIM_Console", UIParent)
PNNSIM_Console:SetSize(450, 380)
PNNSIM_Console:SetPoint("CENTER")
PNNSIM_Console:SetFrameStrata("FULLSCREEN_DIALOG")
PNNSIM_Console:SetFrameLevel(9000)
PNNSIM_Console:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false, edgeSize = 2,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
PNNSIM_Console:EnableMouse(true)
PNNSIM_Console:SetMovable(true)
PNNSIM_Console:SetResizable(true)
PNNSIM_Console:SetMinResize(350, 180)
PNNSIM_Console:RegisterForDrag("LeftButton")

PNNSIM_Console:SetScript("OnDragStart", function(self) if self:IsMovable() then self:StartMoving() end end)
PNNSIM_Console:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
PNNSIM_Console:Hide()

local function PNNSIM_CreateTechBtn(name, text, tooltip, point, relFrame, relPoint, x, y)
    local btn = CreateFrame("Button", name, PNNSIM_Console)
    btn:SetSize(20, 20)
    btn:SetFrameLevel(9001)
    btn:SetPoint(point, relFrame, relPoint, x, y)
    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetPoint("CENTER", 0, 0)
    btn:SetFontString(fs)
    
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("|cFF"..GetConfVal("console.theme.consolecolor.border")..(self.tooltipText or tooltip).."|r")
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return btn
end

local PNNSIM_IsFreeSelect = false
local function ToggleFreeSelect(state)
    if state ~= nil then
        PNNSIM_IsFreeSelect = state
    else
        PNNSIM_IsFreeSelect = not PNNSIM_IsFreeSelect
    end
    
    local bdHex = GetConfVal("console.theme.consolecolor.border")
    
    if PNNSIM_IsFreeSelect then
        PNNSIM_SelectBtn:GetFontString():SetText("|cFF00aa00S|r")
        PNNSIM_SelectBtn.tooltipText = "Disable Free Select"
        PNNSIM_ConsoleOutput_Msg:Hide()
        PNNSIM_ConsoleOutput_Scroll:Show()

        local lines = {}
        local history = (PNNSIM_CharData and PNNSIM_CharData.outputHistory) or {}
        for i = PNNSIM_VisibleStartIdx, #history do table.insert(lines, history[i]) end
        PNNSIM_ConsoleOutput_Edit:SetText(table.concat(lines, "\n"))
        
        PNNSIM_ConsoleOutput_Scroll:UpdateScrollChildRect()
        PNNSIM_ConsoleOutput_Scroll:SetVerticalScroll(PNNSIM_ConsoleOutput_Scroll:GetVerticalScrollRange())
    else
        PNNSIM_SelectBtn:GetFontString():SetText("|cFF"..bdHex.."S|r")
        PNNSIM_SelectBtn.tooltipText = "Enable Free Select (Copy/Paste)"
        PNNSIM_ConsoleOutput_Scroll:Hide()
        PNNSIM_ConsoleOutput_Msg:Show()
    end
end

local PNNSIM_CloseBtn = PNNSIM_CreateTechBtn("PNNSIM_CloseBtn", "X", "Close Console", "TOPRIGHT", PNNSIM_Console, "TOPRIGHT", -4, -4)
PNNSIM_CloseBtn:SetScript("OnClick", function() 
    PNNSIM_Console:Hide() 
    if PNNSIM_ConsoleConfig then PNNSIM_ConsoleConfig[UnitName("player")..".console.isOpen"] = false end
end)

local PNNSIM_IsLocked = false
local PNNSIM_LockBtn = PNNSIM_CreateTechBtn("PNNSIM_LockBtn", "U", "Lock / Unlock Console", "RIGHT", PNNSIM_CloseBtn, "LEFT", -4, 0)
PNNSIM_LockBtn:SetScript("OnClick", function(self)
    PNNSIM_IsLocked = not PNNSIM_IsLocked
    PNNSIM_Console:SetMovable(not PNNSIM_IsLocked)
    if PNNSIM_InitConsoleTheme then PNNSIM_InitConsoleTheme() end
end)

local PNNSIM_MoveBtn = PNNSIM_CreateTechBtn("PNNSIM_MoveBtn", "■", "Drag to Move", "RIGHT", PNNSIM_LockBtn, "LEFT", -4, 0)
PNNSIM_MoveBtn:RegisterForDrag("LeftButton")
PNNSIM_MoveBtn:SetScript("OnDragStart", function() if not PNNSIM_IsLocked then PNNSIM_Console:StartMoving() end end)
PNNSIM_MoveBtn:SetScript("OnDragStop", function() PNNSIM_Console:StopMovingOrSizing() end)

PNNSIM_SelectBtn = PNNSIM_CreateTechBtn("PNNSIM_SelectBtn", "S", "Enable Free Select (Copy/Paste)", "RIGHT", PNNSIM_MoveBtn, "LEFT", -4, 0)
PNNSIM_SelectBtn:SetScript("OnClick", function() ToggleFreeSelect() end)

local PNNSIM_ResizeGrip = CreateFrame("Button", nil, PNNSIM_Console)
PNNSIM_ResizeGrip:SetSize(16, 16)
PNNSIM_ResizeGrip:SetFrameLevel(9001)
PNNSIM_ResizeGrip:SetPoint("BOTTOMRIGHT", -4, 4)
PNNSIM_ResizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
PNNSIM_ResizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
PNNSIM_ResizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
PNNSIM_ResizeGrip:SetScript("OnMouseDown", function() if not PNNSIM_IsLocked then PNNSIM_Console:StartSizing("BOTTOMRIGHT") end end)
PNNSIM_ResizeGrip:SetScript("OnMouseUp", function() PNNSIM_Console:StopMovingOrSizing() end)

local PNNSIM_ConsoleTitleLabel = PNNSIM_Console:CreateFontString(nil, "OVERLAY")
PNNSIM_ConsoleTitleLabel:SetPoint("TOPLEFT", 8, -4)
PNNSIM_ConsoleTitleLabel:SetFont("Interface\\AddOns\\Prebbles_NNS_InvMngmt\\assets\\fonts\\VCR_OSD_MONO_1.001.ttf", 11)
PNNSIM_ConsoleTitleLabel:SetText("")

local PNNSIM_ConsoleTitleBtn = CreateFrame("Button", nil, PNNSIM_Console)
PNNSIM_ConsoleTitleBtn:SetHeight(24)
PNNSIM_ConsoleTitleBtn:SetPoint("TOPLEFT", PNNSIM_Console, "TOPLEFT", 0, 0)
PNNSIM_ConsoleTitleBtn:SetPoint("RIGHT", PNNSIM_SelectBtn, "LEFT", 0, 0)
PNNSIM_ConsoleTitleBtn:EnableMouse(false)
PNNSIM_ConsoleTitleBtn:SetScript("OnClick", function()
    local pKey = PNNSIM_GetActiveProfile()
    if not pKey then return end
    PNNSIM_ConsoleInput:SetText("vendorprofile." .. pKey .. ".")
    PNNSIM_ConsoleInput:SetCursorPosition(PNNSIM_ConsoleInput:GetNumLetters())
    PNNSIM_ConsoleInput:SetFocus()
end)

PNNSIM_Console:HookScript("OnHide", function()
    ToggleFreeSelect(false)
end)

PNNSIM_VisibleStartIdx = 1

local PNNSIM_ConsoleInput = CreateFrame("EditBox", "PNNSIM_ConsoleInput", PNNSIM_Console, "InputBoxTemplate")
PNNSIM_ConsoleInput:SetFrameLevel(9001)
PNNSIM_ConsoleInput:SetPoint("BOTTOMLEFT", 12, 15)
PNNSIM_ConsoleInput:SetPoint("BOTTOMRIGHT", -24, 15)
PNNSIM_ConsoleInput:SetHeight(20)
PNNSIM_ConsoleInput:SetAutoFocus(false)
PNNSIM_ConsoleInput:SetAltArrowKeyMode(false)

if _G["PNNSIM_ConsoleInputLeft"] then _G["PNNSIM_ConsoleInputLeft"]:Hide() end
if _G["PNNSIM_ConsoleInputMiddle"] then _G["PNNSIM_ConsoleInputMiddle"]:Hide() end
if _G["PNNSIM_ConsoleInputRight"] then _G["PNNSIM_ConsoleInputRight"]:Hide() end

PNNSIM_ConsoleInput:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
})

PNNSIM_ConsoleOutput_Msg = CreateFrame("ScrollingMessageFrame", "PNNSIM_ConsoleOutput_Msg", PNNSIM_Console)
PNNSIM_ConsoleOutput_Msg:SetFrameLevel(9001)
PNNSIM_ConsoleOutput_Msg:SetPoint("TOPLEFT", 8, -35)
PNNSIM_ConsoleOutput_Msg:SetPoint("BOTTOMRIGHT", -8, 45)
PNNSIM_ConsoleOutput_Msg:SetJustifyH("LEFT")
PNNSIM_ConsoleOutput_Msg:SetFading(false)
PNNSIM_ConsoleOutput_Msg:EnableMouseWheel(true)
PNNSIM_ConsoleOutput_Msg:SetHyperlinksEnabled(true)

PNNSIM_ConsoleOutput_Msg:SetScript("OnHyperlinkEnter", function(self, link, text)
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetHyperlink(link)
    GameTooltip:Show()
end)

PNNSIM_ConsoleOutput_Msg:SetScript("OnHyperlinkLeave", function(self)
    GameTooltip:Hide()
end)

PNNSIM_ConsoleOutput_Msg:SetScript("OnHyperlinkClick", function(self, link, text, button)
    if IsModifiedClick("CHATLINK") then
        if PNNSIM_ConsoleInput and PNNSIM_ConsoleInput:IsVisible() then
            PNNSIM_ConsoleInput:SetFocus()
            PNNSIM_ConsoleInput:Insert(text)
        end
    else
        SetItemRef(link, text, button)
    end
end)

local PNNSIM_IsCleared = false

PNNSIM_ConsoleOutput_Msg:SetScript("OnMouseWheel", function(self, delta)
    if PNNSIM_IsCleared then
        PNNSIM_IsCleared = false
        self:Clear()
        local history = PNNSIM_CharData and PNNSIM_CharData.outputHistory
        if history then
            for i = PNNSIM_VisibleStartIdx, #history do
                self:AddMessage(history[i])
            end
        end
    end
    if delta > 0 then self:ScrollUp() else self:ScrollDown() end
end)

PNNSIM_ConsoleOutput_Scroll = CreateFrame("ScrollFrame", "PNNSIM_ConsoleOutput_Scroll", PNNSIM_Console)
PNNSIM_ConsoleOutput_Scroll:SetFrameLevel(9001)
PNNSIM_ConsoleOutput_Scroll:SetPoint("TOPLEFT", 8, -35)
PNNSIM_ConsoleOutput_Scroll:SetPoint("BOTTOMRIGHT", -8, 45)
PNNSIM_ConsoleOutput_Scroll:EnableMouseWheel(true)
PNNSIM_ConsoleOutput_Scroll:Hide()

PNNSIM_ConsoleOutput_Edit = CreateFrame("EditBox", "PNNSIM_ConsoleOutput_Edit", PNNSIM_ConsoleOutput_Scroll)
PNNSIM_ConsoleOutput_Edit:SetFrameLevel(9002)
PNNSIM_ConsoleOutput_Edit:SetMultiLine(true)
PNNSIM_ConsoleOutput_Edit:SetAutoFocus(false)
PNNSIM_ConsoleOutput_Edit:SetWidth(434)
PNNSIM_ConsoleOutput_Scroll:SetScrollChild(PNNSIM_ConsoleOutput_Edit)

PNNSIM_Console:HookScript("OnSizeChanged", function(self, width)
    PNNSIM_ConsoleOutput_Edit:SetWidth(width - 16)
end)

PNNSIM_ConsoleOutput_Edit:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
        local lines = {}
        local history = (PNNSIM_CharData and PNNSIM_CharData.outputHistory) or {}
        for i = PNNSIM_VisibleStartIdx, #history do table.insert(lines, history[i]) end
        self:SetText(table.concat(lines, "\n"))
        self:ClearFocus()
    end
end)
PNNSIM_ConsoleOutput_Edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

local function OnEditMouseWheel(self, delta)
    local currentScroll = PNNSIM_ConsoleOutput_Scroll:GetVerticalScroll()
    local maxScroll = PNNSIM_ConsoleOutput_Scroll:GetVerticalScrollRange()
    local newScroll = currentScroll - (delta * 40)
    if newScroll < 0 then newScroll = 0 end
    if newScroll > maxScroll then newScroll = maxScroll end
    PNNSIM_ConsoleOutput_Scroll:SetVerticalScroll(newScroll)
end

PNNSIM_ConsoleOutput_Scroll:SetScript("OnMouseWheel", OnEditMouseWheel)
PNNSIM_ConsoleOutput_Edit:SetScript("OnMouseWheel", OnEditMouseWheel)

local function AddConsoleMessage(text)
    if not PNNSIM_CharData then return end
    PNNSIM_CharData.outputHistory = PNNSIM_CharData.outputHistory or {}

    table.insert(PNNSIM_CharData.outputHistory, text)
    local maxLines = tonumber(GetConfVal("console.memory.linecount")) or 200
    while #PNNSIM_CharData.outputHistory > maxLines do
        table.remove(PNNSIM_CharData.outputHistory, 1)
        if PNNSIM_VisibleStartIdx > 1 then
            PNNSIM_VisibleStartIdx = PNNSIM_VisibleStartIdx - 1
        end
    end

    PNNSIM_ConsoleOutput_Msg:AddMessage(text)

    if PNNSIM_IsFreeSelect then
        local lines = {}
        for i = PNNSIM_VisibleStartIdx, #PNNSIM_CharData.outputHistory do table.insert(lines, PNNSIM_CharData.outputHistory[i]) end
        PNNSIM_ConsoleOutput_Edit:SetText(table.concat(lines, "\n"))
        PNNSIM_ConsoleOutput_Scroll:UpdateScrollChildRect()
        PNNSIM_ConsoleOutput_Scroll:SetVerticalScroll(PNNSIM_ConsoleOutput_Scroll:GetVerticalScrollRange())
    end
end

local HighlightCommands = {
    "console.show", "console.help", "console.save", "console.permclear", "console",
    "console.tracker.genesis.gold.reset", "console.tracker.session.gold.reset",
    "console.tracker.genesis.item.reset", "console.tracker.session.item.reset",
    "console.activeprofile",
    "console.theme.textsize.title",
    "kp list", "sl list", "help", "cls", "clear", "clr", "exit",
    "vendorprofile", "vendorprofile.create", "vendorprofile.list", "vendorprofile.keep.list", "vendorprofile.sell.list", "vendorprofile.tempsell",
    "tool.getproperties",
    "tool.sortbags",
    "tool.minimaprefresh",
    "tool.minimaprefresh.frequency"
}
table.sort(HighlightCommands, function(a, b) return string.len(a) > string.len(b) end)

local HighlightPatterns = {}
for _, cmd in ipairs(HighlightCommands) do
    HighlightPatterns[#HighlightPatterns + 1] = "(" .. string.gsub(cmd, "([%.%+%-%*%?%[%]%^%$%(%)%%])", "%%%1") .. ")"
end

local FILTER_OPS_NUMERIC = { "=", "!=", ">=", "<=", ">", "<" }
local FILTER_OPS_STRING  = { "=", "!=" }
local FILTER_ARG_KEYWORDS = { AND=true, OR=true, NOT=true }

local TabState = { active = false, matches = {}, index = 1, root = "", lastCompletion = "" }
local TabProfileCache = nil
PNNSIM_ProfilesEpoch = 0

PNNSIM_ConsoleInput:SetScript("OnTabPressed", function(self)
    local rawText = self:GetText()
    if rawText == "" then return end

    local currentText = string.lower(rawText)

    -- Filter argument mode: fires when command before first space is a filter-taking command
    local function tryCycle()
        if TabState.active and currentText == string.lower(TabState.lastCompletion) and #TabState.matches > 1 then
            TabState.index = TabState.index + 1
            if TabState.index > #TabState.matches then TabState.index = 1 end
            local c = TabState.root .. TabState.matches[TabState.index]
            self:SetText(c); self:SetCursorPosition(#c)
            TabState.lastCompletion = string.lower(c)
            return true
        end
        return false
    end
    local function applyFirst(root, matches)
        TabState.matches = matches; TabState.index = 1; TabState.root = root
        if #matches > 0 then
            TabState.active = true
            local c = root .. matches[1]
            self:SetText(c); self:SetCursorPosition(#c)
            TabState.lastCompletion = string.lower(c)
        else
            TabState.active = false
        end
    end
    local spacePos = string.find(rawText, " ", 1, true)
    if spacePos then
        local cmdPart = string.lower(string.sub(rawText, 1, spacePos - 1))
        local isFilterCmd = string.sub(cmdPart, -9)  == ".keep.add"
                         or string.sub(cmdPart, -9)  == ".sell.add"
                         or string.sub(cmdPart, -16) == ".keep.mod.commit"
                         or string.sub(cmdPart, -16) == ".sell.mod.commit"
        if isFilterCmd then
            local argPart = string.sub(rawText, spacePos + 1)
            local lastWord = string.match(argPart, "(%S+)%s*$") or ""
            local isKeyword = FILTER_ARG_KEYWORDS[string.upper(lastWord)] or lastWord == "(" or lastWord == ")"
            local currentToken = isKeyword and "" or lastWord
            local filterRoot
            if currentToken == "" then
                filterRoot = rawText
                if string.sub(filterRoot, -1) ~= " " then filterRoot = filterRoot .. " " end
            else
                filterRoot = string.sub(rawText, 1, #rawText - #currentToken)
            end
            local fieldPart = string.match(currentToken, "^([%a]+)") or ""
            local opPart    = string.sub(currentToken, #fieldPart + 1)
            if opPart == "" then
                -- Field completion mode
                if tryCycle() then return end
                local prefix = string.upper(fieldPart)
                local matches = {}
                for _, ff in ipairs(PNNSIM_FilterFields) do
                    if string.sub(ff.name, 1, #prefix) == prefix then table.insert(matches, ff.name) end
                end
                applyFirst(filterRoot, matches); return
            else
                -- Operator completion mode
                local matchedField = nil
                for _, ff in ipairs(PNNSIM_FilterFields) do
                    if string.lower(ff.name) == string.lower(fieldPart) then matchedField = ff; break end
                end
                if not matchedField then
                    if tryCycle() then return end
                    local prefix = string.upper(fieldPart)
                    local matches = {}
                    for _, ff in ipairs(PNNSIM_FilterFields) do
                        if string.sub(ff.name, 1, #prefix) == prefix then table.insert(matches, ff.name) end
                    end
                    applyFirst(filterRoot, matches); return
                end
                if tryCycle() then return end
                local validOps = matchedField.isNumeric and FILTER_OPS_NUMERIC or FILTER_OPS_STRING
                local startIdx = 1
                for i, op in ipairs(validOps) do
                    if op == opPart then startIdx = (i % #validOps) + 1; break end
                end
                local matches = {}
                for i = 0, #validOps - 1 do
                    local idx = ((startIdx - 1 + i) % #validOps) + 1
                    table.insert(matches, matchedField.name .. validOps[idx])
                end
                applyFirst(filterRoot, matches); return
            end
        end
    end

    -- Existing command completion below
    if TabState.active and currentText == string.lower(TabState.lastCompletion) and #TabState.matches > 1 then
        TabState.index = TabState.index + 1
        if TabState.index > #TabState.matches then
            TabState.index = 1
        end
        local completion = TabState.root .. TabState.matches[TabState.index]
        self:SetText(completion)
        self:SetCursorPosition(string.len(completion))
        TabState.lastCompletion = string.lower(completion)
        return
    end
    
    TabState.matches = {}
    TabState.index = 1
    
    local root = ""
    local prefix = currentText

    local uniqueMatches = {}

    if not TabProfileCache or TabProfileCache.epoch ~= (PNNSIM_ProfilesEpoch or 0) then
        local cmds = {}
        local myProfiles = PNNSIM_Profiles and PNNSIM_Profiles[UnitName("player")]
        if myProfiles then
            for profileKey, _ in pairs(myProfiles) do
                local p = string.lower(profileKey)
                cmds[#cmds+1] = "vendorprofile." .. p .. ".keep.add"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".keep.rem"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".keep.rem.listid"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".sell.add"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".sell.rem"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".sell.rem.listid"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".list"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".list.keep"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".list.sell"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".activate"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".delete.confirm"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".deactivate"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".autosell.on"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".autosell.off"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".search"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".cleanup"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".keep.mod"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".sell.mod"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".zone.list"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".zone.register"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".zone.add"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".zone.delete"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".zone.enable"
                cmds[#cmds+1] = "vendorprofile." .. p .. ".zone.disable"
            end
        end

        -- Settings keys from PNNSIM_ConfigDefaults
        if PNNSIM_ConfigDefaults then
            for k in pairs(PNNSIM_ConfigDefaults) do
                cmds[#cmds+1] = k
            end
        end

        -- Non-setting commands not covered by ConfigDefaults or HighlightCommands
        cmds[#cmds+1] = "console.show"
        cmds[#cmds+1] = "console.help"
        cmds[#cmds+1] = "console.tracker.show"
        cmds[#cmds+1] = "tool.simplemailer.bagkeep.list"
        cmds[#cmds+1] = "tool.simplemailer.bagkeep.add"
        cmds[#cmds+1] = "tool.simplemailer.bagkeep.rem"
        cmds[#cmds+1] = "tool.simplemailer.send"

        -- Known char names as path prefixes
        local charSeen = {}
        if PNNSIM_ConsoleConfig then
            for ck in pairs(PNNSIM_ConsoleConfig) do
                local c = string.match(ck, "^([^%.]+)%.")
                if c and not charSeen[c] then
                    charSeen[c] = true
                    cmds[#cmds+1] = c .. "."
                end
            end
        end
        if PNNSIM_Profiles then
            for c in pairs(PNNSIM_Profiles) do
                if not charSeen[c] then
                    charSeen[c] = true
                    cmds[#cmds+1] = c .. "."
                end
            end
        end

        TabProfileCache = { cmds = cmds, epoch = PNNSIM_ProfilesEpoch or 0 }
    end

    local function tryMatch(cmd)
        if string.sub(cmd, 1, string.len(prefix)) == prefix then
            local remainder = string.sub(cmd, string.len(prefix) + 1)
            local next_segment = string.match(remainder, "^([^%s%.]*[%s%.]?)")
            if next_segment and next_segment ~= "" then
                local suggestion = prefix .. next_segment
                -- Strip trailing dot: "tool.bagspace." deduplicates with "tool.bagspace"
                if string.sub(suggestion, -1) == "." then
                    suggestion = string.sub(suggestion, 1, -2)
                end
                if not uniqueMatches[suggestion] then
                    uniqueMatches[suggestion] = true
                    table.insert(TabState.matches, suggestion)
                end
            end
        end
    end

    for _, cmd in ipairs(HighlightCommands) do tryMatch(cmd) end
    for _, cmd in ipairs(TabProfileCache.cmds) do tryMatch(cmd) end
    
    if #TabState.matches > 0 then
        table.sort(TabState.matches)
        TabState.active = true
        TabState.root = root
        local completion = root .. TabState.matches[1]
        self:SetText(completion)
        self:SetCursorPosition(string.len(completion))
        TabState.lastCompletion = string.lower(completion)
    else
        TabState.active = false
    end
end)

function PNNSIM_Console_Print(rawText)
    local cmdHex = GetConfVal("console.theme.consolecolor.textcolor.command")
    local outHex = GetConfVal("console.theme.consolecolor.textcolor.output")
    local outText = rawText

    for _, pattern in ipairs(HighlightPatterns) do
        outText = string.gsub(outText, pattern, "|cFF"..cmdHex.."%1|r|cFF"..outHex)
    end
    
    local finalStr = "|cFF" .. outHex .. outText .. "|r"
    AddConsoleMessage(finalStr)
end

function PNNSIM_Console_PrintRaw(rawText)
    AddConsoleMessage(rawText)
end

function PNNSIM_UpdateConsoleTitleBar()
    if not PNNSIM_ConsoleTitleLabel then return end
    local char = GetCachedPlayerName()
    local stored = PNNSIM_ConsoleConfig and PNNSIM_ConsoleConfig[char .. ".console.theme.textsize.title"]
    local titleSize = tonumber(stored) or tonumber(GetConfVal("console.theme.textsize")) or 14
    PNNSIM_ApplyFont(PNNSIM_ConsoleTitleLabel, titleSize, "OUTLINE")
    local activeProfileName, activeProfile = nil, nil
    if PNNSIM_GetActiveProfile then
        activeProfileName, activeProfile = PNNSIM_GetActiveProfile()
    end
    if activeProfileName and activeProfile then
        local dispName = activeProfile.displayName or activeProfileName
        local cmdHex = GetConfVal("console.theme.consolecolor.textcolor.command")
        PNNSIM_ConsoleTitleLabel:SetText("|cFF" .. cmdHex .. char .. ".vendorprofile." .. dispName .. "|r")
        PNNSIM_ConsoleTitleBtn:EnableMouse(true)
    else
        local errHex = GetConfVal("console.theme.consolecolor.textcolor.error")
        PNNSIM_ConsoleTitleLabel:SetText("|cFF" .. errHex .. char .. ".vendorprofile.void|r")
        PNNSIM_ConsoleTitleBtn:EnableMouse(false)
    end
end

function PNNSIM_InitConsoleTheme()
    if not PNNSIM_ConsoleConfig then return end
    
    local tSize = tonumber(GetConfVal("console.theme.textsize"))
    local bgR, bgG, bgB = HexToRGB(GetConfVal("console.theme.consolecolor.bg"))
    local bdR, bdG, bdB = HexToRGB(GetConfVal("console.theme.consolecolor.border"))
    local ibgR, ibgG, ibgB = HexToRGB(GetConfVal("console.theme.consolecolor.input.bg"))
    local cmdR, cmdG, cmdB = HexToRGB(GetConfVal("console.theme.consolecolor.textcolor.command"))
    
    PNNSIM_Console:SetBackdropColor(bgR, bgG, bgB, 1)
    PNNSIM_Console:SetBackdropBorderColor(bdR, bdG, bdB, 1)
    
    PNNSIM_ConsoleInput:SetBackdropColor(ibgR, ibgG, ibgB, 1)
    PNNSIM_ConsoleInput:SetBackdropBorderColor(bdR, bdG, bdB, 1)

    PNNSIM_ApplyFont(PNNSIM_ConsoleOutput_Msg, tSize, "OUTLINE")
    PNNSIM_ApplyFont(PNNSIM_ConsoleOutput_Edit, tSize, "OUTLINE")
    PNNSIM_ApplyFont(PNNSIM_ConsoleInput, tSize, "OUTLINE")
    PNNSIM_ConsoleInput:SetTextColor(cmdR, cmdG, cmdB, 1)
    PNNSIM_ConsoleInput:SetHistoryLines(tonumber(GetConfVal("console.memory.previouscommands")) or 50)

    PNNSIM_ApplyFont(PNNSIM_CloseBtn:GetFontString(), tSize, "OUTLINE")
    PNNSIM_ApplyFont(PNNSIM_LockBtn:GetFontString(), tSize, "OUTLINE")
    PNNSIM_ApplyFont(PNNSIM_MoveBtn:GetFontString(), tSize, "OUTLINE")
    PNNSIM_ApplyFont(PNNSIM_SelectBtn:GetFontString(), tSize, "OUTLINE")
    
    local bdHex = GetConfVal("console.theme.consolecolor.border")
    PNNSIM_CloseBtn:GetFontString():SetText("|cFF"..bdHex.."X|r")
    
    if PNNSIM_IsLocked then
        PNNSIM_LockBtn:GetFontString():SetText("|cFF00aa00L|r")
        PNNSIM_MoveBtn:Disable()
        local darkR, darkG, darkB = bdR * 0.4, bdG * 0.4, bdB * 0.4
        local darkHex = string.format("%02x%02x%02x", darkR*255, darkG*255, darkB*255)
        PNNSIM_MoveBtn:GetFontString():SetText("|cFF"..darkHex.."■|r")
        PNNSIM_MoveBtn.tooltipText = "Disabled because window is locked."
    else
        PNNSIM_LockBtn:GetFontString():SetText("|cFF"..bdHex.."U|r")
        PNNSIM_MoveBtn:Enable()
        PNNSIM_MoveBtn:GetFontString():SetText("|cFF"..bdHex.."■|r")
        PNNSIM_MoveBtn.tooltipText = "Drag to Move"
    end
    
    if PNNSIM_IsFreeSelect then
        PNNSIM_SelectBtn:GetFontString():SetText("|cFF00aa00S|r")
    else
        PNNSIM_SelectBtn:GetFontString():SetText("|cFF"..bdHex.."S|r")
    end

    if PNNSIM_ResizeGrip:GetNormalTexture() then PNNSIM_ResizeGrip:GetNormalTexture():SetVertexColor(bdR, bdG, bdB, 1) end
    if PNNSIM_ResizeGrip:GetHighlightTexture() then PNNSIM_ResizeGrip:GetHighlightTexture():SetVertexColor(bdR, bdG, bdB, 1) end
    if PNNSIM_ResizeGrip:GetPushedTexture() then PNNSIM_ResizeGrip:GetPushedTexture():SetVertexColor(bdR*0.5, bdG*0.5, bdB*0.5, 1) end

    PNNSIM_ConsoleOutput_Msg:Clear()
    local maxLines = tonumber(GetConfVal("console.memory.linecount")) or 200
    PNNSIM_ConsoleOutput_Msg:SetMaxLines(maxLines)
    local history = PNNSIM_CharData and PNNSIM_CharData.outputHistory
    if history then
        for i = PNNSIM_VisibleStartIdx, #history do
            PNNSIM_ConsoleOutput_Msg:AddMessage(history[i])
        end
    end

    PNNSIM_UpdateConsoleTitleBar()
end

local PNNSIM_ConsoleLoader = CreateFrame("Frame")
PNNSIM_ConsoleLoader:RegisterEvent("ADDON_LOADED")
PNNSIM_ConsoleLoader:RegisterEvent("PLAYER_LOGOUT")
PNNSIM_ConsoleLoader:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" and addon == "Prebbles_NNS_InvMngmt" then
        PNNSIM_ConsoleConfig = PNNSIM_ConsoleConfig or {}
        PNNSIM_CharData = PNNSIM_CharData or {}
        local playerName = UnitName("player")

        PNNSIM_CharData.inputHistory = PNNSIM_CharData.inputHistory or {}

        PNNSIM_InitConsoleTheme()
        ToggleFreeSelect(false)

        for _, text in ipairs(PNNSIM_CharData.inputHistory) do
            PNNSIM_ConsoleInput:AddHistoryLine(text)
        end

        if PNNSIM_ConsoleConfig[playerName..".console.isOpen"] then
            PNNSIM_Console:Show()
        end
    elseif event == "PLAYER_LOGOUT" then
        if PNNSIM_CharData and PNNSIM_SessionTracker and PNNSIM_SessionTracker.startTime then
            local sessTime = math.max(1, GetTime() - PNNSIM_SessionTracker.startTime)
            PNNSIM_CharData["tracker.genesis.time"] = (PNNSIM_CharData["tracker.genesis.time"] or 0) + sessTime
        end
    end
end)

if WorldFrame then
    WorldFrame:HookScript("OnMouseDown", function()
        if PNNSIM_ConsoleInput then
            PNNSIM_ConsoleInput:ClearFocus()
        end
    end)
end

PNNSIM_ConsoleInput:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)

PNNSIM_ConsoleInput:SetScript("OnEnterPressed", function(self)
    local PNNSIM_text = self:GetText()
    if PNNSIM_text == "" then
        self:ClearFocus()
        return
    end
    self:SetText("")

    PNNSIM_CharData = PNNSIM_CharData or {}
    PNNSIM_CharData.inputHistory = PNNSIM_CharData.inputHistory or {}

    self:AddHistoryLine(PNNSIM_text)
    table.insert(PNNSIM_CharData.inputHistory, PNNSIM_text)
    local maxCmds = tonumber(GetConfVal("console.memory.previouscommands")) or 50
    while #PNNSIM_CharData.inputHistory > maxCmds do
        table.remove(PNNSIM_CharData.inputHistory, 1)
    end
    
    local userHex = GetConfVal("console.theme.consolecolor.user")
    local cmdHex = GetConfVal("console.theme.consolecolor.textcolor.command")
    AddConsoleMessage("|cFF"..userHex.."r@nps:/$ |r|cFF"..cmdHex..PNNSIM_text.."|r")
    
    local PNNSIM_cmd_lower = string.lower(PNNSIM_text)
    local PNNSIM_base_cmd = string.match(PNNSIM_cmd_lower, "^(%S+)")

    -- Settings path-navigation interceptor (tools_settings.lua)
    if PNNSIM_HandleSettingsInput and PNNSIM_HandleSettingsInput(PNNSIM_text) then return end

    if PNNSIM_base_cmd == "cls" or PNNSIM_base_cmd == "clr" or PNNSIM_base_cmd == "clear" then
        PNNSIM_IsCleared = true
        PNNSIM_VisibleStartIdx = #((PNNSIM_CharData and PNNSIM_CharData.outputHistory) or {}) + 1
        PNNSIM_ConsoleOutput_Msg:Clear()
        if PNNSIM_IsFreeSelect then
            PNNSIM_ConsoleOutput_Edit:SetText("")
        end
        return
    elseif PNNSIM_base_cmd == "console.permclear" then
        if PNNSIM_CharData then PNNSIM_CharData.outputHistory = {} end
        PNNSIM_VisibleStartIdx = 1
        PNNSIM_ConsoleOutput_Msg:Clear()
        if PNNSIM_IsFreeSelect then
            PNNSIM_ConsoleOutput_Edit:SetText("")
        end
        return
    elseif PNNSIM_base_cmd == "console.save" then
        PNNSIM_ConsoleConfig[UnitName("player")..".console.isOpen"] = PNNSIM_Console:IsShown()
        ReloadUI()
        return
    elseif PNNSIM_base_cmd == "ls" then
        local outHex = GetConfVal("console.theme.consolecolor.textcolor.output")
        AddConsoleMessage("|cFF"..outHex.."Nice try jackass|r")
    elseif PNNSIM_base_cmd == "exit" then
        PNNSIM_Console:Hide()
        PNNSIM_ConsoleConfig[UnitName("player")..".console.isOpen"] = false
    else
        if PNNSIM_ProcessCommand then
            PNNSIM_ProcessCommand(PNNSIM_text, true)
        end
    end
end)

PNNSIM_Console:SetScript("OnMouseDown", function(self, button)
    PNNSIM_ConsoleInput:ClearFocus()
end)

hooksecurefunc("ChatEdit_InsertLink", function(text)
    if PNNSIM_ConsoleInput and PNNSIM_ConsoleInput:HasFocus() then
        PNNSIM_ConsoleInput:Insert(text)
        return true
    end
end)