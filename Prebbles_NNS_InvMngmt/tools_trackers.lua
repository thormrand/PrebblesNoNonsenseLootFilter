-- tools_trackers.lua

local PNNSIM_Trackers = CreateFrame("Frame")
PNNSIM_Trackers:RegisterEvent("PLAYER_LOGIN")
PNNSIM_Trackers:RegisterEvent("PLAYER_LOGOUT")

PNNSIM_SessionTracker = { sold = 0, deleted = 0, soldItems = 0, deletedItems = 0, startTime = GetTime(), looted = 0, kills = 0, ashes = 0 }

function PNNSIM_UpdateTrackers(soldValue, deletedValue, soldItemsCount, deletedItemsCount)
    PNNSIM_SessionTracker.sold = PNNSIM_SessionTracker.sold + soldValue
    PNNSIM_SessionTracker.deleted = PNNSIM_SessionTracker.deleted + deletedValue
    PNNSIM_SessionTracker.soldItems = PNNSIM_SessionTracker.soldItems + soldItemsCount
    PNNSIM_SessionTracker.deletedItems = PNNSIM_SessionTracker.deletedItems + deletedItemsCount

    if PNNSIM_CharData then
        PNNSIM_CharData["tracker.genesis.sold"] = (PNNSIM_CharData["tracker.genesis.sold"] or 0) + soldValue
        PNNSIM_CharData["tracker.genesis.deleted"] = (PNNSIM_CharData["tracker.genesis.deleted"] or 0) + deletedValue
        PNNSIM_CharData["tracker.genesis.item.sold"] = (PNNSIM_CharData["tracker.genesis.item.sold"] or 0) + soldItemsCount
        PNNSIM_CharData["tracker.genesis.item.deleted"] = (PNNSIM_CharData["tracker.genesis.item.deleted"] or 0) + deletedItemsCount
    end

    if PNNSIM_UpdateTrackerUI then PNNSIM_UpdateTrackerUI() end
end

PNNSIM_Trackers:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        if PNNSIM_CharData then
            PNNSIM_CharData["tracker.genesis.sold"] = PNNSIM_CharData["tracker.genesis.sold"] or 0
            PNNSIM_CharData["tracker.genesis.deleted"] = PNNSIM_CharData["tracker.genesis.deleted"] or 0
            PNNSIM_CharData["tracker.genesis.item.sold"] = PNNSIM_CharData["tracker.genesis.item.sold"] or 0
            PNNSIM_CharData["tracker.genesis.item.deleted"] = PNNSIM_CharData["tracker.genesis.item.deleted"] or 0
            PNNSIM_CharData["tracker.genesis.ashes"]      = PNNSIM_CharData["tracker.genesis.ashes"]      or 0

            -- Restore session across reloads; elapsed key present means a saved session exists
            if PNNSIM_CharData["tracker.session.elapsed"] ~= nil then
                PNNSIM_SessionTracker.sold         = PNNSIM_CharData["tracker.session.sold"]         or 0
                PNNSIM_SessionTracker.deleted      = PNNSIM_CharData["tracker.session.deleted"]      or 0
                PNNSIM_SessionTracker.soldItems    = PNNSIM_CharData["tracker.session.soldItems"]    or 0
                PNNSIM_SessionTracker.deletedItems = PNNSIM_CharData["tracker.session.deletedItems"] or 0
                PNNSIM_SessionTracker.looted       = PNNSIM_CharData["tracker.session.looted"]       or 0
                PNNSIM_SessionTracker.kills        = PNNSIM_CharData["tracker.session.kills"]        or 0
                PNNSIM_SessionTracker.ashes        = PNNSIM_CharData["tracker.session.ashes"]        or 0
                PNNSIM_SessionTracker.startTime    = GetTime() - (PNNSIM_CharData["tracker.session.elapsed"] or 0)
            end
            PNNSIM_AshTrackerLastSP = nil
        end
        if PNNSIM_UpdateTrackerUI then PNNSIM_UpdateTrackerUI() end

    elseif event == "PLAYER_LOGOUT" then
        if PNNSIM_CharData then
            local elapsed = math.max(0, GetTime() - (PNNSIM_SessionTracker.startTime or GetTime()))
            PNNSIM_CharData["tracker.session.sold"]         = PNNSIM_SessionTracker.sold
            PNNSIM_CharData["tracker.session.deleted"]      = PNNSIM_SessionTracker.deleted
            PNNSIM_CharData["tracker.session.soldItems"]    = PNNSIM_SessionTracker.soldItems
            PNNSIM_CharData["tracker.session.deletedItems"] = PNNSIM_SessionTracker.deletedItems
            PNNSIM_CharData["tracker.session.looted"]       = PNNSIM_SessionTracker.looted
            PNNSIM_CharData["tracker.session.kills"]        = PNNSIM_SessionTracker.kills
            PNNSIM_CharData["tracker.session.ashes"]        = PNNSIM_SessionTracker.ashes
            PNNSIM_CharData["tracker.session.elapsed"]      = elapsed
        end
    end
end)