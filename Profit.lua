-- Profit.lua: what one craft costs and fetches.
--   made   = average yield (quantityMin..quantityMax) + Master Chef's extra item (+1 item with 10% chance per rank;
--            cooking only, if counted)
--   cost   = sum of reagents you do not mark as your own (Naowh's "owned" reagents are free),
--            each at the cheaper of merchant and auction price
--   sale   = auction: unit price * made * (1 - 5% AH cut);  vendor: sell price * made
--            disenchant: the materials' AH value after the cut (only gear this character's Enchanting can take)
--            saleChannel "best" takes the highest of them
--   profit = sale - cost (only when every price is known), ROI = profit / cost * 100
-- Naowh's list and Profitable filter count 1 item for learned recipes; this counts the real yield.
-- Intermediate reagents (a reagent one of your learned recipes of this profession makes, e.g. cured hide):
--   "off"   always bought
--   "cheap" crafted when its reagents cost less than buying it
--   "hour"  crafted only when that raises gold per hour: the money it saves per second of extra crafting
--           must beat what this recipe earns per second when everything is bought (v.rate). One level deep.
local _, NPP = ...
local L = NPP.L

local Profit = {}
NPP.Profit = Profit

local AH_CUT = 0.05
local EMPTY = {}

local cache, yields = {}, {}
local factor, chefRanks -- per cache generation

-- What a recipe makes and how many on average. Static, so kept until /reload.
local function Yield(recipeID)
    local y = yields[recipeID]
    if y then return y end
    local R = NPP.P.Recipes
    local okOut, output, made = pcall(R.OutputItem, recipeID)
    if not okOut then output, made = nil, nil end
    local minQ, maxQ = made or 1, nil
    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
    if ok and type(schematic) == "table" then
        -- quantityMin is used by Naowh; quantityMax may not exist on Forever, so it is checked.
        if type(schematic.quantityMin) == "number" and schematic.quantityMin > 0 then minQ = schematic.quantityMin end
        if type(schematic.quantityMax) == "number" and schematic.quantityMax >= minQ then maxQ = schematic.quantityMax end
    end
    y = { output = output, min = minQ, max = maxQ or minQ, made = (minQ + (maxQ or minQ)) / 2 }
    if output then yields[recipeID] = y end -- do not keep a miss: item data may not be loaded yet
    return y
end

-- Learned recipes of the open profession by the item they make (first found). Kept until the
-- profession's recipe list changes.
local makers
local function Makers()
    if makers then return makers end
    makers = {}
    local W = NPP.P.State
    if W.linked or not C_TradeSkillUI.GetAllRecipeIDs then return makers end
    for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or EMPTY) do
        local info = C_TradeSkillUI.GetRecipeInfo(id)
        if info and info.learned then
            local y = Yield(id)
            if y.output and not makers[y.output] then makers[y.output] = id end
        end
    end
    return makers
end

function Profit.Maker(itemID)
    return itemID and Makers()[itemID]
end

local makerEvents = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "NEW_RECIPE_LEARNED" }) do
    pcall(makerEvents.RegisterEvent, makerEvents, e)
end
makerEvents:SetScript("OnEvent", function() makers = nil end)

local function Factor()
    if not factor then
        local ok, f, ranks = pcall(NPP.Chef.Factor)
        if ok and type(f) == "number" then
            factor, chefRanks = f, ranks or 0
        else
            factor, chefRanks = 0, 0
        end
    end
    return factor, chefRanks
end

local function FactorFor(recipeID)
    local ok, f, ranks = pcall(NPP.Chef.FactorFor, recipeID)
    if ok and type(f) == "number" then return f, ranks or 0 end
    return Factor()
end

-- Channels: "ah" the auction house; "vendor" = sold at once: a merchant or disenchanting (whichever pays more,
-- disenchanting only if your Enchanting can take it; "de" is the same); "best" the most of them all.
local function PickChannel(v, ahSale, vendorSale, deSale, channel)
    channel = channel or NPP.Get("saleChannel")
    if channel == "ah" then return ahSale, "ah" end
    if channel == "vendor" or channel == "de" then
        if deSale and (not vendorSale or deSale > vendorSale) then return deSale, "de" end
        return vendorSale, "vendor"
    end
    local best, via
    -- ties go to the merchant: money at once, no waiting for a buyer
    for _, c in ipairs({ { vendorSale, "vendor" }, { deSale, "de" }, { ahSale, "ah" } }) do
        if c[1] and (not best or c[1] > best) then best, via = c[1], c[2] end
    end
    return best, via
end

-- Seconds one craft of a recipe takes (cast + the gap between repeated casts).
local function CraftSeconds(recipeID)
    local Plan = NPP.Plan
    if not Plan then return 3.3 end
    local cast = Plan.CastTime(recipeID)
    return cast + Plan.CAST_GAP
end
Profit.CraftSeconds = CraftSeconds

-- How an intermediate is made: { recipeID, parts = { {itemID, need, owned} }, made (whole units per craft),
-- seconds (per craft), cost (reagents per craft at buy prices; nil if one has no price) }.
local function MakerInfo(makerID, owned)
    local PS = NPP.PriceSource
    local okR, reagents = pcall(NPP.P.Recipes.Reagents, makerID)
    if not okR or type(reagents) ~= "table" or #reagents == 0 then return end
    local y = Yield(makerID)
    local f = FactorFor(makerID)
    local m = { recipeID = makerID, parts = {}, made = math.max(1, math.floor(y.made + f)), seconds = CraftSeconds(makerID), cost = 0 }
    for _, r in ipairs(reagents) do
        local part = { itemID = r.itemID, need = r.need or 1, owned = owned[r.itemID] == true }
        m.parts[#m.parts + 1] = part
        if not part.owned then
            local each = PS.Buy(r.itemID)
            if each and m.cost then m.cost = m.cost + each * part.need else m.cost = nil end
        end
    end
    return m
end

local function Compute(recipeID, outputOverride, channel)
    local P = NPP.P
    local PS = NPP.PriceSource
    local y = Yield(recipeID)
    local f, ranks = FactorFor(recipeID)
    local v = {
        recipeID = recipeID, output = outputOverride or y.output,
        baseMade = y.made, madeMin = y.min, madeMax = y.max, extra = f, chefRanks = ranks,
        made = y.made + f, cost = 0, missing = 0, owned = 0, parts = {},
    }
    local okR, reagents = pcall(P.Recipes.Reagents, recipeID)
    if not okR or type(reagents) ~= "table" then reagents = EMPTY end
    local okO, owned = pcall(P.Recipes.Owned)
    if not okO or type(owned) ~= "table" then owned = EMPTY end

    for _, r in ipairs(reagents) do
        local part = { itemID = r.itemID, need = r.need or 1 }
        v.parts[#v.parts + 1] = part
        if owned[r.itemID] == true then
            part.owned = true
            v.owned = v.owned + 1
        else
            part.each, part.from = PS.Buy(r.itemID)
            if part.each then
                v.cost = v.cost + part.each * part.need
            else
                v.missing = v.missing + 1
            end
        end
    end

    if #reagents == 0 then
        v.reason = "noreagents"
    elseif not v.output then
        v.reason = "nooutput"
    else
        v.each, v.src = PS.AH(v.output)
        v.vendorEach = PS.VendorSell(v.output)
        v.ahSale = v.each and math.floor(v.each * v.made * (1 - AH_CUT))
        v.vendorSale = v.vendorEach and math.floor(v.vendorEach * v.made)
        v.deEach = NPP.DE and NPP.DE.ValueFor(v.output) or nil
        v.deSale = v.deEach and math.floor(v.deEach * v.made)
        v.sale, v.channel = PickChannel(v, v.ahSale, v.vendorSale, v.deSale, channel)
        if v.sale and v.channel == "ah" then
            v.unitSale = v.each * (1 - AH_CUT)
        elseif v.sale and v.channel == "vendor" then
            v.unitSale = v.vendorEach
        elseif v.sale and v.channel == "de" then
            v.unitSale = v.deEach
        end
        local asked = channel or NPP.Get("saleChannel")
        if not v.sale then v.reason = (asked == "vendor" or asked == "de") and "novendor" or "nosaleprice" end
        if v.missing > 0 then v.reason = v.reason or "noreagentprice" end
    end

    v.seconds = CraftSeconds(recipeID)
    local mode = NPP.Get("intermediates")
    if mode ~= "off" and v.output and #reagents > 0 then
        -- what one second of crafting this recipe earns when everything is bought ("hour" mode only)
        local rate = 0
        if mode == "hour" and v.sale and v.missing == 0 and v.sale > v.cost then
            rate = (v.sale - v.cost) / v.seconds
        end
        v.rate = rate
        for _, part in ipairs(v.parts) do
            local makerID = not part.owned and Profit.Maker(part.itemID)
            if makerID and makerID ~= recipeID then
                local m = MakerInfo(makerID, owned)
                if m then
                    part.maker = m
                    if m.cost then
                        local each, secs = m.cost / m.made, m.seconds / m.made
                        if not part.each or each + secs * rate < part.each then
                            if part.each then v.cost = v.cost - part.each * part.need else v.missing = v.missing - 1 end
                            part.buyEach, part.each, part.from = part.each, each, "craft"
                            part.craft = true
                            v.cost = v.cost + each * part.need
                            v.seconds = v.seconds + secs * part.need
                        end
                    end
                end
            end
        end
        if v.missing == 0 and v.reason == "noreagentprice" then v.reason = nil end
    end

    if v.sale and v.missing == 0 and #reagents > 0 then
        v.profit = v.sale - v.cost
        if v.cost > 0 then
            v.roi = v.profit / v.cost * 100
        elseif v.profit > 0 then
            v.roiInf = true -- every reagent is your own: any sale is pure profit
        end
    end
    return v
end

-- Always returns a table; v.profit is nil when it cannot be computed (v.reason says why).
-- channel: count with this sale channel instead of the saleChannel setting (the profession overview has its own).
function Profit.Get(recipeID, outputOverride, fresh, channel)
    if not recipeID then return { reason = "norecipe", parts = EMPTY, cost = 0, missing = 0, owned = 0 } end
    local key = channel and (tostring(recipeID) .. ":" .. channel) or recipeID
    local v = not fresh and cache[key]
    if v then return v end
    v = Compute(recipeID, outputOverride, channel)
    cache[key] = v
    return v
end

-- For a list entry of Naowh's recipe list.
function Profit.ForEntry(e)
    if e.recipe then return Profit.Get(e.recipe.recipeID) end
    if e.unlearned then return Profit.Get(e.unlearned.spell, e.unlearned.item) end
end

local lastWipe, ownedSig = 0, nil
local REDRAW_TTL = 30 -- seconds: Naowh's redraws wipe our caches at most this often

function Profit.ClearCache()
    lastWipe = GetTime()
    wipe(cache)
    factor, chefRanks = nil, nil
    if NPP.PriceSource then NPP.PriceSource.ClearCache() end
    if NPP.Plan then NPP.Plan.ClearCache() end
end

local REASONS = {
    noreagents = "No reagent list for this recipe.",
    nooutput = "The recipe makes no item (enchant?): nothing to sell.",
    nosaleprice = "No price for the crafted item.",
    novendor = "Merchants do not buy the crafted item.",
    noreagentprice = "No price for %d reagent(s).",
    norecipe = "No recipe.",
}
function Profit.ReasonText(v)
    if not v.reason then return end
    return L(REASONS[v.reason] or v.reason):format(v.missing or 0)
end

function Profit.ItemName(itemID)
    local R = NPP.P and NPP.P.Recipes
    local name = R and R.ItemName and R.ItemName(itemID)
    return name or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)) or ("item:" .. tostring(itemID))
end

NPP.Module("profit", { "core" }, function()
    -- Naowh clears its price cache on every window redraw and when a reagent is marked as owned.
    -- Naowh clears its price cache on every redraw (on every craft, as the bags change). Prices do not change
    -- with that: ours are wiped only when your own-reagent marks change, or every REDRAW_TTL seconds, and never
    -- while crafting. New lots, scans and settings still wipe them at once (they call Profit.ClearCache).
    local function OwnedSignature()
        local ok, owned = pcall(NPP.P.Recipes.Owned)
        if not ok or type(owned) ~= "table" then return "" end
        local keys = {}
        for k, v in pairs(owned) do
            if v then keys[#keys + 1] = tostring(k) end
        end
        table.sort(keys)
        return table.concat(keys, ",")
    end
    hooksecurefunc(NPP.P.Prices, "ClearCache", function()
        local sig = OwnedSignature()
        if sig ~= ownedSig then
            ownedSig = sig
            return Profit.ClearCache()
        end
        if NPP.Crafting() or GetTime() - lastWipe < REDRAW_TTL then return end
        Profit.ClearCache()
    end)
end)
