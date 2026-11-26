-- Plan.lua: how many crafts stay profitable, and what to buy for them.
-- Each reagent's supply, in the order it is used:
--   your own reagents (Naowh "owned")  free and unlimited, never bought
--   your bags                          valued at today's buy price (you could sell them instead)
--   auction levels from our scan       cheapest first, with their quantities
--   merchant                           unlimited at the merchant price
-- (No quantities for an item -> its AH price counts as unlimited and the plan says so.)
-- Crafts are added one at a time while that craft's own profit (sale value of one craft minus the
-- price of the units it takes from the supply) stays above zero and above Min profit, if one is set.
-- Limits: planMax crafts; for auction sales with limitByDemand, TSM's region sold-per-day * demandDays
-- (region-wide, so for one realm it is generous); the money to pay for the AH and merchant purchases
-- (budget: "auto" = gold on this character, a number = copper, false = no limit). Bags cost no money.
-- When money is the limit the plan also remembers how far it would go without it (p.free*).
-- Bag space (limitByBags): the new stacks the purchases need, and the stacks of the crafted results, must each fit
-- in your free slots of ordinary bags (profession and reagent bags are not counted). While you craft, the reagents'
-- stacks shrink as the results' grow, so the larger of the two is the most you hold at once.
-- Intermediates (see Profit.lua): each unit comes from spare crafted units, its next unit for sale or one
-- more craft of it, whichever is cheaper after valuing the craft's time at the recipe's rate (mode "hour").
-- So cheap lots of the intermediate are bought first and it is crafted once the lots get dearer.
local _, NPP = ...
local L = NPP.L

local Plan = {}
NPP.Plan = Plan

local INF = math.huge
local cache = {}

-- Craft time, as Naowh's Total Craft Timer counts it: the recipe spell's cast time, plus a short gap
-- between repeated casts; 3 s when the spell gives no cast time (then marked as a guess).
local CAST_GAP, GUESS_CAST, MS = 0.3, 3, 1000
Plan.CAST_GAP = CAST_GAP

function Plan.CastTime(recipeID)
    if not (recipeID and C_Spell and C_Spell.GetSpellInfo) then return GUESS_CAST, true end
    local ok, spell = pcall(C_Spell.GetSpellInfo, recipeID)
    local cast = ok and type(spell) == "table" and tonumber(spell.castTime) or 0
    if cast > 0 then return cast / MS, false end
    return GUESS_CAST, true
end

-- Seconds for n crafts in a row.
function Plan.Seconds(recipeID, n)
    local cast, guess = Plan.CastTime(recipeID)
    if not n or n <= 0 then return 0, cast, guess end
    return n * cast + (n - 1) * CAST_GAP, cast, guess
end

function Plan.TimeText(seconds)
    seconds = math.floor((seconds or 0) + 0.5)
    if seconds < 60 then return L("%d s"):format(seconds) end
    local minutes = math.floor(seconds / 60 + 0.5)
    if minutes < 60 then return L("%d min"):format(minutes) end
    if minutes >= 24 * 60 then return L("%s d"):format(("%.1f"):format(seconds / 86400)) end
    return L("%d h %d min"):format(math.floor(minutes / 60), minutes % 60)
end

local function SortLevels(a, b) return a[1] < b[1] end

local function Supply(itemID)
    local PS = NPP.PriceSource
    local R = NPP.P.Recipes
    local levels, noDepth = {}, false
    local okB, bag = pcall(R.ItemCount, itemID)
    bag = okB and tonumber(bag) or 0
    local market = PS.Buy(itemID)
    local vendor = PS.Vendor(itemID)
    local ladder = NPP.Scan and NPP.Scan.Ladder(itemID)
    local rest = {}
    if ladder then
        for i = 1, #ladder.levels, 2 do rest[#rest + 1] = { ladder.levels[i], ladder.levels[i + 1], "ah" } end
    elseif not vendor then
        local price = PS.AH(itemID)
        if price then
            rest[#rest + 1] = { price, INF, "ah" }
            noDepth = true
        end
    end
    if vendor then rest[#rest + 1] = { vendor, INF, "vendor" } end
    table.sort(rest, SortLevels)
    if bag > 0 then levels[1] = { market or 0, bag, "bags" } end
    for _, lv in ipairs(rest) do levels[#levels + 1] = lv end
    return levels, noDepth, ladder, vendor
end

-- Takes n units from a supply starting at level i with used units of it taken already.
-- Returns cost, new i, new used, cash (the part paid with money: not from bags); or nil when the supply runs out.
local function Take(levels, i, used, n)
    local cost, cash = 0, 0
    while n > 0 do
        local lv = levels[i]
        if not lv then return nil end
        local left = lv[2] - used
        if left <= 0 then
            i, used = i + 1, 0
        else
            local take = math.min(left, n)
            cost = cost + take * lv[1]
            if lv[3] ~= "bags" then cash = cash + take * lv[1] end
            n, used = n - take, used + take
        end
    end
    return cost, i, used, cash
end

-- Money the plan may spend, in copper; nil = no limit.
function Plan.Budget()
    local b = NPP.Get("budget")
    if b == "auto" then return GetMoney and GetMoney() or nil end
    if type(b) == "number" and b >= 0 then return b end
end

-- What n units taken from the start of a supply come from.
local function Breakdown(levels, n)
    local out = { bags = 0, ah = 0, ahCost = 0, ahMax = nil, vendor = 0, vendorCost = 0 }
    for _, lv in ipairs(levels) do
        if n <= 0 then break end
        local take = math.min(lv[2], n)
        n = n - take
        if lv[3] == "bags" then
            out.bags = out.bags + take
        elseif lv[3] == "ah" then
            out.ah, out.ahCost, out.ahMax = out.ah + take, out.ahCost + take * lv[1], lv[1]
        else
            out.vendor, out.vendorCost = out.vendor + take, out.vendorCost + take * lv[1]
        end
    end
    return out
end

-- Supply state of every item a plan takes from: main reagents and the reagents of crafted intermediates.
local function NewState(p)
    local state = {}
    local function Get(itemID)
        local s = state[itemID]
        if s then return s end
        local levels, noDepth, ladder, vendor = Supply(itemID)
        local first = levels[1]
        s = { itemID = itemID, levels = levels, at = 1, used = 0, taken = 0, ladder = ladder or false,
            have = first and first[3] == "bags" and first[2] or 0,
            partial = ladder and ladder.full == false and not vendor, spare = 0, subCrafts = 0 }
        if noDepth then p.noDepth = true end
        state[itemID] = s
        return s
    end
    return state, Get
end

local function Snapshot(state)
    local snap = {}
    for id, s in pairs(state) do snap[id] = { s.at, s.used, s.taken, s.spare, s.subCrafts } end
    return snap
end

local function Restore(state, snap)
    for id, s in pairs(state) do
        local t = snap[id]
        if t then
            s.at, s.used, s.taken, s.spare, s.subCrafts = t[1], t[2], t[3], t[4], t[5]
        else
            s.at, s.used, s.taken, s.spare, s.subCrafts = 1, 0, 0, 0, 0
        end
    end
end

-- Takes n units of an item from its supply; returns cost, cash or nil, why ("partial" | true).
local function TakeFrom(s, n)
    local c, i, u, m = Take(s.levels, s.at, s.used, n)
    if not c then return nil, s.partial and "partial" or true end
    s.at, s.used, s.taken = i, u, s.taken + n
    return c, m
end

-- One craft of an intermediate's maker: cost, cash or nil, why. Takes nothing.
local function PeekMaker(m, Get)
    local cost, cash = 0, 0
    for _, part in ipairs(m.parts) do
        if not part.owned then
            local s = Get(part.itemID)
            local c, _, _, cm = Take(s.levels, s.at, s.used, part.need)
            if not c then return nil, s.partial and "partial" or true end
            cost, cash = cost + c, cash + cm
        end
    end
    return cost, cash
end

local function CraftMaker(m, Get)
    for _, part in ipairs(m.parts) do
        if not part.owned then TakeFrom(Get(part.itemID), part.need) end
    end
end

-- n units of an intermediate, one at a time: a spare crafted unit, else the cheaper of its next unit for sale
-- and one more craft of it (that craft's reagents + its time valued at rate per second).
-- Returns cost, cash, seconds or nil, why.
local function TakeIntermediate(part, n, rate, Get)
    local s, m = Get(part.itemID), part.maker
    local cost, cash, secs = 0, 0, 0
    for _ = 1, n do
        local lv = s.levels[s.at]
        if s.spare > 0 then
            s.spare = s.spare - 1
        elseif lv and lv[3] == "bags" and lv[2] - s.used > 0 then
            -- intermediates already in your bags go first
            local c, m = TakeFrom(s, 1)
            cost, cash = cost + c, cash + m
        else
            local buy, _, _, buyCash = Take(s.levels, s.at, s.used, 1)
            local craft, craftCash = PeekMaker(m, Get)
            local useCraft = craft and (not buy or craft / m.made + m.seconds / m.made * rate < buy)
            if useCraft then
                CraftMaker(m, Get)
                s.subCrafts = s.subCrafts + 1
                s.spare = s.spare + m.made - 1
                cost, cash, secs = cost + craft, cash + craftCash, secs + m.seconds
            elseif buy then
                TakeFrom(s, 1)
                cost, cash = cost + buy, cash + buyCash
            else
                return nil, (s.partial or craftCash == "partial") and "partial" or true
            end
        end
    end
    return cost, cash, secs
end

-- Free slots in ordinary bags (bag family 0); nil when the API is missing.
function Plan.FreeSlots()
    if not (C_Container and C_Container.GetContainerNumFreeSlots) then return end
    local free = 0
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local n, family = C_Container.GetContainerNumFreeSlots(bag)
        if n and (family == nil or family == 0) then free = free + n end
    end
    return free
end

-- Stack size of an item; 20 (a guess) while its data is not loaded.
local function StackSize(itemID)
    local stack = C_Item and C_Item.GetItemInfo and select(8, C_Item.GetItemInfo(itemID))
    if type(stack) == "number" and stack > 0 then return stack end
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    return 20
end

local function NewStacks(have, add, stack)
    if add <= 0 then return 0 end
    return math.ceil((have + add) / stack) - math.ceil(have / stack)
end

-- Slots the plan needs at its fullest: the new stacks of everything bought, or of the results crafted.
local function SlotsNeeded(state, output, outHave, outUnits)
    local buy = 0
    for id, s in pairs(state) do
        buy = buy + NewStacks(s.have, math.max(0, s.taken - s.have), StackSize(id))
    end
    local made = output and NewStacks(outHave, math.ceil(outUnits), StackSize(output)) or 0
    return math.max(buy, made), buy, made
end

-- For the session plan (Session.lua): the same supplies and takes, shared by several recipes.
Plan.internal = {
    NewState = NewState, Snapshot = Snapshot, Restore = Restore, Breakdown = Breakdown,
    TakeFrom = TakeFrom, TakeIntermediate = TakeIntermediate, StackSize = StackSize, NewStacks = NewStacks,
}

local function Compute(recipeID, outputOverride)
    local v = NPP.Profit.Get(recipeID, outputOverride)
    local p = { v = v, crafts = 0, cost = 0, sale = 0, profit = 0, cash = 0, subSeconds = 0, parts = {} }
    if not v.unitSale or v.missing > 0 or #v.parts == 0 then
        p.limit = "noprice"
        return p
    end
    local perCraft = v.unitSale * v.made
    local minProfit = NPP.Get("minProfit")
    local cap = math.max(1, tonumber(NPP.Get("planMax")) or 200)
    local rate = v.rate or 0
    p.limit = "cap"
    if v.channel == "ah" and NPP.Get("limitByDemand") then
        local sold = NPP.PriceSource.SoldPerDay(v.output)
        p.soldPerDay = sold
        if sold then
            local byDemand = math.floor(sold * (tonumber(NPP.Get("demandDays")) or 1) / math.max(v.made, 1))
            if byDemand < cap then
                cap = byDemand
                p.limit = "demand"
            end
        end
    end

    local state, Get = NewState(p)
    for _, part in ipairs(v.parts) do
        if not part.owned then
            local s = Get(part.itemID)
            if part.maker then
                s.made = part.maker.made
                for _, sub in ipairs(part.maker.parts) do
                    if not sub.owned then Get(sub.itemID) end
                end
            end
        end
    end

    local budget = Plan.Budget()
    p.budget = budget
    local free = NPP.Get("limitByBags") and Plan.FreeSlots() or nil
    p.freeSlots = free
    local outHave = 0
    if free and v.output then
        local ok, n = pcall(NPP.P.Recipes.ItemCount, v.output)
        outHave = ok and tonumber(n) or 0
    end
    local cut -- the plan at the moment money or bag space ran out
    local slots, slotsBuy, slotsMade = 0, 0, 0
    for k = 1, cap do
        local snap = Snapshot(state)
        local cost, cash, secs, short = 0, 0, 0, false
        for _, part in ipairs(v.parts) do
            if not part.owned then
                local c, m, t
                if part.maker then
                    c, m, t = TakeIntermediate(part, part.need, rate, Get)
                else
                    c, m = TakeFrom(Get(part.itemID), part.need)
                end
                if not c then
                    short = m
                    break
                end
                cost, cash, secs = cost + c, cash + m, secs + (t or 0)
            end
        end
        if short then
            Restore(state, snap)
            p.limit = short == "partial" and "partial" or "supply"
            break
        end
        local margin = perCraft - cost
        if margin <= 0 or (minProfit ~= false and margin < minProfit) then
            Restore(state, snap)
            p.limit = "profit"
            p.nextMargin = margin
            break
        end
        local why
        if budget and p.cash + cash > budget then why = "money" end
        local need, needBuy, needMade = 0, 0, 0
        if free then
            need, needBuy, needMade = SlotsNeeded(state, v.output, outHave, k * v.made)
            if not why and need > free then why = "bags" end
        end
        if why and not cut then
            cut = { crafts = p.crafts, cost = p.cost, sale = p.sale, cash = p.cash, lastMargin = p.lastMargin,
                subSeconds = p.subSeconds, snap = snap, why = why, slots = slots, slotsBuy = slotsBuy, slotsMade = slotsMade }
        end
        slots, slotsBuy, slotsMade = need, needBuy, needMade
        p.crafts, p.cost, p.sale, p.cash, p.lastMargin = k, p.cost + cost, p.sale + perCraft, p.cash + cash, margin
        p.subSeconds = p.subSeconds + secs
    end
    p.slots, p.slotsBuy, p.slotsMade = slots, slotsBuy, slotsMade
    if cut then
        -- keep what would pay without the money / bag limit, then cut the plan to what fits
        p.freeCrafts, p.freeProfit, p.freeCash, p.freeLimit = p.crafts, math.floor(p.sale - p.cost), p.cash, p.limit
        p.freeSlotsNeeded = slots
        p.crafts, p.cost, p.sale, p.cash, p.lastMargin = cut.crafts, cut.cost, cut.sale, cut.cash, cut.lastMargin
        p.subSeconds = cut.subSeconds
        p.slots, p.slotsBuy, p.slotsMade = cut.slots, cut.slotsBuy, cut.slotsMade
        Restore(state, cut.snap)
        p.limit, p.nextMargin = cut.why, nil
    end
    p.profit = math.floor(p.sale - p.cost)
    p.sale = math.floor(p.sale)
    p.cash = math.floor(p.cash)
    p.units = p.crafts * v.made
    p.seconds, p.castTime, p.castGuess = Plan.Seconds(recipeID, p.crafts)
    p.seconds = p.seconds + p.subSeconds
    if p.seconds > 0 then p.perHour = math.floor(p.profit * 3600 / p.seconds) end
    -- sort key "profit per hour": the plan's average; with no profitable craft, one craft's (negative) rate
    if p.perHour then
        p.hourly = p.perHour
    elseif v.profit then
        p.hourly = math.floor(v.profit * 3600 / (v.seconds or (p.castTime + CAST_GAP)))
    end

    -- lines: the recipe's reagents, then the reagents of the intermediates crafted for it (b.sub)
    local mainNeed, shown = {}, {}
    for _, part in ipairs(v.parts) do mainNeed[part.itemID] = (mainNeed[part.itemID] or 0) + p.crafts * part.need end
    local function Line(itemID, sub, ownUnits)
        if shown[itemID] then return end
        shown[itemID] = true
        local s = state[itemID]
        local b
        if s then
            b = Breakdown(s.levels, s.taken)
        else
            b = { own = ownUnits or mainNeed[itemID] or 0 }
        end
        b.itemID, b.sub = itemID, sub
        b.need = mainNeed[itemID] or ownUnits or (s and s.taken) or 0
        if s then
            if s.subCrafts > 0 then
                b.crafts = s.subCrafts
                b.crafted = math.min(b.need, s.subCrafts * (s.made or 1))
            end
            if s.ladder then b.lotsFrom, b.lotsAt, b.lotsTotal = s.ladder.source, s.ladder.time, s.ladder.total end
        end
        p.parts[#p.parts + 1] = b
        return b
    end
    for _, part in ipairs(v.parts) do
        local b = Line(part.itemID)
        local m = part.maker
        if b and m and m.cost then
            b.makeEach, b.makeSecs = m.cost / m.made, m.seconds / m.made
            b.buyEach = part.craft and part.buyEach or part.each
        end
    end
    for _, part in ipairs(v.parts) do
        local s = part.maker and state[part.itemID]
        if s and s.subCrafts > 0 then
            for _, sub in ipairs(part.maker.parts) do
                Line(sub.itemID, true, sub.owned and s.subCrafts * sub.need or nil)
            end
        end
    end
    return p
end

-- Plans are kept by two generations:
--   prices  (Plan.ClearCache: new prices, lots, settings)   a plan of an older one is counted again
--   bags    (Plan.Touch: bags or money changed)               a plan of an older one is counted again only where
--                                                             it matters: at the auction house or a merchant (or
--                                                             always, with plansOnlyAtAH off) or when fresh is asked
-- While crafting, the list's plans are never counted again (fresh still is: the plan panel's own recipe).
local priceGen, bagGen = 0, 0

local function Shopping()
    if not NPP.Get("plansOnlyAtAH") then return true end
    if NPP.Live and NPP.Live.Open() then return true end
    local merchant = _G.MerchantFrame
    return merchant ~= nil and merchant:IsShown()
end

function Plan.For(recipeID, outputOverride, fresh)
    if not recipeID then return end
    local p = cache[recipeID]
    if p then
        if not fresh and NPP.Crafting() then return p end
        if p.priceGen == priceGen and (p.bagGen == bagGen or (not fresh and not Shopping())) then return p end
    end
    p = Compute(recipeID, outputOverride)
    p.priceGen, p.bagGen = priceGen, bagGen
    cache[recipeID] = p
    return p
end

function Plan.ForEntry(e)
    if e.recipe then return Plan.For(e.recipe.recipeID) end
    if e.unlearned then return Plan.For(e.unlearned.spell, e.unlearned.item) end
end

function Plan.ClearCache()
    priceGen = priceGen + 1
    bagGen = bagGen + 1
end

function Plan.Touch()
    bagGen = bagGen + 1
end

-- Plans follow the gold on the character (budget "auto") and the bags.
local pending = false
local function Watched(event)
    if event == "PLAYER_MONEY" then return NPP.Get("budget") == "auto" end
    return NPP.Get("limitByBags") == true
end

local function ListUsesPlans()
    local mode = NPP.Get("sortMode")
    return mode == "total" or mode == "hour"
end

-- While crafting only the plan panel is redrawn (one recipe); the list is sorted again once, after the crafting.
local waitingForCraftEnd = false
local function RefreshAfterCrafting()
    if NPP.Crafting() then
        C_Timer.After(1, function() NPP.Safe("money", RefreshAfterCrafting) end)
        return
    end
    waitingForCraftEnd = false
    if Shopping() then NPP.Refresh() end
end

local function MoneyChanged()
    pending = false
    if not NPP.P then return end
    Plan.Touch()
    if NPP.PlanPanel then NPP.Safe("plan panel", NPP.PlanPanel.Render) end
    if not (ListUsesPlans() and Shopping()) then return end
    if not NPP.Crafting() then
        NPP.Refresh()
    elseif not waitingForCraftEnd then
        waitingForCraftEnd = true
        C_Timer.After(1, function() NPP.Safe("money", RefreshAfterCrafting) end)
    end
end
local money = CreateFrame("Frame")
money:RegisterEvent("PLAYER_MONEY")
money:RegisterEvent("BAG_UPDATE_DELAYED")
money:RegisterEvent("AUCTION_HOUSE_SHOW")
money:RegisterEvent("MERCHANT_SHOW")
money:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_HOUSE_SHOW" or event == "MERCHANT_SHOW" then
        -- where the plans matter: count the list's plans again with today's bags and money
        if NPP.P and ListUsesPlans() and NPP.Get("plansOnlyAtAH") then
            Plan.Touch()
            C_Timer.After(0.5, function() NPP.Safe("money", NPP.Refresh) end)
        end
        return
    end
    if pending or not Watched(event) then return end
    pending = true
    C_Timer.After(0.5, function() NPP.Safe("money", MoneyChanged) end)
end)

local LIMITS = {
    cap = "plan limit (/km planmax)",
    demand = "demand (TSM sold per day)",
    supply = "reagents on sale run out",
    partial = "only part of the lots is loaded (refresh lots again)",
    profit = "next craft would not pay",
    money = "not enough money",
    bags = "not enough bag space",
    noprice = "no prices",
}
function Plan.LimitText(p)
    return L(LIMITS[p.limit] or tostring(p.limit))
end

-- To Naowh's shopping list. With the plan (p) and Naowh's single-item list (Shopping.AddItem): exactly the items
-- the plan buys (AH and merchant units; bags and your own crafts left out), so Naowh does not swap in its own
-- craft-or-buy choice. Otherwise: the recipe's crafts, and Naowh works out the materials itself.
local function AddPlanItems(Shopping, p)
    local parts = {}
    for _, b in ipairs(p.parts or {}) do
        local n = (b.ah or 0) + (b.vendor or 0)
        if n > 0 then
            local ok, err = pcall(Shopping.AddItem, b.itemID, n)
            if not ok then
                NPP.Report("shopping item", err)
                return false
            end
            parts[#parts + 1] = ("%dx %s"):format(n, NPP.Profit.ItemName(b.itemID))
        end
    end
    if #parts == 0 then
        NPP.Print(L("Nothing to buy: everything is in your bags or crafted."))
        return false
    end
    NPP.Print(L("Shopping list: added %s."), table.concat(parts, ", "))
    return true
end

function Plan.AddToShopping(recipeID, crafts, p)
    if p and NPP.Shop and NPP.Started("shop") and NPP.Get("shopTarget") ~= "naowh" then
        local added = NPP.Shop.AddPlan(p)
        if added and NPP.Live and NPP.Live.Open() then NPP.Shop.ShowPanel(true) end
        return added
    end
    local Shopping = NPP.P and NPP.P.Shopping
    if p and Shopping and type(Shopping.AddItem) == "function" then return AddPlanItems(Shopping, p) end
    if not (Shopping and type(Shopping.Add) == "function") then
        NPP.Print(L("Naowh's shopping list is not available."))
        return false
    end
    local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
    if not (info and info.learned) then
        NPP.Print(L("Only learned recipes can go on the shopping list."))
        return false
    end
    local ok, added = pcall(Shopping.Add, info, crafts)
    if not ok then
        NPP.Report("shopping", added)
        return false
    end
    if added == false then NPP.Print(L("Naowh did not add it (no materials needed?).")) end
    return added ~= false
end
