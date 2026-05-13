-- tools_bagspace.lua

local FONT          = "Interface\\AddOns\\Prebbles_NNS_InvMngmt\\assets\\fonts\\VCR_OSD_MONO_1.001.ttf"
local FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"

local bagLabel = nil
local cachedPlayerName = nil

local function GetSetting(key)
    if PNNSIM_ConsoleConfig then
        cachedPlayerName = cachedPlayerName or UnitName("player")
        local v = PNNSIM_ConsoleConfig[cachedPlayerName .. "." .. key]
        if v ~= nil then return v end
    end
    local entry = PNNSIM_ConfigDefaults and PNNSIM_ConfigDefaults[key]
    return entry and entry.default or nil
end

local function IsEnabled()
    return GetSetting("tool.bagspace") ~= "0"
end

local function GetThreshold(name)
    return tonumber(GetSetting("tool.bagspace.threshold." .. name)) or 0
end

local function GetColor(name)
    return GetSetting("tool.bagspace.color." .. name) or "ffffff"
end

local function ApplyFont(obj, size, flags)
    local ok = pcall(function() obj:SetFont(FONT, size, flags) end)
    if not ok then obj:SetFont(FALLBACK_FONT, size, flags) end
end

local function ApplyColorHex(obj, hex)
    hex = hex or "ffffff"
    obj:SetTextColor(
        tonumber("0x" .. hex:sub(1, 2)) / 255,
        tonumber("0x" .. hex:sub(3, 4)) / 255,
        tonumber("0x" .. hex:sub(5, 6)) / 255
    )
end

local function CountBagSlots()
    local free, total = 0, 0
    for bag = 0, 4 do
        local size = GetContainerNumSlots(bag)
        total = total + size
        for slot = 1, size do
            if not GetContainerItemLink(bag, slot) then
                free = free + 1
            end
        end
    end
    return free, total
end

local function EnsureLabel()
    if bagLabel then return end
    bagLabel = MainMenuBarBackpackButton:CreateFontString(nil, "OVERLAY")
    bagLabel:SetPoint("CENTER", MainMenuBarBackpackButton, "CENTER", 0, 0)
    ApplyFont(bagLabel, 14, "OUTLINE")
    bagLabel:SetJustifyH("CENTER")
end

local bagTicker = CreateFrame("Frame")
bagTicker:SetScript("OnUpdate", function(self, elapsed)
    self.updateTimer = (self.updateTimer or 0) + elapsed
    self.flashTimer  = (self.flashTimer  or 0) + elapsed

    if not IsEnabled() then
        if bagLabel then bagLabel:Hide() end
        self.updateTimer = 0
        self.flashTimer  = 0
        self.flashStep   = 0
        return
    end

    EnsureLabel()
    bagLabel:Show()

    if self.updateTimer >= 0.1 then
        self.updateTimer = 0

        local free, total = CountBagSlots()
        if total == 0 then return end

        self.freeSlots   = free
        self.freePercent = math.floor(free / total * 100)
        bagLabel:SetText(tostring(free))
    end

    local fp = self.freePercent
    if fp == nil then return end

    local tEm = GetThreshold("empty")
    local tLo = GetThreshold("low")
    local tMi = GetThreshold("mid")

    if fp <= tEm then
        -- Flash: advance color step every 0.25s
        if self.flashTimer >= 0.25 then
            self.flashTimer = 0
            self.flashStep = ((self.flashStep or 0) + 1) % 3
        end
        local flashColors = { [0] = "empty", [1] = "mid", [2] = "high" }
        ApplyColorHex(bagLabel, GetColor(flashColors[self.flashStep or 0]))
    else
        self.flashTimer = 0
        self.flashStep  = 0
        if fp <= tLo then
            ApplyColorHex(bagLabel, GetColor("empty"))
        elseif fp <= tMi then
            ApplyColorHex(bagLabel, GetColor("mid"))
        else
            ApplyColorHex(bagLabel, GetColor("high"))
        end
    end
end)
