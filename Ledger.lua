-- Ledger.lua: what you really spent and earned, since the last /km ledger reset.
-- Recorded from events only: the auction house's purchase functions and C_Container.UseContainerItem are
-- protected, and a hook on them made the game block purchases ("ADDON_ACTION_BLOCKED ... UNKNOWN()").
--   auction purchases   commodities: the price quote (COMMODITY_PRICE_UPDATED: total; the item is the last one
--                       searched, or the one our shopping list says it buys - Ledger.Expect) and its
--                       COMMODITY_PURCHASE_SUCCEEDED
--   merchant purchases  BuyMerchantItem (not protected; repairs are not counted)
--   merchant sales      what leaves the bags while a merchant is open and money comes in (any way of
--                       selling), at the item's merchant price; what comes back that was not bought was bought
--                       back. (The buyback list holds only 12 stacks, too few for a batch of crafts.)
--   crafts              UNIT_SPELLCAST_SUCCEEDED of a recipe of the open profession
--   auction sales       from Naowh's The Market ledger (the money that came by mail for a sold auction), when The
--                       Market is installed: its "auction" entries of items your recipes make, on their own day
-- Not recorded: single (non-stackable) auction purchases, deposits, repairs.
-- A recipe's real result: what its sold results brought minus its reagents' cost for those units,
-- each reagent at the average price you actually paid (the market price when you bought none: "~").
-- Days (db.ledgerDays, kept 60 days, not cleared by /km ledger reset): spent, merchant sales and crafts per
-- calendar day, and per recipe its crafts and what its results brought.
-- Other modules can listen to purchases (Ledger.OnBought) - the shopping list counts its items down that way.
local _, NPP = ...
local L = NPP.L

local Ledger = {}
NPP.Ledger = Ledger

function Ledger.Data()
    local db = NPP.db
    if not db then return end
    local d = db.ledger
    if type(d) ~= "table" then
        d = {}
        db.ledger = d
    end
    d.started = d.started or time()
    d.items = d.items or {}     -- [itemID] = { bought, spent, sold, earned } (spent: AH + merchant)
    d.recipes = d.recipes or {} -- [recipeID] = { crafts, output, name }
    d.ahSpent = d.ahSpent or 0
    d.vendorSpent = d.vendorSpent or 0
    d.vendorEarned = d.vendorEarned or 0
    return d
end

local KEEP_DAYS = 60
local listeners = {}

function Ledger.OnBought(fn) listeners[#listeners + 1] = fn end

function Ledger.DayKey(t) return date("%Y-%m-%d", t or time()) end

function Ledger.Days()
    local db = NPP.db
    if not db then return {} end
    if type(db.ledgerDays) ~= "table" then db.ledgerDays = {} end
    return db.ledgerDays
end

local function Day(at)
    local days = Ledger.Days()
    local key = Ledger.DayKey(at)
    local day = days[key]
    if not day then
        day = { ahSpent = 0, vendorSpent = 0, vendorEarned = 0, ahEarned = 0, crafts = 0, recipes = {} }
        days[key] = day
        local oldest = Ledger.DayKey(time() - KEEP_DAYS * 86400)
        for k in pairs(days) do
            if k < oldest then days[k] = nil end
        end
    end
    return day
end

local function DayRecipe(day, recipeID, name)
    local r = day.recipes[recipeID]
    if not r then
        r = { crafts = 0, earned = 0 }
        day.recipes[recipeID] = r
    end
    r.name = name or r.name
    return r
end

function Ledger.Reset()
    if not NPP.db then return end
    NPP.db.ledger = nil
    Ledger.Data()
end

local function Item(itemID)
    local d = Ledger.Data()
    local it = d.items[itemID]
    if not it then
        it = { bought = 0, spent = 0, sold = 0, earned = 0 }
        d.items[itemID] = it
    end
    return it
end

local function Changed()
    if NPP.PlanPanel then NPP.Safe("plan panel", NPP.PlanPanel.Render) end
end

-- What counts: the ledger is about crafting, not about everything bought and sold.
--   bought  a reagent of a recipe you know (Naowh's learned recipes, any profession) or an item on our shopping list
--   sold    a result of a recipe you know, an item on the sell list, or a result of a recipe the ledger saw crafted
local relevant, relevantAt = nil, 0
local function Relevant()
    if relevant and GetTime() - relevantAt < 60 then return relevant end
    relevant, relevantAt = { reagent = {}, result = {} }, GetTime()
    local S = NPP.P and NPP.P.Shopping
    if S and type(S.Makes) == "function" then
        local ok, makes = pcall(S.Makes)
        if ok and type(makes) == "table" then
            for output, m in pairs(makes) do
                relevant.result[output] = true
                for item in pairs(type(m) == "table" and m.need or {}) do relevant.reagent[item] = true end
            end
        end
    end
    local d = NPP.db and NPP.db.ledger
    for _, r in pairs(d and d.recipes or {}) do
        if r.output then relevant.result[r.output] = true end
    end
    return relevant
end

function Ledger.IsReagent(itemID)
    if Relevant().reagent[itemID] then return true end
    local shop = NPP.db and NPP.db.shop
    return shop and shop.items and shop.items[itemID] ~= nil or false
end

function Ledger.IsCraftedGood(itemID)
    if Relevant().result[itemID] then return true end
    return NPP.Sell and NPP.Sell.Has and NPP.Sell.Has(itemID) or false
end

function Ledger.ForgetRelevant() relevant = nil end

local function Bought(itemID, qty, copper, where)
    if not (itemID and qty and copper) or qty <= 0 or copper < 0 then return end
    -- the shopping list counts down any purchase of its items
    for _, fn in ipairs(listeners) do NPP.Safe("ledger listener", fn, itemID, qty, copper, where) end
    if not Ledger.IsReagent(itemID) then
        NPP.Debug("ledger: not a reagent, not counted: %s", itemID)
        return
    end
    local d = Ledger.Data()
    local it = Item(itemID)
    it.bought, it.spent = it.bought + qty, it.spent + copper
    if where == "ah" then d.ahSpent = d.ahSpent + copper else d.vendorSpent = d.vendorSpent + copper end
    local day = Day()
    if where == "ah" then day.ahSpent = day.ahSpent + copper else day.vendorSpent = day.vendorSpent + copper end
    NPP.Debug("ledger: bought %d x %s for %s (%s)", qty, itemID, copper, where)
    Changed()
end

-- where: "ah" (an auction sold, money by mail) or merchant; at: when (a past auction sale goes on its own day)
local function Sold(itemID, qty, copper, where, at)
    if not (itemID and qty and copper) then return end
    if not Ledger.IsCraftedGood(itemID) then
        NPP.Debug("ledger: not a crafted good, not counted: %s", itemID)
        return
    end
    local d = Ledger.Data()
    local ah = where == "ah"
    if not at or at >= (d.started or 0) then -- the period since /km ledger reset
        local it = Item(itemID)
        it.sold, it.earned = it.sold + qty, it.earned + copper
        if ah then d.ahEarned = (d.ahEarned or 0) + copper else d.vendorEarned = d.vendorEarned + copper end
    end
    local day = Day(at)
    if ah then day.ahEarned = (day.ahEarned or 0) + copper else day.vendorEarned = day.vendorEarned + copper end
    local recipeID, name
    for id, r in pairs(d.recipes) do
        if r.output == itemID then recipeID, name = id, r.name break end
    end
    if not recipeID and NPP.PriceFloor and NPP.PriceFloor.RecipeFor then
        recipeID = NPP.PriceFloor.RecipeFor(itemID)
        name = recipeID and C_Spell.GetSpellName(recipeID)
    end
    if recipeID then
        local dr = DayRecipe(day, recipeID, name)
        dr.earned = dr.earned + copper
    end
    NPP.Debug("ledger: sold %d x %s for %s", qty, itemID, copper)
    Changed()
end

-- Average price you paid for an item; nil when you bought none in this period.
function Ledger.Paid(itemID)
    local d = Ledger.Data()
    local it = d and d.items[itemID]
    if it and it.bought > 0 then return it.spent / it.bought end
end

---------------------------------------------------------------------------------------------------
-- Auction house
---------------------------------------------------------------------------------------------------

local lastSearched -- item of the last commodity search answered
local quote        -- { itemID, qty, total } of the price the auction house quoted
local expect       -- { itemID, qty } our shopping list is about to ask the price for

-- Our shopping list says which item and how many it asks the price for (a quote names neither).
function Ledger.Expect(itemID, qty)
    expect = { itemID = itemID, qty = qty }
end

-- Which item a quote is for when nobody told us: Naowh checks every item first and buys after, so the last
-- search says little. Candidates: Naowh's shopping list materials and our list's items given to Naowh;
-- the one whose amount times its usual price is closest to the quoted total wins.
local function GuessQuote(unit, total)
    local cands = {}
    local S = NPP.P and NPP.P.Shopping
    if S and type(S.Materials) == "function" then
        local ok, list = pcall(S.Materials)
        if ok and type(list) == "table" then
            for _, m in ipairs(list) do
                if m.item and m.qty and m.qty > 0 then cands[#cands + 1] = { itemID = m.item, qty = m.qty } end
            end
        end
    end
    if NPP.Shop and NPP.Shop.Data then
        for id, e in pairs(NPP.Shop.Data().items) do
            if (e.handed or 0) > 0 then cands[#cands + 1] = { itemID = id, qty = e.handed } end
        end
    end
    local guessQty = (type(unit) == "number" and unit > 0) and math.floor(total / unit + 0.5) or nil
    local best, bestErr
    for _, c in ipairs(cands) do
        local ref = NPP.PriceSource.AH(c.itemID) or unit
        local err = math.abs(c.qty * ref - total) / math.max(total, 1)
        if guessQty and c.qty ~= guessQty then err = err + 0.5 end
        if not bestErr or err < bestErr then best, bestErr = c, err end
    end
    if best and bestErr < 1 then return best.itemID, best.qty end
    return lastSearched, guessQty
end

local function OnAuctionEvent(event, a, b)
    if event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        lastSearched = a
    elseif event == "COMMODITY_PRICE_UPDATED" then
        local unit, total = a, b
        local id, qty
        if expect then
            id, qty = expect.itemID, expect.qty
        elseif type(total) == "number" then
            id, qty = GuessQuote(unit, total)
        end
        quote = { itemID = id, qty = qty, total = total }
        NPP.Debug("ledger: quote %s for %s x %s", total, qty, id)
    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" then
        local q = quote
        quote, expect = nil, nil
        if q and q.itemID and q.qty and q.total then Bought(q.itemID, q.qty, q.total, "ah") end
    elseif event == "COMMODITY_PURCHASE_FAILED" or event == "COMMODITY_PRICE_UNAVAILABLE" then
        quote, expect = nil, nil
    elseif event == "AUCTION_HOUSE_CLOSED" then
        quote, expect, lastSearched = nil, nil, nil
    end
end

---------------------------------------------------------------------------------------------------
-- Merchant
---------------------------------------------------------------------------------------------------

local function MerchantOpen()
    local frame = _G.MerchantFrame
    return frame ~= nil and frame:IsShown()
end

local bagSnap        -- [itemID] = count at the last look
local snapMoney      -- money at the last look
local boughtUnits = {} -- [itemID] = units bought from the merchant since the last look (they arrive in the bags)
local boughtCost = 0   -- copper spent at the merchant since the last look
local soldHere = {}    -- [itemID] = units sold during this visit (for buybacks)
local lastCraft = 0    -- GetTime() of the last craft: reagents used up are not sales

local function OnBuyMerchant(index, qty)
    if not MerchantOpen() then return end
    local itemID = GetMerchantItemID and GetMerchantItemID(index)
    local price, stack, extended
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local info = C_MerchantFrame.GetItemInfo(index)
        if info then price, stack, extended = info.price, info.stackCount, info.hasExtendedCost end
    elseif GetMerchantItemInfo then
        local _, _, p, s, _, _, _, e = GetMerchantItemInfo(index)
        price, stack, extended = p, s, e
    end
    if extended or not (itemID and price and price > 0) then return end
    stack = math.max(1, stack or 1)
    qty = tonumber(qty) or stack
    local cost = math.floor(price / stack * qty + 0.5)
    boughtUnits[itemID] = (boughtUnits[itemID] or 0) + qty
    boughtCost = boughtCost + cost
    Bought(itemID, qty, cost, "vendor")
end

-- Sales, seen in the bags while a merchant is open: items that left, when money came in.

local function LastBag() return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 end

local function BagCounts()
    local counts = {}
    for bag = 0, LastBag() do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1) end
        end
    end
    return counts
end

local function Look()
    if not bagSnap then return end
    local now = BagCounts()
    local gained = GetMoney() - snapMoney + boughtCost -- money in from sales (merchant purchases put back)
    local left, back = {}, {}
    for id, n in pairs(bagSnap) do
        local d = (now[id] or 0) - n
        if d < 0 then left[id] = -d end
    end
    for id, n in pairs(now) do
        local d = n - (bagSnap[id] or 0)
        if d > 0 then
            local bought = math.min(d, boughtUnits[id] or 0)
            if d - bought > 0 then back[id] = d - bought end
        end
    end
    if next(left) and gained <= 0 then
        if GetTime() - lastCraft < 3 then
            -- reagents used up by a craft at the merchant: not a sale, start from here
            bagSnap, snapMoney, boughtCost = now, GetMoney(), 0
            wipe(boughtUnits)
        end
        -- otherwise the sale may not be answered yet: look again on the next change
        return
    end
    for id, n in pairs(left) do
        local each = NPP.PriceSource.VendorSell(id)
        if each and each > 0 then
            Sold(id, n, each * n)
            soldHere[id] = (soldHere[id] or 0) + n
        end
    end
    for id, n in pairs(back) do
        local take = math.min(n, soldHere[id] or 0)
        local each = NPP.PriceSource.VendorSell(id)
        if take > 0 and each and each > 0 then
            Sold(id, -take, -each * take)
            soldHere[id] = soldHere[id] - take
        end
    end
    bagSnap, snapMoney, boughtCost = now, GetMoney(), 0
    wipe(boughtUnits)
end

local function OnMerchant(event)
    if event == "MERCHANT_SHOW" then
        bagSnap, snapMoney, boughtCost = BagCounts(), GetMoney(), 0
        wipe(boughtUnits)
        wipe(soldHere)
    elseif event == "MERCHANT_CLOSED" then
        Look()
        bagSnap = nil
    else
        Look()
    end
end

---------------------------------------------------------------------------------------------------
-- Crafts
---------------------------------------------------------------------------------------------------

local function OnCast(spellID)
    if not NPP.IsRecipeSpell(spellID) then return end
    local info = C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(spellID)
    if not info then return end
    local d = Ledger.Data()
    local r = d.recipes[spellID]
    if not r then
        r = { crafts = 0 }
        d.recipes[spellID] = r
    end
    r.crafts = r.crafts + 1
    r.name = info.name or r.name
    lastCraft = GetTime()
    local day = Day()
    day.crafts = day.crafts + 1
    -- crafting time: the cast and the gap between repeated casts, as Naowh's craft timer counts it
    day.secs = (day.secs or 0) + ((NPP.Profit and NPP.Profit.CraftSeconds) and NPP.Profit.CraftSeconds(spellID) or 3.3)
    local dr = DayRecipe(day, spellID, r.name)
    dr.crafts = dr.crafts + 1
    if not r.output then
        local ok, output = pcall(NPP.P.Recipes.OutputItem, spellID)
        if ok and output then r.output = output end
    end
    Changed()
end

---------------------------------------------------------------------------------------------------
-- Results
---------------------------------------------------------------------------------------------------

-- A recipe's real result in this period: { crafts, sold, earned, cost, net, estimated, made }; nil if never crafted.
function Ledger.Recipe(recipeID)
    local d = Ledger.Data()
    local r = d and d.recipes[recipeID]
    if not r then return end
    local out = { crafts = r.crafts, name = r.name, output = r.output, sold = 0, earned = 0, cost = 0 }
    local it = r.output and d.items[r.output]
    if it then out.sold, out.earned = it.sold, it.earned end
    local v = NPP.Profit.Get(recipeID)
    local perCraft, estimated = 0, false
    for _, part in ipairs(v.parts or {}) do
        if not part.owned then
            local each = Ledger.Paid(part.itemID)
            if not each then
                each = part.craft and part.each or NPP.PriceSource.Buy(part.itemID)
                estimated = true
            end
            perCraft = perCraft + (each or 0) * part.need
        end
    end
    local made = v.made or 1
    if made <= 0 then made = 1 end
    out.made = made
    out.cost = math.floor(perCraft / made * math.max(out.sold, 0) + 0.5)
    out.net = out.earned - out.cost
    out.estimated = estimated
    return out
end

function Ledger.Started()
    local d = Ledger.Data()
    return d and d.started
end

-- Records from before the recipe check counted combat spells as crafts: take them out of the history and the period.
local function CleanOldCasts()
    local removed = 0
    for _, day in pairs(Ledger.Days()) do
        for id, r in pairs(day.recipes or {}) do
            if not NPP.IsRecipeSpell(id) then
                day.crafts = math.max(0, (day.crafts or 0) - (r.crafts or 0))
                removed = removed + (r.crafts or 0)
                day.recipes[id] = nil
            end
        end
    end
    local d = Ledger.Data()
    for id in pairs(d.recipes) do
        if not NPP.IsRecipeSpell(id) then d.recipes[id] = nil end
    end
    if removed > 0 then NPP.Debug("ledger: removed %d non-recipe casts from the history", removed) end
end

-- Auction sales from Naowh's The Market ledger (per character: at, kind, item, qty, amount). Entries newer than the
-- last one taken (per character) are taken once; the first time, everything still within the history's days.
local function ImportAuctionSales()
    local ns = NPP.ns
    local shared = ns and ns.Shared
    if not (shared and type(shared.CharacterData) == "function") then return end
    local ok, data = pcall(shared.CharacterData, "marketLedger", false)
    if not ok or type(data) ~= "table" or type(data.at) ~= "table" then return end
    local guid = UnitGUID("player")
    if not (guid and NPP.db) then return end
    NPP.db.ledgerMarketSeen = type(NPP.db.ledgerMarketSeen) == "table" and NPP.db.ledgerMarketSeen or {}
    local last = NPP.db.ledgerMarketSeen[guid] or (time() - KEEP_DAYS * 86400)
    local newest, taken = last, 0
    for i = 1, #data.at do
        local at = data.at[i]
        if type(at) == "number" and at > last and data.kind[i] == "auction" and (tonumber(data.amount[i]) or 0) > 0 then
            local item = data.item[i]
            local itemID = type(item) == "number" and item > 0 and item
                or (type(item) == "string" and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(item)) or nil
            if itemID then
                Sold(itemID, tonumber(data.qty[i]) or 1, tonumber(data.amount[i]), "ah", at)
                taken = taken + 1
            end
        end
        if type(at) == "number" and at > newest then newest = at end
    end
    NPP.db.ledgerMarketSeen[guid] = newest
    if taken > 0 then NPP.Debug("ledger: %d auction sales taken from The Market", taken) end
end
Ledger.ImportAuctionSales = ImportAuctionSales

function Ledger.ResetDays()
    if NPP.db then NPP.db.ledgerDays = nil end
end

NPP.Module("ledger", { "core" }, function()
    Ledger.Data()
    NPP.Safe("ledger clean", CleanOldCasts)
    -- auction sales: a moment after logging in, and after mail (where their money comes)
    C_Timer.After(5, function() NPP.Safe("ledger auction sales", ImportAuctionSales) end)
    local mail = CreateFrame("Frame")
    local waiting = false
    for _, e in ipairs({ "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "PLAYER_MONEY" }) do pcall(mail.RegisterEvent, mail, e) end
    mail:SetScript("OnEvent", function()
        if waiting then return end
        waiting = true
        C_Timer.After(3, function()
            waiting = false
            NPP.Safe("ledger auction sales", ImportAuctionSales)
        end)
    end)
    -- no hooks on protected functions (auction purchases, using bag items): events only
    if BuyMerchantItem then
        hooksecurefunc("BuyMerchantItem", function(...) NPP.Safe("ledger buy", OnBuyMerchant, ...) end)
    end
    local events = CreateFrame("Frame")
    for _, e in ipairs({ "COMMODITY_SEARCH_RESULTS_UPDATED", "COMMODITY_PRICE_UPDATED", "COMMODITY_PRICE_UNAVAILABLE",
        "COMMODITY_PURCHASE_SUCCEEDED", "COMMODITY_PURCHASE_FAILED", "AUCTION_HOUSE_CLOSED",
        "MERCHANT_SHOW", "MERCHANT_CLOSED", "BAG_UPDATE_DELAYED", "PLAYER_MONEY" }) do
        pcall(events.RegisterEvent, events, e)
    end
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    events:SetScript("OnEvent", function(_, event, a, b, c)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            NPP.Safe("ledger craft", OnCast, c)
        elseif event == "MERCHANT_SHOW" or event == "MERCHANT_CLOSED" or event == "BAG_UPDATE_DELAYED"
            or event == "PLAYER_MONEY" then
            NPP.Safe("ledger merchant", OnMerchant, event)
        else
            NPP.Safe("ledger auction", OnAuctionEvent, event, a, b)
        end
    end)
end)
