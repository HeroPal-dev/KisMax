-- PriceSource.lua: where an item's prices come from.
-- Auction price, sources (priceSource):
--   auto           our scan by depth if it is under 24h old, else TSM chain, else our old scan, else Naowh
--   depth          our scan (Scan.lua): the price below which depthPct% of the listed quantity sits,
--                  so one cheap listing does not set the price
--   tsm_chain      TSM custom price string tsmPrice, default first(DBMarket, DBHistorical, DBRegionMarketAvg)
--   tsm_market     TSM DBMarket
--   tsm_minbuyout  TSM DBMinBuyout
--   naowh          NaowhForever_QoL's last full scan: the lowest buyout (ns.AuctionPrice)
-- With tsmFallback on, an explicit source that has no price falls back to our scan, then Naowh's.
-- A reagent's buy price is the cheaper of the merchant price (Naowh's vendor table) and the AH price.
-- Vendor sell price is the game's sellPrice (C_Item.GetItemInfo, 11th value).
local _, NPP = ...
local L = NPP.L

local PS = {}
NPP.PriceSource = PS

local FRESH = 24 * 60 * 60
local NONE = false

local TSM_KEYS = { tsm_chain = true, tsm_market = "DBMarket", tsm_minbuyout = "DBMinBuyout" }
local ORDER_FRESH = { "depth", "tsm_chain", "naowh" }
local ORDER_OLD = { "tsm_chain", "depth", "naowh" }
local orders = {}

local ahCache, vendorCache, sellCache, demandCache = {}, {}, {}, {}
local tsmErrorShown = {}

function PS.TSMAvailable()
    local api = _G.TSM_API
    return type(api) == "table" and type(api.GetCustomPriceValue) == "function"
end

local function TSMKey(src)
    if src == "tsm_chain" then return NPP.Get("tsmPrice") end
    return TSM_KEYS[src]
end

local function TSMValue(key, itemID)
    if type(key) ~= "string" or key == "" or not PS.TSMAvailable() then return end
    local ok, value, err = pcall(_G.TSM_API.GetCustomPriceValue, key, "i:" .. itemID)
    if ok and type(value) == "number" and value > 0 then return value end
    local why = ok and err or value
    if why and not tsmErrorShown[key] then
        tsmErrorShown[key] = true
        NPP.Debug("TSM '%s' for item %s: %s", key, itemID, why)
    end
end
PS.TSMValue = TSMValue

local function NaowhValue(itemID)
    local ns = NPP.ns
    if not (ns and type(ns.AuctionPrice) == "function") then return end
    local ok, value = pcall(ns.AuctionPrice, itemID)
    if ok and type(value) == "number" and value > 0 then return value end
end

function PS.NaowhScanTime()
    local ns = NPP.ns
    if not (ns and type(ns.AuctionScanTime) == "function") then return end
    local ok, t = pcall(ns.AuctionScanTime)
    if ok and type(t) == "number" then return t end
end

function PS.NaowhPricedCount()
    local ns = NPP.ns
    if not (ns and type(ns.AuctionPriceList) == "function") then return 0 end
    local ok, prices = pcall(ns.AuctionPriceList)
    if not (ok and type(prices) == "table") then return 0 end
    local n = 0
    for _ in pairs(prices) do n = n + 1 end
    return n
end

local function ScanTime()
    return NPP.Scan and NPP.Scan.Time()
end

local function Try(src, itemID)
    if src == "depth" then
        return NPP.Scan and NPP.Scan.DepthPrice(itemID, NPP.Get("depthPct"))
    elseif src == "naowh" then
        return NaowhValue(itemID)
    elseif TSM_KEYS[src] then
        return TSMValue(TSMKey(src), itemID)
    end
end

local LIVE_FRESH = 60 * 60

local function Order(itemID)
    local src = NPP.Get("priceSource")
    if src == "auto" then
        local t = ScanTime()
        if t and time() - t < FRESH then return ORDER_FRESH end
        -- lots of this item from a search on the auction house within the hour
        local ladder = itemID and NPP.Scan and NPP.Scan.Ladder(itemID)
        if ladder and ladder.source == "live" and time() - (ladder.time or 0) < LIVE_FRESH then return ORDER_FRESH end
        return ORDER_OLD
    end
    if not NPP.Get("tsmFallback") then
        orders[src] = orders[src] or { src }
        return orders[src]
    end
    local key = src .. "+"
    if not orders[key] then
        local list = { src }
        for _, other in ipairs({ "depth", "naowh" }) do
            if other ~= src then list[#list + 1] = other end
        end
        orders[key] = list
    end
    return orders[key]
end

-- Is there any price data at all? Without it every profit is unknown, so the filters stay off.
function PS.HasData()
    return PS.TSMAvailable() or ScanTime() ~= nil or PS.NaowhScanTime() ~= nil
end

-- Auction price of one unit: price, source key.
function PS.AH(itemID)
    if not itemID then return end
    local cached = ahCache[itemID]
    if cached ~= nil then
        if cached == NONE then return end
        return cached[1], cached[2]
    end
    local value, from
    for _, src in ipairs(Order(itemID)) do
        value = Try(src, itemID)
        if value then
            from = src
            break
        end
    end
    ahCache[itemID] = value and { value, from } or NONE
    return value, from
end

-- Merchant price to buy (Naowh's built-in and seen vendor prices).
function PS.Vendor(itemID)
    if not itemID then return end
    local cached = vendorCache[itemID]
    if cached ~= nil then return cached or nil end
    local V = NPP.P and NPP.P.Vendors
    local ok, value = false, nil
    -- Naowh's built-in list price, minus your merchant discount (Legacy perk); a price Naowh saw at a merchant
    -- (when there is no list price) is what that merchant asked, the discount already in it
    local list = NPP.P and type(NPP.P.VendorPrices) == "table" and NPP.P.VendorPrices[itemID]
    if type(list) == "number" and list > 0 then
        ok, value = true, list * (NPP.Discount and NPP.Discount.Factor() or 1)
    elseif V and V.Price then
        ok, value = pcall(V.Price, itemID)
    end
    value = ok and type(value) == "number" and value > 0 and value or nil
    vendorCache[itemID] = value or NONE
    return value
end

-- Cheapest way to buy a reagent: price, "vendor" or the AH source key.
function PS.Buy(itemID)
    local vendor = PS.Vendor(itemID)
    local ah, from = PS.AH(itemID)
    if vendor and (not ah or vendor <= ah) then return vendor, "vendor" end
    if ah then return ah, from end
end

-- What a merchant pays for one: price, or nil (cannot be sold, or item data still loading).
function PS.VendorSell(itemID)
    if not itemID then return end
    local cached = sellCache[itemID]
    if cached ~= nil then return cached or nil end
    local ok, sell = pcall(function() return select(11, C_Item.GetItemInfo(itemID)) end)
    if not ok or sell == nil then
        local R = NPP.P and NPP.P.Recipes
        if R and R.Request then pcall(R.Request, itemID) end -- Naowh redraws when the data arrives
        return
    end
    sellCache[itemID] = (type(sell) == "number" and sell > 0) and sell or NONE
    return sellCache[itemID] or nil
end

-- Units sold per day on the region (TSM). Region-wide, so for one realm it is an upper bound.
function PS.SoldPerDay(itemID)
    if not itemID then return end
    local cached = demandCache[itemID]
    if cached ~= nil then return cached or nil end
    local value = TSMValue("DBRegionSoldPerDay * 1000", itemID) -- TSM rounds, so it is scaled up
    value = value and value / 1000
    demandCache[itemID] = value or NONE
    return value
end

function PS.ClearCache()
    wipe(ahCache)
    wipe(vendorCache)
    wipe(sellCache)
    wipe(demandCache)
end

local LABELS = {
    auto = "Auto",
    depth = "Our scan (by quantity)",
    naowh = "Naowh scan (min buyout)",
    tsm_chain = "TSM (price chain)",
    tsm_market = "TSM DBMarket",
    tsm_minbuyout = "TSM DBMinBuyout",
    vendor = "merchant",
    own = "own",
    bags = "bags",
}
LABELS.craft = "your craft"

function PS.Label(key)
    return L(LABELS[key] or tostring(key))
end

local function Age(t)
    if not t then return end
    local seconds = math.max(0, time() - t)
    local ns = NPP.ns
    if ns and type(ns.AuctionAge) == "function" then
        local ok, text = pcall(ns.AuctionAge, seconds)
        if ok and text then return text end
    end
    return math.floor(seconds / 60) .. "m"
end
PS.Age = Age

function PS.NaowhAge() return Age(PS.NaowhScanTime()) end
function PS.ScanAge() return Age(ScanTime()) end

function PS.Status()
    local ns = NPP.ns
    if not (ns and type(ns.AuctionPrice) == "function") then
        NPP.Print(L("  Naowh scan: NaowhForever_QoL is not loaded (no ns.AuctionPrice)."))
    elseif PS.NaowhScanTime() then
        NPP.Print(L("  Naowh scan: %s ago, %d items priced."), PS.NaowhAge(), PS.NaowhPricedCount())
    else
        NPP.Print(L("  Naowh scan: no scan for this realm and faction yet (Scan Prices at the AH)."))
    end
    if ScanTime() then
        NPP.Print(L("  Our scan (quantities): %s ago, %d items."), PS.ScanAge(), NPP.Scan.Count())
    else
        NPP.Print(L("  Our scan (quantities): none yet. Press Scan Prices at the AH; it is read at the same time."))
    end
    if PS.TSMAvailable() then
        -- Linen Cloth (stackable, a commodity) and Linen Belt (not stackable): which TSM sources answer.
        for _, item in ipairs({ { 2589, "Linen Cloth" }, { 7026, "Linen Belt" } }) do
            local parts = {}
            for _, key in ipairs({ "DBMarket", "DBMinBuyout", "DBHistorical", "DBRegionMarketAvg", "DBNumAuctions" }) do
                local v = TSMValue(key, item[1])
                parts[#parts + 1] = key .. "=" .. (v and (key == "DBNumAuctions" and tostring(v) or NPP.Coins(v)) or "-")
            end
            local sold = PS.SoldPerDay(item[1])
            parts[#parts + 1] = "SoldPerDay=" .. (sold and ("%.2f"):format(sold) or "-")
            NPP.Print("  TSM %s: %s", item[2], table.concat(parts, ", "))
        end
        local chain = TSMValue(NPP.Get("tsmPrice"), 2589)
        NPP.Print(L("  TSM price chain: %s -> Linen Cloth %s"), NPP.Get("tsmPrice"),
            chain and NPP.Coins(chain) or L("no data"))
    else
        NPP.Print(L("  TSM: not loaded (TSM_API missing)."))
    end
    local order = {}
    for _, src in ipairs(Order()) do order[#order + 1] = PS.Label(src) end
    NPP.Print(L("  Source: %s -> order: %s."), PS.Label(NPP.Get("priceSource")), table.concat(order, " > "))
end
