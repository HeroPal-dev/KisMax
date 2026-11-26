-- Scan.lua: the auction "order book" with quantities. It does not start a scan of its own: when a
-- full scan finishes (Naowh's Scan Prices button, TSM, or any addon calling ReplicateItems), the game
-- fires REPLICATE_ITEM_LIST_UPDATE and we read the same listings, keeping for each item its cheapest
-- price levels (unit price -> quantity) and the total quantity listed. Your own auctions are skipped.
-- Naowh's own scan gives up after 60 s ("no answer from the auction house") while a slow server is still sending
-- the listings; we keep reading. When our read finishes and Naowh's prices are older than this scan, we write the
-- lowest unit price of every item into Naowh's price table (its own format: account ahPrices[realm-faction] =
-- { prices = { [itemID] = copper }, time = epoch }) so Naowh's window shows today's prices too (feedNaowh).
-- Kept per realm and faction in KisMaxAH:
--   [house] = { time = epoch, listings = n, ladders = { [itemID] = "price:qty,price:qty,..." },
--               totals = { [itemID] = qty } }
local _, NPP = ...
local L = NPP.L

local Scan = {}
NPP.Scan = Scan

local READ_CHUNK = 500   -- listings read per frame
local PACK_CHUNK = 400   -- items packed per frame
local LEVELS = 16        -- cheapest price levels kept per item
local IGNORE_AFTER = 120 -- seconds: another update right after a read is the same scan

local reading, lastFinish, gen = false, 0, 0
local parsed = {}
local houseKey

-- Next chunk on the next frame; an error there stops the read instead of leaving it stuck.
local function Later(fn)
    C_Timer.After(0, function()
        if not NPP.Safe("scan", fn) then reading = false end
    end)
end

local function HouseKey()
    if not houseKey then
        houseKey = (GetRealmName() or "?") .. "-" .. (UnitFactionGroup("player") or "")
    end
    return houseKey
end

local function House(create)
    local root = _G.KisMaxAH
    if type(root) ~= "table" then
        if not create then return end
        root = {}
        _G.KisMaxAH = root
    end
    local key = HouseKey()
    if create and type(root[key]) ~= "table" then root[key] = {} end
    return root[key]
end

-- Naowh's prices from this scan, when Naowh did not keep them itself.
local function FeedNaowh(mins, count, scanTime)
    if not NPP.Get("feedNaowh") then return end
    local ns = NPP.ns
    if not (ns and type(ns.AccountSettings) == "function") then return end
    -- Naowh 1.4+ reads the auction house page by page when its fast scan gets no answer, and keeps more in its
    -- price table (listed, medians, suffixes): it no longer needs ours, and our old format would overwrite its own.
    if type(ns.AuctionHouseKey) == "function" then return end
    local account = ns.AccountSettings()
    if type(account) ~= "table" then return end
    account.ahPrices = type(account.ahPrices) == "table" and account.ahPrices or {}
    local key = HouseKey()
    local theirs = account.ahPrices[key]
    if type(theirs) == "table" and (theirs.time or 0) >= scanTime then
        NPP.Debug("scan: Naowh kept this scan itself")
        return
    end
    account.ahPrices[key] = { prices = mins, time = scanTime }
    NPP.Print(L("Naowh's scan gave up early; its prices were taken from ours (%d items)."), count)
    if type(ns.ProfWindowRefresh) == "function" then pcall(ns.ProfWindowRefresh) end
end

local function Finish(ids, ladders, totals, listings, myGen, started, mins, scanTime)
    if myGen ~= gen then return end
    local house = House(true)
    house.time, house.listings, house.ladders, house.totals = time(), listings, ladders, totals
    wipe(parsed)
    reading, lastFinish = false, time()
    NPP.Print(L("Auction listings saved with quantities: %d items."), #ids)
    NPP.Debug("scan: %d listings, %d items, %.0f ms", listings, #ids, debugprofilestop() - started)
    NPP.Safe("feed naowh", FeedNaowh, mins, #ids, scanTime)
    if NPP.Profit then NPP.Profit.ClearCache() end
    NPP.Refresh(false)
end

local function Pack(acc, listings, myGen, started, scanTime)
    local ids, mins = {}, {}
    for id in pairs(acc) do ids[#ids + 1] = id end
    local ladders, totals = {}, {}
    local done = 0
    local prices, parts = {}, {}
    local function Step()
        if myGen ~= gen then return end
        local last = math.min(done + PACK_CHUNK, #ids)
        for k = done + 1, last do
            local id = ids[k]
            local levels = acc[id]
            wipe(prices)
            wipe(parts)
            local sum = 0
            for price, qty in pairs(levels) do
                prices[#prices + 1] = price
                sum = sum + qty
            end
            table.sort(prices)
            mins[id] = prices[1]
            for n = 1, math.min(#prices, LEVELS) do parts[n] = prices[n] .. ":" .. levels[prices[n]] end
            ladders[id] = table.concat(parts, ",")
            totals[id] = sum
            acc[id] = nil
        end
        done = last
        if done < #ids then
            Later(Step)
            return
        end
        Finish(ids, ladders, totals, listings, myGen, started, mins, scanTime)
    end
    Step()
end

local function Read()
    if reading then return end
    if time() - lastFinish < IGNORE_AFTER then
        NPP.Debug("scan: update ignored, read %ds ago", time() - lastFinish)
        return
    end
    local total = C_AuctionHouse.GetNumReplicateItems()
    if not total or total == 0 then return end
    reading = true
    gen = gen + 1
    local myGen, started, scanTime = gen, debugprofilestop(), time()
    local me = UnitName("player")
    local acc, index, own = {}, 0, 0
    NPP.Debug("scan: reading %d listings", total)
    local function Step()
        if myGen ~= gen then return end
        local last = math.min(index + READ_CHUNK, total) - 1
        for i = index, last do
            local _, _, count, _, _, _, _, _, _, buyout, _, _, _, owner, _, _, itemID =
                C_AuctionHouse.GetReplicateItemInfo(i)
            if itemID and buyout and buyout > 0 and count and count > 0 then
                if owner and owner == me then
                    own = own + count
                else
                    local each = math.floor(buyout / count)
                    local levels = acc[itemID]
                    if not levels then
                        levels = {}
                        acc[itemID] = levels
                    end
                    levels[each] = (levels[each] or 0) + count
                end
            end
        end
        index = last + 1
        if index < total then
            Later(Step)
            return
        end
        NPP.Debug("scan: %d of your own items skipped", own)
        Pack(acc, total, myGen, started, scanTime)
    end
    Step()
end

local function Abort()
    if reading then NPP.Print(L("Reading listings stopped: the auction house closed.")) end
    reading = false
    gen = gen + 1
end

local function Parse(s)
    local out = {}
    for price, qty in s:gmatch("(%d+):(%d+)") do
        out[#out + 1] = tonumber(price)
        out[#out + 1] = tonumber(qty)
    end
    return out
end

-- { levels = { price1, qty1, price2, qty2, ... } (cheapest first), total = qty,
--   source = "live" | "scan", time = epoch, full = false when a live search returned only part of the lots }
-- A live search (Live.lua) of an item is used when it is newer than the full scan.
function Scan.Ladder(itemID)
    if not itemID then return end
    local c = parsed[itemID]
    if c == nil then
        c = false
        local house = House()
        if house then
            local liveAt = house.liveTime and house.liveTime[itemID]
            local live = liveAt and house.live and house.live[itemID]
            if live and liveAt >= (house.time or 0) then
                c = { levels = Parse(live), total = house.liveTotal and house.liveTotal[itemID] or 0,
                    source = "live", time = liveAt, full = not (house.livePartial and house.livePartial[itemID]) }
            else
                local s = house.ladders and house.ladders[itemID]
                if s then
                    c = { levels = Parse(s), total = house.totals and house.totals[itemID] or 0,
                        source = "scan", time = house.time, full = true }
                end
            end
        end
        parsed[itemID] = c
    end
    return c or nil
end

-- Lots found by a search on the auction house for one item (Live.lua): unit price -> quantity.
local LIVE_LEVELS = 60
function Scan.StoreLive(itemID, levels, partial)
    local house = House(true)
    house.live, house.liveTime = house.live or {}, house.liveTime or {}
    house.liveTotal, house.livePartial = house.liveTotal or {}, house.livePartial or {}
    local prices, total = {}, 0
    for price, qty in pairs(levels) do
        prices[#prices + 1] = price
        total = total + qty
    end
    table.sort(prices)
    local parts = {}
    for n = 1, math.min(#prices, LIVE_LEVELS) do parts[n] = prices[n] .. ":" .. levels[prices[n]] end
    house.live[itemID] = table.concat(parts, ",")
    house.liveTime[itemID] = time()
    house.liveTotal[itemID] = total
    house.livePartial[itemID] = partial or nil
    parsed[itemID] = nil
    return total, #prices
end

function Scan.Forget(itemID)
    parsed[itemID] = nil
end

-- The price below which pct% of the listed quantity sits: one cheap listing no longer sets it.
function Scan.DepthPrice(itemID, pct)
    local ladder = Scan.Ladder(itemID)
    if not ladder or #ladder.levels == 0 then return end
    local target = math.max(1, math.ceil((ladder.total or 0) * (pct or 10) / 100))
    local lv, sum = ladder.levels, 0
    for i = 1, #lv, 2 do
        sum = sum + lv[i + 1]
        if sum >= target then return lv[i] end
    end
    return lv[#lv - 1]
end

function Scan.Time()
    local house = House()
    return house and house.time
end

function Scan.Count()
    local house = House()
    local n = 0
    if house and house.ladders then
        for _ in pairs(house.ladders) do n = n + 1 end
    end
    return n
end

function Scan.Reading() return reading end

NPP.Module("scan", { "scan" }, function()
    local events = CreateFrame("Frame")
    events:RegisterEvent("AUCTION_HOUSE_SHOW")
    events:RegisterEvent("AUCTION_HOUSE_CLOSED")
    events:SetScript("OnEvent", function(self, event)
        if event == "AUCTION_HOUSE_SHOW" then
            self:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
        elseif event == "AUCTION_HOUSE_CLOSED" then
            self:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
            Abort()
        elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
            if not NPP.Safe("scan", Read) then reading = false end
        end
    end)
end)
