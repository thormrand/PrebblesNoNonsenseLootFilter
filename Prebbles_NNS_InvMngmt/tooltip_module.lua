-- tooltip_module.lua

local function GetAllMatches(itemData, list)
    local matches = {}
    if not list or not itemData then return matches end
    for _, entry in ipairs(list) do
        if PNNSIM_IsItemInList(itemData, {entry}) then
            matches[#matches + 1] = entry
        end
    end
    return matches
end

local function UpdateTooltipWithRules(tooltip)
    if not PNNSIM_BuildItemData or not PNNSIM_IsItemInList or not PNNSIM_GetActiveProfile then return end

    local _, activeProfile = PNNSIM_GetActiveProfile()
    if not activeProfile then return end

    local _, itemLink = tooltip:GetItem()
    if not itemLink then return end

    local itemID = tonumber(string.match(itemLink, "item:(%d+)"))
    if not itemID then return end

    local itemData = PNNSIM_BuildItemData(itemID, itemLink)
    if not itemData then return end

    local keepMatches = GetAllMatches(itemData, activeProfile.keep)
    local sellMatches = GetAllMatches(itemData, activeProfile.sell)

    if PNNSIM_TempSellActive then
        local protected = false
        local protectReason = ""

        if string.find(string.lower(itemData.NAME), "hearthstone", 1, true) then
            protected = true
            protectReason = " [hearthstone]"
        else
            for _, entry in ipairs(keepMatches) do
                if entry.pts then
                    protected = true
                    protectReason = " [--pts]"
                    break
                end
            end
        end

        tooltip:AddLine(" ")
        if protected then
            tooltip:AddLine("|cff00ff00[PNNSIM] TEMPSELL: SAVED|r" .. protectReason)
        elseif itemData.PRICE and itemData.PRICE > 0 then
            tooltip:AddLine("|cffff0000[PNNSIM] TEMPSELL: SELL|r")
        else
            tooltip:AddLine("|cffff0000[PNNSIM] TEMPSELL: DELETE|r")
        end
    end

    if #keepMatches > 0 or #sellMatches > 0 then
        if not PNNSIM_TempSellActive then
            tooltip:AddLine(" ")
        end
        for _, entry in ipairs(keepMatches) do
            local fsText = entry.fs and " [--fs]" or ""
            tooltip:AddLine("|cff00ff00[PNNSIM] KEEP:|r Matched Rule ID " .. entry.listid .. fsText)
        end
        for _, entry in ipairs(sellMatches) do
            tooltip:AddLine("|cffff0000[PNNSIM] SELL:|r Matched Rule ID " .. entry.listid)
        end
    end

    if PNNSIM_TempSellActive or #keepMatches > 0 or #sellMatches > 0 then
        tooltip:Show()
    end
end

GameTooltip:HookScript("OnTooltipSetItem", UpdateTooltipWithRules)
ItemRefTooltip:HookScript("OnTooltipSetItem", UpdateTooltipWithRules)

-- WotLK bug: WatchFrameItem_UpdateCooldown calls GetContainerItemCooldown
-- without nil-checking self.bag/self.slot, crashing CooldownFrame_SetTimer
-- when BAG_UPDATE_COOLDOWN fires for WatchFrame quest objectives with no bag slot.
if WatchFrameItem_UpdateCooldown then
    local _orig_WatchFrameItem_UpdateCooldown = WatchFrameItem_UpdateCooldown
    WatchFrameItem_UpdateCooldown = function(self)
        if not self or not self.bag or not self.slot then return end
        _orig_WatchFrameItem_UpdateCooldown(self)
    end
end
