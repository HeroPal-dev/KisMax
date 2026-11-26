-- PriceFloor.lua: "do not sell below" on the tooltip of an item your recipes make. Posting crafted items (Naowh's
-- The Market undercuts for you) can go under what they cost; this line shows the lowest auction price that still
-- pays: the larger of
--   cost per item / 0.95       the reagents of one craft at today's prices (Profit), per item made, before the cut
--   merchant price / 0.95      below that a merchant (or disenchanting) pays more, at once
-- The item's recipe: Naowh's memory of this character's learned recipes (result -> recipe), or one the ledger saw.
local _, NPP = ...
local L = NPP.L

local Floor = {}
NPP.PriceFloor = Floor

local AH_KEEP = 0.95
local byOutput, builtAt = nil, 0

local function Recipes()
    if byOutput and GetTime() - builtAt < 60 then return byOutput end
    byOutput, builtAt = {}, GetTime()
    local S = NPP.P and NPP.P.Shopping
    if S and type(S.Makes) == "function" then
        local ok, makes = pcall(S.Makes)
        if ok and type(makes) == "table" then
            for output, m in pairs(makes) do
                if type(m) == "table" and m.recipe then byOutput[output] = m.recipe end
            end
        end
    end
    local d = NPP.db and NPP.db.ledger
    for recipeID, r in pairs(d and d.recipes or {}) do
        if r.output and not byOutput[r.output] then byOutput[r.output] = recipeID end
    end
    return byOutput
end

-- { cost = per item, floor = lowest AH price that pays, why = "cost" | "merchant", recipe } or nil
function Floor.For(itemID)
    local recipeID = itemID and Recipes()[itemID]
    if not recipeID then return end
    local ok, v = pcall(NPP.Profit.Get, recipeID, itemID)
    if not ok or not v or v.missing > 0 or not v.made or v.made <= 0 then return end
    local cost = v.cost / v.made
    local quick = math.max(v.vendorEach or 0, v.deEach or 0)
    local floor, why = cost / AH_KEEP, "cost"
    if quick / AH_KEEP > floor then floor, why = quick / AH_KEEP, "merchant" end
    return { cost = cost, floor = math.ceil(floor), why = why, recipe = recipeID, quick = quick }
end

local function OnTooltip(tooltip, data)
    if not NPP.Get("tooltipFloor") or tooltip ~= GameTooltip then return end
    local id = data and data.id
    if not id and tooltip.GetItem then
        local _, link = tooltip:GetItem()
        id = link and tonumber(link:match("item:(%d+)"))
    end
    local f = id and Floor.For(id)
    if not f then return end
    tooltip:AddDoubleLine("|cff33ccffKM|r " .. L("cost per item"), NPP.Coins(math.floor(f.cost + 0.5)), 0.8, 0.8, 0.8, 1, 1, 1)
    local why = f.why == "merchant" and L("(a merchant / disenchanting pays more below it)") or L("(after the 5% cut)")
    tooltip:AddDoubleLine("|cff33ccffKM|r " .. L("on the AH not below"), NPP.Coins(f.floor), 1, 0.82, 0, 1, 0.82, 0)
    tooltip:AddLine("    " .. why, 0.6, 0.6, 0.6)
end

NPP.Module("pricefloor", { "core" }, function()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            NPP.Safe("price floor tooltip", OnTooltip, tooltip, data)
        end)
    end
end)
