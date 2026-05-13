-- core.lua

local PNNSIM_Core = CreateFrame("Frame")
PNNSIM_Core:RegisterEvent("MERCHANT_SHOW")
PNNSIM_Core:RegisterEvent("MERCHANT_CLOSED")
PNNSIM_Core:RegisterEvent("BAG_UPDATE_DELAYED")
PNNSIM_Core:RegisterEvent("PLAYER_LOGIN")
PNNSIM_Core:RegisterEvent("PLAYER_REGEN_DISABLED")
PNNSIM_Core:RegisterEvent("PLAYER_LOGOUT")

local PNNSIM_ScanTooltip = CreateFrame("GameTooltip", "PNNSIM_ScanTooltip", nil, "GameTooltipTemplate")
local PNNSIM_ItemDataCache = {}

PNNSIM_FilterFields = {
    { name = "EQUIPLOC",  isNumeric = false },
    { name = "ID",        isNumeric = true  },
    { name = "ILVL",      isNumeric = true  },
    { name = "INTOOLTIP", isNumeric = false },
    { name = "NAME",      isNumeric = false },
    { name = "PRICE",     isNumeric = true  },
    { name = "QUALITY",   isNumeric = true  },
    { name = "REQLEVEL",  isNumeric = true  },
    { name = "STACK",     isNumeric = true  },
    { name = "SUBTYPE",   isNumeric = false },
    { name = "TYPE",      isNumeric = false },
}

local grayDeleteBusy = false
local delNoValueBusy = false
local sortBusy = false
local sortBagsWasOpen = {}
local function sortRestoreBags()
    for bag = 1, 4 do
        if not sortBagsWasOpen[bag] then CloseBag(bag) end
    end
end
local sellBusy = false
local activeSellState = nil

local function PNNSIM_AbortSell(reason)
    if not sellBusy then return end
    if activeSellState then
        activeSellState.queue = {}
        activeSellState = nil
    end
    sellBusy = false
    local msg = "Selling cancelled — " .. (reason or "merchant closed") .. "."
    if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
end

local function GetConfValCore(prop)
    local fullKey = UnitName("player") .. "." .. prop
    if PNNSIM_ConsoleConfig and PNNSIM_ConsoleConfig[fullKey] ~= nil then
        return tostring(PNNSIM_ConsoleConfig[fullKey])
    end
    return "0"
end

function PNNSIM_GetActiveProfile()
    if not PNNSIM_ConsoleConfig then return nil, nil end
    local charName = UnitName("player")
    local pKey = PNNSIM_ConsoleConfig[charName .. ".console.activeprofile"]
    if not pKey or pKey == "" or pKey == "void" then return nil, nil end
    local charProfiles = PNNSIM_Profiles and PNNSIM_Profiles[charName]
    if not charProfiles then return nil, nil end
    local profile = charProfiles[pKey]
    if not profile then return nil, nil end
    return pKey, profile
end

local function EvalSingleCondition(condStr, itemData)
    local prop, op, valStr = string.match(condStr, "^([%w_]+)%s*([=><!]+)%s*(.+)$")
    if not prop then return false end
    prop = string.upper(prop)
    local itemVal = itemData[prop]
    if itemVal == nil then return false end
    
    valStr = string.gsub(strtrim(valStr), '^"(.*)"$', '%1')
    if op == "=" then
        local cleanVal = string.match(valStr, "^%*(.+)%*$")
        if cleanVal then
            return string.find(string.lower(tostring(itemVal)), string.lower(cleanVal), 1, true) ~= nil
        else
            return string.lower(tostring(itemVal)) == string.lower(valStr)
        end
    elseif op == "!=" then
        return string.lower(tostring(itemVal)) ~= string.lower(valStr)
    else
        local nItemVal = tonumber(itemVal)
        local nValStr = tonumber(valStr)
        if nItemVal and nValStr then
            if op == ">=" then return nItemVal >= nValStr end
            if op == "<=" then return nItemVal <= nValStr end
            if op == ">" then return nItemVal > nValStr end
            if op == "<" then return nItemVal < nValStr end
        end
        return false
    end
end

local function ParseFilter(filterStr, itemData)
    local s = string.gsub(filterStr, "%s+[aA][nN][dD]%s+", "&")
    s = string.gsub(s, "%s+[oO][rR]%s+", "|")
    s = string.gsub(s, "%s+[nN][oO][tT]%s+", "!")
    s = string.gsub(s, "^[nN][oO][tT]%s+", "!")
    
    local tokens = {}
    local currentCond = ""
    
    local function pushCond()
        local c = strtrim(currentCond)
        if c ~= "" then
            table.insert(tokens, {type="COND", val=c})
            currentCond = ""
        end
    end
    
    local i = 1
    while i <= #s do
        local char = string.sub(s, i, i)
        local nextChar = string.sub(s, i+1, i+1)
        
        if char == "(" or char == ")" or char == "&" or char == "|" then
            pushCond()
            local op = char
            if op == "&" then op = "AND" end
            if op == "|" then op = "OR" end
            table.insert(tokens, {type="OP", val=op})
        elseif char == "!" and nextChar ~= "=" then
            pushCond()
            table.insert(tokens, {type="OP", val="NOT"})
        else
            currentCond = currentCond .. char
        end
        i = i + 1
    end
    pushCond()

    local prec = {["NOT"] = 3, ["AND"] = 2, ["OR"] = 1, ["("] = 0, [")"] = 0}
    local output = {}
    local ops = {}
    
    for _, token in ipairs(tokens) do
        if token.type == "COND" then
            local res = EvalSingleCondition(token.val, itemData)
            table.insert(output, res)
        elseif token.type == "OP" then
            if token.val == "(" then
                table.insert(ops, token.val)
            elseif token.val == ")" then
                while #ops > 0 and ops[#ops] ~= "(" do
                    table.insert(output, table.remove(ops))
                end
                if #ops > 0 and ops[#ops] == "(" then
                    table.remove(ops)
                end
            else
                while #ops > 0 and prec[ops[#ops]] and prec[ops[#ops]] >= prec[token.val] do
                    table.insert(output, table.remove(ops))
                end
                table.insert(ops, token.val)
            end
        end
    end
    while #ops > 0 do
        table.insert(output, table.remove(ops))
    end

    local stack = {}
    for _, t in ipairs(output) do
        if type(t) == "boolean" then
            table.insert(stack, t)
        elseif t == "NOT" then
            local val = table.remove(stack)
            if val == nil then return false end
            table.insert(stack, not val)
        elseif t == "AND" then
            local b = table.remove(stack)
            local a = table.remove(stack)
            if a == nil or b == nil then return false end
            table.insert(stack, a and b)
        elseif t == "OR" then
            local b = table.remove(stack)
            local a = table.remove(stack)
            if a == nil or b == nil then return false end
            table.insert(stack, a or b)
        end
    end
    
    return stack[1] == true
end

function PNNSIM_ValidateFilter(filterStr)
    local s = string.gsub(filterStr, "%s+[aA][nN][dD]%s+", "&")
    s = string.gsub(s, "%s+[oO][rR]%s+", "|")
    s = string.gsub(s, "%s+[nN][oO][tT]%s+", "!")
    s = string.gsub(s, "^[nN][oO][tT]%s+", "!")

    local function splitTopLevel(str, sep)
        local parts = {}; local depth = 0; local current = ""
        for i = 1, #str do
            local c = string.sub(str, i, i)
            if c == "(" then depth = depth + 1; current = current .. c
            elseif c == ")" then depth = depth - 1; current = current .. c
            elseif c == sep and depth == 0 then table.insert(parts, strtrim(current)); current = ""
            else current = current .. c end
        end
        if strtrim(current) ~= "" then table.insert(parts, strtrim(current)) end
        return parts
    end

    local function invertOp(op)
        local inv = { ["="]="!=", ["!="]="=", [">"]="<=", ["<"]=">=", [">="]="<", ["<="]=">" }
        return inv[op]
    end

    local function parseCond(condStr)
        condStr = strtrim(condStr)
        local isNegated = false
        local inner = string.match(condStr, "^!%((.+)%)$")
        if inner then
            local depth = 0; local hasTopOp = false
            for i = 1, #inner do
                local c = string.sub(inner, i, i)
                if c == "(" then depth = depth + 1
                elseif c == ")" then depth = depth - 1
                elseif (c == "&" or c == "|") and depth == 0 then hasTopOp = true; break end
            end
            if not hasTopOp then condStr = inner; isNegated = true
            else return nil end
        end
        local stripped = string.match(condStr, "^%((.+)%)$")
        if stripped then condStr = stripped end
        local prop, op, val = string.match(condStr, "^([%w_]+)%s*([=><!]+)%s*(.+)$")
        if not prop then return nil end
        if isNegated then op = invertOp(op); if not op then return nil end end
        return { field = string.upper(prop), op = op, val = strtrim(val) }
    end

    local function checkBranch(branchStr)
        local conditions = splitTopLevel(branchStr, "&")
        local byField = {}
        for _, c in ipairs(conditions) do
            local parsed = parseCond(c)
            if parsed then
                byField[parsed.field] = byField[parsed.field] or {}
                table.insert(byField[parsed.field], parsed)
            end
        end
        for field, conds in pairs(byField) do
            local isNum = false
            for _, ff in ipairs(PNNSIM_FilterFields) do
                if ff.name == field then isNum = ff.isNumeric; break end
            end
            if isNum then
                local lb, lbInc, ub, ubInc = nil, nil, nil, nil
                local eqs, neqs = {}, {}
                for _, c in ipairs(conds) do
                    local n = tonumber(c.val)
                    if n then
                        if c.op == "=" then table.insert(eqs, n)
                        elseif c.op == "!=" then table.insert(neqs, n)
                        elseif c.op == ">=" then
                            if not lb or n > lb or (n == lb and not lbInc) then lb, lbInc = n, true end
                        elseif c.op == ">" then
                            if not lb or n > lb or (n == lb and lbInc) then lb, lbInc = n, false end
                        elseif c.op == "<=" then
                            if not ub or n < ub or (n == ub and not ubInc) then ub, ubInc = n, true end
                        elseif c.op == "<" then
                            if not ub or n < ub or (n == ub and ubInc) then ub, ubInc = n, false end
                        end
                    end
                end
                if lb and ub then
                    if lb > ub or (lb == ub and (not lbInc or not ubInc)) then
                        local lbS = (lbInc and ">=" or ">") .. lb
                        local ubS = (ubInc and "<=" or "<") .. ub
                        return "Filter cannot match any item: " .. field .. " cannot satisfy " .. lbS .. " AND " .. ubS .. "."
                    end
                end
                if #eqs > 1 then
                    local first = eqs[1]
                    for _, v in ipairs(eqs) do
                        if v ~= first then
                            return "Filter cannot match any item: " .. field .. " cannot equal both " .. first .. " and " .. v .. "."
                        end
                    end
                end
                for _, eq in ipairs(eqs) do
                    if lb and ((lbInc and eq < lb) or (not lbInc and eq <= lb)) then
                        return "Filter cannot match any item: " .. field .. "=" .. eq .. " conflicts with " .. (lbInc and ">=" or ">") .. lb .. "."
                    end
                    if ub and ((ubInc and eq > ub) or (not ubInc and eq >= ub)) then
                        return "Filter cannot match any item: " .. field .. "=" .. eq .. " conflicts with " .. (ubInc and "<=" or "<") .. ub .. "."
                    end
                    for _, neq in ipairs(neqs) do
                        if eq == neq then
                            return "Filter cannot match any item: " .. field .. "=" .. eq .. " contradicts " .. field .. "!=" .. neq .. "."
                        end
                    end
                end
            else
                local exactVals, neqVals = {}, {}
                for _, c in ipairs(conds) do
                    if c.op == "=" and not string.match(c.val, "^%*(.+)%*$") then
                        table.insert(exactVals, string.lower(c.val))
                    elseif c.op == "!=" then
                        table.insert(neqVals, string.lower(c.val))
                    end
                end
                if #exactVals > 1 then
                    local first = exactVals[1]
                    for _, v in ipairs(exactVals) do
                        if v ~= first then
                            return "Filter cannot match any item: " .. field .. " cannot equal both '" .. exactVals[1] .. "' and '" .. v .. "'."
                        end
                    end
                end
                for _, eq in ipairs(exactVals) do
                    for _, neq in ipairs(neqVals) do
                        if eq == neq then
                            return "Filter cannot match any item: " .. field .. "='" .. eq .. "' contradicts " .. field .. "!='" .. neq .. "'."
                        end
                    end
                end
            end
        end
        return nil
    end

    local orBranches = splitTopLevel(s, "|")
    local lastErr = nil
    for _, branch in ipairs(orBranches) do
        local err = checkBranch(branch)
        if not err then return nil end
        lastErr = err
    end
    return lastErr
end

function PNNSIM_BuildItemData(itemID, itemLink)
    if PNNSIM_ItemDataCache[itemID] then return PNNSIM_ItemDataCache[itemID] end

    local itemName, _, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, _, itemSellPrice = GetItemInfo(itemLink)
    if not itemName then return nil end

    PNNSIM_ScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    PNNSIM_ScanTooltip:ClearLines()
    PNNSIM_ScanTooltip:SetHyperlink(itemLink)
    local tooltipText = ""
    for i = 1, PNNSIM_ScanTooltip:NumLines() do
        local lineL = _G["PNNSIM_ScanTooltipTextLeft"..i]
        if lineL and lineL:GetText() then
            tooltipText = tooltipText .. " " .. lineL:GetText()
        end
        local lineR = _G["PNNSIM_ScanTooltipTextRight"..i]
        if lineR and lineR:GetText() then
            tooltipText = tooltipText .. " " .. lineR:GetText()
        end
    end

    local data = {
        ID = itemID,
        NAME = itemName,
        QUALITY = itemRarity,
        ILVL = itemLevel,
        REQLEVEL = itemMinLevel,
        TYPE = itemType,
        SUBTYPE = itemSubType,
        STACK = itemStackCount,
        EQUIPLOC = itemEquipLoc,
        PRICE = itemSellPrice,
        INTOOLTIP = tooltipText
    }
    PNNSIM_ItemDataCache[itemID] = data
    return data
end

function PNNSIM_IsItemInList(itemData, list)
    if not list or not itemData then return false, nil end
    for _, entry in ipairs(list) do
        if entry.type == "id" then
            if itemData.ID == entry.value then return true, entry end
        elseif entry.type == "exact" then
            if string.lower(itemData.NAME) == string.lower(entry.value) then return true, entry end
        elseif entry.type == "match" then
            if string.find(string.lower(itemData.NAME), string.lower(entry.value), 1, true) then return true, entry end
        elseif entry.type == "filter" then
            if ParseFilter(entry.value, itemData) then return true, entry end
        end
    end
    return false, nil
end

function PNNSIM_IsExplicitlyInSellList(itemData, list)
    if not list or not itemData then return false end
    for _, entry in ipairs(list) do
        if entry.type == "id" and itemData.ID == entry.value then return true end
        if entry.type == "exact" and string.lower(itemData.NAME) == string.lower(entry.value) then return true end
    end
    return false
end

local function PNNSIM_GetSellBatchSize()
    local total = 0
    for bag = 0, 4 do total = total + (GetContainerNumSlots(bag) or 0) end
    local n = math.floor(total / 4)
    if n < 1 then n = 1 end
    return n
end

local function PNNSIM_RunSellQueue(state)
    if not MerchantFrame:IsShown() then
        PNNSIM_AbortSell("merchant closed")
        return
    end
    if #state.queue == 0 then
        activeSellState = nil
        sellBusy = false
        if (state.soldCount > 0 or state.deletedCount > 0) and state.onComplete then
            state.onComplete(state)
        end
        return
    end

    local batch = PNNSIM_GetSellBatchSize()
    local processed = 0
    while #state.queue > 0 and processed < batch do
        local item = table.remove(state.queue, 1)
        local link = GetContainerItemLink(item.bag, item.slot)
        if link then
            local currentID = tonumber(string.match(link, "item:(%d+)"))
            if currentID == item.itemID then
                local stackSize = select(2, GetContainerItemInfo(item.bag, item.slot)) or 1
                if item.action == "sell" then
                    UseContainerItem(item.bag, item.slot)
                    state.soldCount = state.soldCount + stackSize
                    state.totalSoldValue = state.totalSoldValue + (item.price or 0) * stackSize
                elseif item.action == "delete" and not CursorHasItem() then
                    PickupContainerItem(item.bag, item.slot)
                    DeleteCursorItem()
                    state.deletedCount = state.deletedCount + stackSize
                    state.totalDeletedValue = state.totalDeletedValue + (item.price or 0) * stackSize
                end
            end
        end
        processed = processed + 1
    end

    C_Timer.After(0.1, function() PNNSIM_RunSellQueue(state) end)
end

function PNNSIM_TriggerSell()
    if sellBusy then return end
    local activeProfileName, activeProfile = PNNSIM_GetActiveProfile()
    if not activeProfileName then return end

    local queue = {}
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local itemID = tonumber(string.match(itemLink, "item:(%d+)"))
                if itemID then
                    local itemData = PNNSIM_BuildItemData(itemID, itemLink)
                    if itemData then
                        local isKeep, keepEntry = PNNSIM_IsItemInList(itemData, activeProfile.keep)
                        local shouldSell = false
                        if isKeep then
                            if keepEntry.fs and PNNSIM_IsExplicitlyInSellList(itemData, activeProfile.sell) then
                                shouldSell = true
                            end
                        else
                            local isSell, _ = PNNSIM_IsItemInList(itemData, activeProfile.sell)
                            if isSell then shouldSell = true end
                        end
                        if shouldSell then
                            if itemData.PRICE and itemData.PRICE > 0 then
                                table.insert(queue, { bag = bag, slot = slot, itemID = itemID, action = "sell", price = itemData.PRICE })
                            else
                                table.insert(queue, { bag = bag, slot = slot, itemID = itemID, action = "delete", price = 0 })
                            end
                        end
                    end
                end
            end
        end
    end

    if #queue == 0 then return end
    sellBusy = true
    activeSellState = {
        queue = queue,
        soldCount = 0, deletedCount = 0,
        totalSoldValue = 0, totalDeletedValue = 0,
        onComplete = function(s)
            if PNNSIM_UpdateTrackers then
                PNNSIM_UpdateTrackers(s.totalSoldValue, s.totalDeletedValue, s.soldCount, s.deletedCount)
            end
            local msg = "Profile ["..activeProfileName.."]: Sold " .. s.soldCount .. " item(s) for " .. GetCoinTextureString(s.totalSoldValue) .. " and deleted " .. s.deletedCount .. " item(s)."
            if GetConfValCore("console.verbose") == "1" then
                msg = msg .. " (Deleted value: " .. GetCoinTextureString(s.totalDeletedValue) .. ")"
            end
            if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
        end,
    }
    PNNSIM_RunSellQueue(activeSellState)
end

function PNNSIM_TriggerTempSell()
    if sellBusy then return end
    local activeProfileName, activeProfile = PNNSIM_GetActiveProfile()
    if not activeProfileName then
        local msg = "Temp Sell requires an active profile."
        if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
        return
    end

    local queue = {}
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local itemID = tonumber(string.match(itemLink, "item:(%d+)"))
                if itemID then
                    local itemData = PNNSIM_BuildItemData(itemID, itemLink)
                    if itemData then
                        local protected = false
                        if string.find(string.lower(itemData.NAME), "hearthstone", 1, true) then
                            protected = true
                        end
                        if not protected and activeProfile.keep then
                            for _, entry in ipairs(activeProfile.keep) do
                                if entry.pts and PNNSIM_IsItemInList(itemData, {entry}) then
                                    protected = true
                                    break
                                end
                            end
                        end
                        if not protected then
                            if itemData.PRICE and itemData.PRICE > 0 then
                                table.insert(queue, { bag = bag, slot = slot, itemID = itemID, action = "sell", price = itemData.PRICE })
                            else
                                table.insert(queue, { bag = bag, slot = slot, itemID = itemID, action = "delete", price = 0 })
                            end
                        end
                    end
                end
            end
        end
    end

    if #queue == 0 then return end
    sellBusy = true
    activeSellState = {
        queue = queue,
        soldCount = 0, deletedCount = 0,
        totalSoldValue = 0, totalDeletedValue = 0,
        onComplete = function(s)
            if PNNSIM_UpdateTrackers then
                PNNSIM_UpdateTrackers(s.totalSoldValue, 0, s.soldCount, s.deletedCount)
            end
            local msg = "Temp Sell: Sold " .. s.soldCount .. " item(s) for " .. GetCoinTextureString(s.totalSoldValue) .. " and deleted " .. s.deletedCount .. " item(s)."
            if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
        end,
    }
    PNNSIM_RunSellQueue(activeSellState)
end

function PNNSIM_SortBags()
    if UnitAffectingCombat("player") then
        local msg = "Cannot sort bags while in combat."
        if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
        return
    end
    if sortBusy then
        local msg = "Sort already in progress."
        if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
        return
    end

    ClearCursor()

    for bag = 1, 4 do
        sortBagsWasOpen[bag] = IsBagOpen(bag)
        if not sortBagsWasOpen[bag] then OpenBag(bag) end
    end

    sortBusy = true

    -- Defer snapshot one frame so newly-opened bags are fully registered
    C_Timer.After(0, function()
        if not sortBusy then return end

    -- Snapshot: flat array of all bag slots in physical order
    local slots = {}
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            local name = "\255"
            if link then
                -- Parse name from the link itself so uncached items still sort correctly.
                -- GetItemInfo returns nil when the item isn't in the client cache yet.
                local n = string.match(link, "%[(.-)%]") or GetItemInfo(link)
                if n then name = string.lower(n) end
            end
            table.insert(slots, { bag = bag, slot = slot, name = name })
        end
    end

    local N = #slots

    -- Sort: compute target order (copy references, then sort)
    local sorted = {}
    for i = 1, N do sorted[i] = slots[i] end
    table.sort(sorted, function(a, b) return a.name < b.name end)

    -- Plan: whereIs[i] = j  →  item belonging at position i is currently at position j
    --       occupiedBy[j] = i  →  position j holds the item meant for position i
    local currentIdx = {}
    for i = 1, N do currentIdx[slots[i]] = i end

    local whereIs = {}
    local occupiedBy = {}
    for i = 1, N do
        local j = currentIdx[sorted[i]]
        whereIs[i] = j
        occupiedBy[j] = i
    end

    local moves = 0
    local stuckTicks = 0

    local function step()
        if not sortBusy then return end
        -- Find first position that still needs its item
        for i = 1, N do
            if whereIs[i] ~= i then
                local j = whereIs[i]
                -- Same-name items are interchangeable for alpha sort: skip physical swap to
                -- avoid WoW merging same-item stacks and leaving slots locked server-side.
                if slots[j].name == slots[i].name then
                    local k = occupiedBy[i]
                    whereIs[k] = j
                    occupiedBy[j] = k
                    whereIs[i] = i
                    occupiedBy[i] = i
                    C_Timer.After(0, step)
                    return
                end
                local _, _, srcLocked = GetContainerItemInfo(slots[j].bag, slots[j].slot)
                local _, _, dstLocked = GetContainerItemInfo(slots[i].bag, slots[i].slot)

                if srcLocked or dstLocked then
                    stuckTicks = stuckTicks + 1
                    if stuckTicks >= 30 then
                        ClearCursor()
                        sortBusy = false
                        sortRestoreBags()
                        local msg = "Sort stalled: some slots remain locked."
                        if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
                        return
                    end
                else
                    stuckTicks = 0
                    -- 3-step swap: pick up j, drop at i (swap), drop displaced back at j
                    PickupContainerItem(slots[j].bag, slots[j].slot)
                    PickupContainerItem(slots[i].bag, slots[i].slot)
                    PickupContainerItem(slots[j].bag, slots[j].slot)
                    -- Keep snapshot names in sync with physical state so the same-name skip
                    -- above stays accurate on later iterations.
                    slots[i].name, slots[j].name = slots[j].name, slots[i].name
                    -- Update plan: i is settled; displaced item (was at i, target = k) is now at j
                    local k = occupiedBy[i]
                    whereIs[k] = j
                    occupiedBy[j] = k
                    whereIs[i] = i
                    occupiedBy[i] = i
                    moves = moves + 1
                end

                C_Timer.After(0, step)
                return
            end
        end

        -- All positions settled
        sortBusy = false
        sortRestoreBags()
        local msg = moves > 0 and ("Bags sorted: " .. moves .. " move(s).") or "Bags already sorted."
        if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
    end

    C_Timer.After(0, step)
    end) -- end deferred snapshot
end

function PNNSIM_SortGuildBankTab()
    local tab = GetCurrentGuildBankTab()

    if UnitAffectingCombat("player") then
        local msg = "Cannot sort bags while in combat."
        if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
        return
    end
    if sortBusy then
        local msg = "Sort already in progress."
        if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
        return
    end
    if CanWithdrawGuildBankItem and not CanWithdrawGuildBankItem(tab, 1) then
        local msg = "Cannot sort: no withdraw permission on this tab."
        if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
        return
    end

    ClearCursor()
    sortBusy = true

    local slots = {}
    for slot = 1, MAX_GUILDBANK_SLOTS_PER_TAB do
        local link = GetGuildBankItemLink(tab, slot)
        local name = "\255"
        if link then
            local n = string.match(link, "%[(.-)%]") or GetItemInfo(link)
            if n then name = string.lower(n) end
        end
        table.insert(slots, { slot = slot, name = name })
    end

    local N = #slots

    local sorted = {}
    for i = 1, N do sorted[i] = slots[i] end
    table.sort(sorted, function(a, b) return a.name < b.name end)

    local currentIdx = {}
    for i = 1, N do currentIdx[slots[i]] = i end

    local whereIs = {}
    local occupiedBy = {}
    for i = 1, N do
        local j = currentIdx[sorted[i]]
        whereIs[i] = j
        occupiedBy[j] = i
    end

    local moves = 0
    local stuckTicks = 0

    local function step()
        if not sortBusy then return end
        for i = 1, N do
            if whereIs[i] ~= i then
                local j = whereIs[i]
                if slots[j].name == slots[i].name then
                    local k = occupiedBy[i]
                    whereIs[k] = j
                    occupiedBy[j] = k
                    whereIs[i] = i
                    occupiedBy[i] = i
                    C_Timer.After(0, step)
                    return
                end
                local _, _, srcLocked = GetGuildBankItemInfo(tab, slots[j].slot)
                local _, _, dstLocked = GetGuildBankItemInfo(tab, slots[i].slot)
                if srcLocked or dstLocked then
                    stuckTicks = stuckTicks + 1
                    if stuckTicks >= 30 then
                        ClearCursor()
                        sortBusy = false
                        local msg = "Sort stalled: some slots remain locked."
                        if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
                        return
                    end
                else
                    stuckTicks = 0
                    PickupGuildBankItem(tab, slots[j].slot)
                    PickupGuildBankItem(tab, slots[i].slot)
                    PickupGuildBankItem(tab, slots[j].slot)
                    slots[i].name, slots[j].name = slots[j].name, slots[i].name
                    local k = occupiedBy[i]
                    whereIs[k] = j
                    occupiedBy[j] = k
                    whereIs[i] = i
                    occupiedBy[i] = i
                    moves = moves + 1
                end
                C_Timer.After(0, step)
                return
            end
        end
        sortBusy = false
        local msg = moves > 0 and ("Guild bank tab sorted: " .. moves .. " move(s).") or "Guild bank tab already sorted."
        if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
    end

    C_Timer.After(0, step)
end

function PNNSIM_DisableTempSell(reason)
    PNNSIM_TempSellActive = false
    if PNNSIM_ConsoleConfig then
        PNNSIM_ConsoleConfig[UnitName("player") .. ".console.tempsell"] = "0"
    end
    local msg = "Temp Sell mode auto-disabled: " .. (reason or "unknown") .. "."
    if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
end

local tempSellTicker = CreateFrame("Frame")
tempSellTicker:SetScript("OnUpdate", function(self, elapsed)
    self.timer = (self.timer or 0) + elapsed
    if self.timer < 0.5 then return end
    self.timer = 0
    if not PNNSIM_TempSellActive then return end

    if (PNNSIM_ProfilesEpoch or 0) ~= (PNNSIM_TempSellEpochSnapshot or 0) then
        PNNSIM_DisableTempSell("profile rules changed")
        return
    end

    if GetTime() - (PNNSIM_TempSellLastKillTime or GetTime()) > 300 then
        PNNSIM_DisableTempSell("5 minutes without a kill")
    end
end)

PNNSIM_Core:SetScript("OnEvent", function(self, event)
    if event == "MERCHANT_SHOW" then
        if PNNSIVM_SummoningLock then return end
        if PNNSIM_TempSellActive then
            PNNSIM_TriggerTempSell()
        elseif GetConfValCore("console.autosell") == "1" then
            local _, activeProfile = PNNSIM_GetActiveProfile()
            if activeProfile and activeProfile.autoSell ~= false then
                PNNSIM_TriggerSell()
            end
        end
    elseif event == "MERCHANT_CLOSED" then
        PNNSIM_AbortSell("merchant closed")
    elseif event == "BAG_UPDATE_DELAYED" then
        if PNNSIVM_SummoningLock then return end
        if sortBusy then return end
        if GetConfValCore("console.graydelete") == "1" then
            if grayDeleteBusy then return end
            grayDeleteBusy = true
            for bag = 0, 4 do
                for slot = 1, GetContainerNumSlots(bag) do
                    local itemLink = GetContainerItemLink(bag, slot)
                    if itemLink then
                        local _, _, quality, _, _, _, _, _, _, _, price = GetItemInfo(itemLink)
                        if quality == 0 and not CursorHasItem() then
                            local stackSize = select(2, GetContainerItemInfo(bag, slot)) or 1
                            local delValue = (price or 0) * stackSize

                            PickupContainerItem(bag, slot)
                            DeleteCursorItem()

                            if PNNSIM_UpdateTrackers then
                                PNNSIM_UpdateTrackers(0, delValue, 0, stackSize)
                            end

                            if GetConfValCore("console.verbose") == "1" then
                                local msg = "Auto-deleted gray item: " .. itemLink
                                if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
                            end
                        end
                    end
                end
            end
            grayDeleteBusy = false
        end
        local _, activeProfileForDel = PNNSIM_GetActiveProfile()
        if GetConfValCore("console.delnovalue") == "1" and activeProfileForDel then
            if not delNoValueBusy then
                delNoValueBusy = true
                for bag = 0, 4 do
                    for slot = 1, GetContainerNumSlots(bag) do
                        local itemLink = GetContainerItemLink(bag, slot)
                        if itemLink then
                            local itemID = tonumber(string.match(itemLink, "item:(%d+)"))
                            if itemID then
                                local itemData = PNNSIM_BuildItemData(itemID, itemLink)
                                if itemData and itemData.PRICE ~= nil and itemData.PRICE == 0 then
                                    local isKeep, keepEntry = PNNSIM_IsItemInList(itemData, activeProfileForDel.keep)
                                    local shouldDelete = false
                                    if isKeep then
                                        if keepEntry.fs and PNNSIM_IsExplicitlyInSellList(itemData, activeProfileForDel.sell) then
                                            shouldDelete = true
                                        end
                                    else
                                        local isSell, _ = PNNSIM_IsItemInList(itemData, activeProfileForDel.sell)
                                        if isSell then shouldDelete = true end
                                    end
                                    if shouldDelete and not CursorHasItem() then
                                        local stackSize = select(2, GetContainerItemInfo(bag, slot)) or 1
                                        PickupContainerItem(bag, slot)
                                        DeleteCursorItem()
                                        if PNNSIM_UpdateTrackers then
                                            PNNSIM_UpdateTrackers(0, 0, 0, stackSize)
                                        end
                                        if GetConfValCore("console.verbose") == "1" then
                                            local msg = "Auto-deleted no-value item: " .. itemLink
                                            if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                delNoValueBusy = false
            end
        end
    elseif event == "PLAYER_LOGIN" then
        PNNSIM_TempSellActive = false
        if PNNSIM_ConsoleConfig then
            PNNSIM_ConsoleConfig[UnitName("player") .. ".console.tempsell"] = "0"
        end

        -- One-time migration: console.defaultprofile -> console.activeprofile
        if PNNSIM_ConsoleConfig then
            local charName = UnitName("player")
            local activeKey = charName .. ".console.activeprofile"
            local defaultKey = charName .. ".console.defaultprofile"
            local activeVal = PNNSIM_ConsoleConfig[activeKey]
            local defaultVal = PNNSIM_ConsoleConfig[defaultKey]
            if (not activeVal or activeVal == "void" or activeVal == "") and defaultVal and defaultVal ~= "void" and defaultVal ~= "" then
                PNNSIM_ConsoleConfig[activeKey] = defaultVal
            end
            if defaultVal ~= nil then
                PNNSIM_ConsoleConfig[defaultKey] = nil
            end
        end

        local portraitButtons = {
            ContainerFrame1PortraitButton,
            ContainerFrame2PortraitButton,
            ContainerFrame3PortraitButton,
            ContainerFrame4PortraitButton,
            ContainerFrame5PortraitButton,
        }
        for _, btn in ipairs(portraitButtons) do
            local origClick = btn:GetScript("OnClick")
            btn:SetScript("OnClick", function(self, button)
                if IsAltKeyDown() then
                    PNNSIM_SortBags()
                else
                    if origClick then origClick(self, button) end
                end
            end)

            local origEnter = btn:GetScript("OnEnter")
            btn:SetScript("OnEnter", function(self)
                if origEnter then origEnter(self) end
                if GameTooltip:IsShown() then
                    GameTooltip:AddLine("Alt+Click to sort bags", 1, 1, 0)
                    GameTooltip:Show()
                end
            end)
        end

        -- Guild bank tab sort trigger.
        -- GUILDBANKBAGSLOTS_CHANGED fires on every tab click on this server,
        -- so we detect Alt+click by checking IsAltKeyDown() at event time.
        local gbSortFrame = CreateFrame("Frame")
        gbSortFrame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
        gbSortFrame:SetScript("OnEvent", function()
            if IsAltKeyDown() then
                PNNSIM_SortGuildBankTab()
            end
        end)

        local gbWaitFrame = CreateFrame("Frame")
        gbWaitFrame:RegisterEvent("GUILDBANKFRAME_OPENED")
        gbWaitFrame:SetScript("OnEvent", function(self)
            if GuildBankFrame then
                GuildBankFrame:HookScript("OnHide", function()
                    if sortBusy then
                        ClearCursor()
                        sortBusy = false
                        local msg = "Sort cancelled: guild bank closed."
                        if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
                    end
                end)
            end
            self:UnregisterAllEvents()
        end)
    elseif event == "PLAYER_REGEN_DISABLED" then
        if sortBusy then
            ClearCursor()
            sortBusy = false
            sortRestoreBags()
            local msg = "Sort cancelled: entered combat."
            if PNNSIM_Console_Print then PNNSIM_Console_Print(msg) else print("|cff00ff00[PNNSIM]|r " .. msg) end
        end
    elseif event == "PLAYER_LOGOUT" then
        if PNNSIM_TempSellActive then
            PNNSIM_TempSellActive = false
            if PNNSIM_ConsoleConfig then
                PNNSIM_ConsoleConfig[UnitName("player") .. ".console.tempsell"] = "0"
            end
        end
    end
end)