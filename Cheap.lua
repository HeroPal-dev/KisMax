-- Cheap.lua: "cheap now" - a reagent of your recipes whose cheapest lot right now (our live lots or full scan) is
-- well under its usual price (TSM DBMarket, else DBHistorical): a green line on its tooltip, so you can buy ahead.
-- The shopping list's own check at the auction house is in Shop.lua (autoShopCheck).
local _, NPP = ...
local L = NPP.L

local Cheap = {}
NPP.Cheap = Cheap

-- cheapest listed now, usual price, how much under it (0.3 = 30%); nil when not cheap or not known
function Cheap.Now(itemID)
    local pct = tonumber(NPP.Get("cheapPct")) or 30
    local ladder = NPP.Scan and NPP.Scan.Ladder(itemID)
    if not (ladder and ladder.levels and ladder.levels[1]) then return end
    local now = ladder.levels[1]
    for i = 1, #ladder.levels, 2 do now = math.min(now, ladder.levels[i]) end
    local PS = NPP.PriceSource
    local usual = PS.TSMValue and (PS.TSMValue("DBMarket", itemID) or PS.TSMValue("DBHistorical", itemID))
    if not usual or usual <= 0 then return end
    local drop = 1 - now / usual
    if drop * 100 < pct then return end
    return now, usual, drop, ladder
end

local function OnTooltip(tooltip, data)
    if not NPP.Get("tooltipCheap") or tooltip ~= GameTooltip then return end
    local id = data and data.id
    if not id and tooltip.GetItem then
        local _, link = tooltip:GetItem()
        id = link and tonumber(link:match("item:(%d+)"))
    end
    if not (id and NPP.Ledger and NPP.Ledger.IsReagent and NPP.Ledger.IsReagent(id)) then return end
    local now, usual, drop, ladder = Cheap.Now(id)
    if not now then return end
    local age = ladder.time and NPP.PriceSource.Age(ladder.time)
    tooltip:AddDoubleLine("|cff33ccffKM|r " .. L("cheap now"), NPP.Coins(now), 0.3, 0.82, 0.48, 0.3, 0.82, 0.48)
    tooltip:AddLine("    " .. L("usually %s, %d%% less"):format(NPP.Coins(usual), math.floor(drop * 100 + 0.5))
        .. (age and (", " .. L("lots %s ago"):format(age)) or ""), 0.6, 0.6, 0.6)
end

NPP.Module("cheap", { "core" }, function()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            NPP.Safe("cheap tooltip", OnTooltip, tooltip, data)
        end)
    end
end)
