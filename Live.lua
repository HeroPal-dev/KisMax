-- Live.lua: lots of single items, read from auction house searches.
-- Any search result is read as it arrives (yours in Blizzard's window, Naowh's shopping list and Buyer,
-- ours): unit price and quantity of every lot, your own lots left out, kept by Scan.StoreLive.
-- "Refresh lots" searches the selected recipe's reagents and result one after another, as Naowh's
-- shopping list does (SendSearchQuery, waiting for the throttle), and asks for more commodity lots
-- while fewer are loaded than the plan could use.
local _, NPP = ...
local L = NPP.L

local Live = {}
NPP.Live = Live

local SEARCH_TIMEOUT = 5   -- seconds without an answer: go on with the next item
local THROTTLE_WAIT = 0.5
local MAX_MORE = 6         -- "more results" requests per item
local REDRAW_DELAY = 0.3

local houseOpen = false
local kinds = {} -- [itemID] = "commodity" | "item": how the auction house lists it
local queue -- { ids = {...}, need = { [itemID] = units }, i = 0, gen = 0, waiting = itemID, more = 0, done = 0 }
local redrawPending = false

local function PriceSort()
    if Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price then
        return { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
    end
    return {}
end

local function Redraw()
    if redrawPending then return end
    redrawPending = true
    C_Timer.After(REDRAW_DELAY, function()
        redrawPending = false
        if NPP.Profit then NPP.Profit.ClearCache() end
        NPP.Refresh(false)
        if NPP.PlanPanel then NPP.PlanPanel.Render() end
    end)
end

local function ReadCommodity(itemID)
    local levels = {}
    local n = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
    for i = 1, n do
        local r = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
        if r and r.unitPrice and r.unitPrice > 0 then
            local qty = (r.quantity or 0) - (r.numOwnerItems or 0)
            if qty > 0 then levels[r.unitPrice] = (levels[r.unitPrice] or 0) + qty end
        end
    end
    local full = true
    if C_AuctionHouse.HasFullCommoditySearchResults then
        full = C_AuctionHouse.HasFullCommoditySearchResults(itemID) and true or false
    end
    kinds[itemID] = "commodity"
    local total, prices = NPP.Scan.StoreLive(itemID, levels, not full)
    NPP.Debug("live: item %s, %d results, %d units at %d prices%s", itemID, n, total, prices, full and "" or " (partial)")
    return total, full
end

local function ReadItems(itemKey)
    local itemID = itemKey and itemKey.itemID
    if not itemID then return end
    local levels = {}
    local n = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
    for i = 1, n do
        local r = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
        local qty = r and (r.quantity or 1) or 0
        if r and not r.containsOwnerItem and (r.buyoutAmount or 0) > 0 and qty > 0 then
            local each = math.floor(r.buyoutAmount / qty)
            levels[each] = (levels[each] or 0) + qty
        end
    end
    local full = true
    if C_AuctionHouse.HasFullItemSearchResults then
        full = C_AuctionHouse.HasFullItemSearchResults(itemKey) and true or false
    end
    kinds[itemID] = "item"
    local total, prices = NPP.Scan.StoreLive(itemID, levels, not full)
    NPP.Debug("live: item %s (lots), %d results, %d units at %d prices", itemID, n, total, prices)
    return itemID, total, full
end

local Next

local function Finish()
    local done, count, opts = queue.done, #queue.ids, queue.opts
    queue = nil
    if not opts.quiet then NPP.Print(L("Lots refreshed: %d of %d items answered."), done, count) end
    Redraw()
    if opts.onDone then NPP.Safe("live done", opts.onDone, done, count) end
end

local function Timeout(gen)
    C_Timer.After(SEARCH_TIMEOUT, function()
        if queue and queue.gen == gen and queue.waiting then
            NPP.Debug("live: no answer for item %s", queue.waiting)
            queue.waiting = nil
            NPP.Safe("live next", Next)
        end
    end)
end

function Next()
    if not queue then return end
    if not houseOpen then
        NPP.Print(L("Refreshing lots stopped: the auction house closed."))
        local opts = queue.opts
        queue = nil
        if opts.onDone then NPP.Safe("live done", opts.onDone, 0, 0) end
        return
    end
    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
        C_Timer.After(THROTTLE_WAIT, function() NPP.Safe("live next", Next) end)
        return
    end
    queue.i = queue.i + 1
    local id = queue.ids[queue.i]
    if not id then return Finish() end
    queue.waiting, queue.more = id, 0
    queue.gen = queue.gen + 1
    C_AuctionHouse.SendSearchQuery(C_AuctionHouse.MakeItemKey(id), PriceSort(), true)
    Timeout(queue.gen)
end

local function Answered()
    queue.done = queue.done + 1
    queue.waiting = nil
    C_Timer.After(0, function() NPP.Safe("live next", Next) end)
end

local function OnCommodity(itemID)
    local total, full = ReadCommodity(itemID)
    if queue and queue.waiting == itemID then
        local need = queue.need[itemID] or 0
        if not full and total < need and queue.more < MAX_MORE and C_AuctionHouse.RequestMoreCommoditySearchResults then
            queue.more = queue.more + 1
            queue.gen = queue.gen + 1
            C_AuctionHouse.RequestMoreCommoditySearchResults(itemID)
            Timeout(queue.gen)
            return
        end
        Answered()
    else
        Redraw()
    end
end

local function OnItems(itemKey)
    local itemID = ReadItems(itemKey)
    if queue and itemID and queue.waiting == itemID then
        Answered()
    else
        Redraw()
    end
end

function Live.Open() return houseOpen end
function Live.Kind(itemID) return kinds[itemID] end
function Live.Busy() return queue ~= nil end

-- Searches the given items; need = { [itemID] = units the plan could use } decides when to load more lots.
-- opts: quiet (no chat lines), onDone(answered, count) when the last search is answered.
function Live.Refresh(ids, need, opts)
    opts = opts or {}
    if not houseOpen then
        NPP.Print(L("Open the auction house first: lots can be read only there."))
        return false
    end
    if queue then
        NPP.Print(L("Lots are being refreshed already."))
        return false
    end
    if #ids == 0 then return false end
    queue = { ids = ids, need = need or {}, i = 0, gen = 0, more = 0, done = 0, opts = opts }
    if not opts.quiet then NPP.Print(L("Refreshing lots of %d items..."), #ids) end
    Next()
    return true
end

-- The reagents (not your own) and the result of a recipe, with how many units a full plan could use.
function Live.RefreshRecipe(recipeID, outputOverride)
    local v = NPP.Profit.Get(recipeID, outputOverride)
    local ids, need, seen = {}, {}, {}
    local crafts = math.max(1, tonumber(NPP.Get("planMax")) or 200)
    local function Add(itemID, units)
        if seen[itemID] then
            need[itemID] = (need[itemID] or 0) + units
            return
        end
        seen[itemID] = true
        ids[#ids + 1] = itemID
        need[itemID] = units
    end
    for _, part in ipairs(v.parts or {}) do
        if not part.owned then
            Add(part.itemID, part.need * crafts)
            -- an intermediate you can craft: its reagents too, so craft vs buy compares fresh lots
            local m = part.maker
            if m then
                local subCrafts = math.ceil(part.need * crafts / math.max(1, m.made))
                for _, sub in ipairs(m.parts) do
                    if not sub.owned then Add(sub.itemID, sub.need * subCrafts) end
                end
            end
        end
    end
    if v.output and not seen[v.output] then ids[#ids + 1] = v.output end
    return Live.Refresh(ids, need)
end

NPP.Module("live", { "live" }, function()
    local events = CreateFrame("Frame")
    events:RegisterEvent("AUCTION_HOUSE_SHOW")
    events:RegisterEvent("AUCTION_HOUSE_CLOSED")
    events:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
    events:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
    events:SetScript("OnEvent", function(_, event, a)
        if event == "AUCTION_HOUSE_SHOW" then
            houseOpen = true
            if NPP.PlanPanel then NPP.PlanPanel.Render() end
        elseif event == "AUCTION_HOUSE_CLOSED" then
            houseOpen = false
            if NPP.PlanPanel then NPP.PlanPanel.Render() end
        elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
            if type(a) == "number" then NPP.Safe("live read", OnCommodity, a) end
        elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
            if type(a) == "table" then NPP.Safe("live read", OnItems, a) end
        end
    end)
end)
