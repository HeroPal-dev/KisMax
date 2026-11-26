-- Shop.lua: our own shopping list, filled from buy plans: the same items and amounts as the plan (bags and your
-- own crafts left out) and, for the auction house, the plan's price limit per unit.
-- Buying on the auction house is done by Naowh's shopping list: on Forever the game blocks the commodity purchase
-- functions for our addon (ADDON_ACTION_BLOCKED on StartCommoditiesPurchase) but lets Naowh's buyer use them.
-- The limit still holds: a commodity purchase always takes the cheapest units first, so we search the lots and hand
-- Naowh only as many units as are listed at or under the limit; Naowh then buys exactly those cheapest units
-- (it shows the total and asks you to confirm; if the lots changed meanwhile, its price will show it).
--   panel at the auction house: "Search" -> per item: units at or under the limit -> "To Naowh: N items"
-- Merchant: "Buy from list" under the merchant window buys the listed merchant items this merchant sells
-- (BuyMerchantItem is not protected). Handing the list to Naowh also hands it the merchant items, so Naowh's
-- "Buy from merchant" window shows our list too; whichever button buys, the other list is counted down
-- (Naowh's merchant purchases reach us through the ledger; ours are reported to Naowh with Shopping.Bought).
-- Every purchase (Naowh's, by hand, at a merchant) counts the list down (Ledger.OnBought).
local _, NPP = ...
local L = NPP.L

local Shop = {}
NPP.Shop = Shop

local ROWS, ROW_H, WIDTH = 12, 18, 420
local GREEN, RED, GREY, GOLD = "|cff4dd17a", "|cffff5555", "|cff999999", "|cffffd100"

local panel, rows, merchantButton
local found = {}     -- [itemID] = { n = units at or under the limit, cost, cheapest, kind } after a search
local searching = false
local announce = false -- the search the auction house opening started: say in chat what can be bought

---------------------------------------------------------------------------------------------------
-- The list
---------------------------------------------------------------------------------------------------

function Shop.Data()
    local db = NPP.db
    if not db then return { items = {}, order = {} } end
    local d = db.shop
    if type(d) ~= "table" then
        d = {}
        db.shop = d
    end
    d.items = d.items or {} -- [itemID] = { ah = units, max = copper per unit, vendor = units, handed = units given to Naowh }
    d.order = d.order or {}
    return d
end

local function Entry(itemID, create)
    local d = Shop.Data()
    local e = d.items[itemID]
    if not e and create then
        e = { ah = 0, vendor = 0 }
        d.items[itemID] = e
        d.order[#d.order + 1] = itemID
    end
    return e
end

local function Wanted(e) return (e.ah or 0) > 0 or (e.vendor or 0) > 0 end

-- Items still to buy, in the order they were added: { { itemID, e }, ... }
function Shop.Entries()
    local d, out, seen, keep = Shop.Data(), {}, {}, {}
    for _, id in ipairs(d.order) do
        local e = d.items[id]
        if e and not seen[id] and Wanted(e) then
            seen[id] = true
            out[#out + 1] = { itemID = id, e = e }
            keep[#keep + 1] = id
        elseif e and not Wanted(e) then
            d.items[id] = nil
        end
    end
    d.order = keep
    return out
end

local function Changed()
    NPP.Safe("shop panel", Shop.Render)
    NPP.Safe("shop merchant", Shop.UpdateMerchant)
end

-- Adds what a plan buys. Returns true when something was added.
function Shop.AddPlan(p)
    local parts = {}
    for _, b in ipairs(p.parts or {}) do
        local ah, vendor = b.ah or 0, b.vendor or 0
        if ah > 0 or vendor > 0 then
            local e = Entry(b.itemID, true)
            e.ah, e.vendor = (e.ah or 0) + ah, (e.vendor or 0) + vendor
            if ah > 0 and b.ahMax then e.max = math.max(e.max or 0, b.ahMax) end
            found[b.itemID] = nil
            local bits = {}
            if ah > 0 then bits[#bits + 1] = L("AH %d up to %s"):format(ah, NPP.Coins(b.ahMax)) end
            if vendor > 0 then bits[#bits + 1] = L("merchant %d"):format(vendor) end
            parts[#parts + 1] = ("%s (%s)"):format(NPP.Profit.ItemName(b.itemID), table.concat(bits, ", "))
        end
    end
    if #parts == 0 then
        NPP.Print(L("Nothing to buy: everything is in your bags or crafted."))
        return false
    end
    NPP.Print(L("Shopping list: added %s."), table.concat(parts, "; "))
    Changed()
    return true
end

function Shop.Remove(itemID)
    Shop.Data().items[itemID] = nil
    found[itemID] = nil
    Changed()
end

function Shop.Clear()
    local d = Shop.Data()
    wipe(d.items)
    wipe(d.order)
    wipe(found)
    Changed()
end

-- Any purchase counts the list down: first the channel it was bought on, then the other one.
local function OnBought(itemID, qty, _, where)
    local e = Entry(itemID)
    if not e then return end
    local first, second = "ah", "vendor"
    if where ~= "ah" then first, second = "vendor", "ah" end
    local take = math.min(qty, e[first] or 0)
    e[first] = (e[first] or 0) - take
    if where == "ah" and e.handed then e.handed = math.max(0, e.handed - take) end
    if where ~= "ah" and e.handedVendor then e.handedVendor = math.max(0, e.handedVendor - take) end
    qty = qty - take
    if qty > 0 then e[second] = math.max(0, (e[second] or 0) - qty) end
    local f = found[itemID]
    if f and where == "ah" then f.n = math.max(0, f.n - take) end
    Changed()
end

---------------------------------------------------------------------------------------------------
-- Auction house: search, then hand Naowh the units at or under the limit
---------------------------------------------------------------------------------------------------

local function HouseOpen() return NPP.Live and NPP.Live.Open() end

local function NaowhShopping()
    local S = NPP.P and NPP.P.Shopping
    if S and type(S.AddItem) == "function" then return S end
end

-- Units listed at or under the limit, what those cheapest units cost, and the cheapest price.
local function Affordable(itemID, want, max)
    local ladder = NPP.Scan.Ladder(itemID)
    if not ladder then return 0, 0 end
    local lv = {}
    for i = 1, #ladder.levels, 2 do lv[#lv + 1] = { ladder.levels[i], ladder.levels[i + 1] } end
    table.sort(lv, function(a, b) return a[1] < b[1] end)
    local n, cost = 0, 0
    for _, l in ipairs(lv) do
        if n >= want or (max and l[1] > max) then break end
        local take = math.min(l[2], want - n)
        n, cost = n + take, cost + take * l[1]
    end
    return n, cost, lv[1] and lv[1][1]
end

local function AuctionItems()
    local out = {}
    for _, x in ipairs(Shop.Entries()) do
        local left = (x.e.ah or 0) - (x.e.handed or 0)
        if left > 0 then out[#out + 1] = { itemID = x.itemID, e = x.e, left = left } end
    end
    return out
end

-- Merchant units of the list not handed to Naowh yet: { { itemID, e, left } }
local function VendorItems()
    local out = {}
    for _, x in ipairs(Shop.Entries()) do
        local left = (x.e.vendor or 0) - (x.e.handedVendor or 0)
        if left > 0 then out[#out + 1] = { itemID = x.itemID, e = x.e, left = left } end
    end
    return out
end

-- Hands the merchant part to Naowh; returns the chat parts.
local function HandVendor(S, parts)
    for _, x in ipairs(VendorItems()) do
        local ok, err = pcall(S.AddItem, x.itemID, x.left)
        if not ok then
            NPP.Report("shop to naowh", err)
            return parts
        end
        x.e.handedVendor = (x.e.handedVendor or 0) + x.left
        parts[#parts + 1] = L("%dx %s (merchant)"):format(x.left, NPP.Profit.ItemName(x.itemID))
    end
    return parts
end

local function AfterSearch()
    searching = false
    local lines, total = {}, 0
    for _, x in ipairs(AuctionItems()) do
        local n, cost, cheapest = Affordable(x.itemID, x.left, x.e.max)
        found[x.itemID] = { n = n, cost = cost, cheapest = cheapest, kind = NPP.Live.Kind(x.itemID) }
        if n > 0 then
            lines[#lines + 1] = L("%s: %d of %d at or under the limit (%s)"):format(NPP.Profit.ItemName(x.itemID), n, x.left, NPP.Coins(cost))
            total = total + cost
        end
    end
    if announce then
        announce = false
        if #lines > 0 then
            NPP.Print(L("Shopping list: can be bought now for about %s:"), NPP.Coins(total))
            for _, line in ipairs(lines) do NPP.Print("  %s", line) end
        else
            NPP.Print(L("Shopping list: everything is dearer than its limit right now."))
        end
    end
    Changed()
end

function Shop.Search(say)
    if not HouseOpen() then return NPP.Print(L("Open the auction house first: lots can be read only there.")) end
    if NPP.Live.Busy() then return NPP.Print(L("Lots are being refreshed already.")) end
    local ids, need = {}, {}
    for _, x in ipairs(AuctionItems()) do
        ids[#ids + 1] = x.itemID
        need[x.itemID] = x.left
    end
    if #ids == 0 then return Changed() end
    searching = true
    announce = say and true or false
    wipe(found)
    Changed()
    if not NPP.Live.Refresh(ids, need, { quiet = true, onDone = function() NPP.Safe("shop search", AfterSearch) end }) then
        searching = false
        Changed()
    end
end

-- What a search allows: { { itemID, n, cost } } for commodities with units at or under the limit.
local function Ready()
    local out, total = {}, 0
    for _, x in ipairs(AuctionItems()) do
        local f = found[x.itemID]
        if f and f.n > 0 and f.kind ~= "item" then
            out[#out + 1] = { itemID = x.itemID, n = math.min(f.n, x.left), cost = f.cost }
            total = total + f.cost
        end
    end
    return out, total
end

function Shop.HandToNaowh()
    local S = NaowhShopping()
    if not S then return NPP.Print(L("Naowh's shopping list is not available.")) end
    local ready, total = Ready()
    if #ready == 0 and #VendorItems() == 0 then
        return NPP.Print(L("Nothing at or under the limits right now: search again later."))
    end
    local parts = {}
    for _, r in ipairs(ready) do
        local ok, err = pcall(S.AddItem, r.itemID, r.n)
        if not ok then return NPP.Report("shop to naowh", err) end
        local e = Entry(r.itemID)
        if e then e.handed = (e.handed or 0) + r.n end
        found[r.itemID] = nil
        parts[#parts + 1] = ("%dx %s"):format(r.n, NPP.Profit.ItemName(r.itemID))
    end
    HandVendor(S, parts)
    NPP.Print(L("Given to Naowh's shopping list: %s (about %s). In Naowh's list: Check prices, then Buy."),
        table.concat(parts, ", "), NPP.Coins(total))
    Changed()
end

-- Everything left on the auction house part, without a limit check (when you want to buy anyway).
function Shop.ToNaowh()
    local S = NaowhShopping()
    if not S then return NPP.Print(L("Naowh's shopping list is not available.")) end
    local parts = {}
    for _, x in ipairs(AuctionItems()) do
        local ok, err = pcall(S.AddItem, x.itemID, x.left)
        if not ok then return NPP.Report("shop to naowh", err) end
        x.e.handed = (x.e.handed or 0) + x.left
        parts[#parts + 1] = ("%dx %s"):format(x.left, NPP.Profit.ItemName(x.itemID))
    end
    HandVendor(S, parts)
    if #parts == 0 then return NPP.Print(L("Nothing to buy: everything is in your bags or crafted.")) end
    NPP.Print(L("Passed to Naowh's shopping list: %s. Naowh does not know the price limits."), table.concat(parts, ", "))
    Changed()
end

---------------------------------------------------------------------------------------------------
-- Auction house panel
---------------------------------------------------------------------------------------------------

local function Font(parent, size)
    local ns = NPP.ns
    if ns and type(ns.Font) == "function" then return ns.Font(parent, size) end
    return parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
end

local function Button(parent, text, w, h, onClick)
    local ns = NPP.ns
    if ns and type(ns.Button) == "function" then return ns.Button(parent, text, w, h, onClick) end
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function SetEnabled(b, on)
    if b.SetEnabled then b:SetEnabled(on) end
    b:SetAlpha(on and 1 or 0.45)
end

local function SetLabel(b, text)
    if NPP.SetButtonText then NPP.SetButtonText(b, text) else b:SetText(text) end
end

local function Place()
    panel:ClearAllPoints()
    local pos = NPP.db and NPP.db.shopPos
    if type(pos) == "table" and pos[1] then
        panel:SetPoint(pos[1], UIParent, pos[1], pos[2] or 0, pos[3] or 0)
    elseif _G.AuctionHouseFrame then
        panel:SetPoint("TOPLEFT", _G.AuctionHouseFrame, "TOPRIGHT", 6, 0)
    else
        panel:SetPoint("CENTER")
    end
end

local function Tip(b, title, text)
    b:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title, 1, 1, 1)
        GameTooltip:AddLine(text, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", GameTooltip_Hide)
end

local function Build()
    panel = CreateFrame("Frame", "KisMaxShop", UIParent)
    panel:SetSize(WIDTH, 120)
    panel:SetFrameStrata("HIGH")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetClampedToScreen(true)
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint(1)
        if NPP.db then NPP.db.shopPos = { point, x, y } end
    end)
    local ns, T = NPP.ns, NPP.ns and NPP.ns.THEME
    if ns and ns.Solid and T then
        ns.Solid(panel, "BACKGROUND", T.bg, 0.95):SetAllPoints()
        if ns.Border then ns.Border(panel, T.line) end
    else
        local bg = panel:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.9)
    end
    panel.title = Font(panel, 13)
    panel.title:SetPoint("TOPLEFT", 8, -8)
    panel.title:SetText(GOLD .. L("KM shopping list") .. "|r")
    panel.close = Button(panel, "X", 22, 20, function() panel:Hide() end)
    panel.close:SetPoint("TOPRIGHT", -6, -6)
    panel.clear = Button(panel, L("Clear"), 80, 20, function() Shop.Clear() end)
    panel.clear:SetPoint("RIGHT", panel.close, "LEFT", -4, 0)

    local head = Font(panel, 11)
    head:SetPoint("TOPLEFT", 8, -32)
    head:SetText(GREY .. L("Item") .. "|r")
    local headR = Font(panel, 11)
    headR:SetPoint("TOPRIGHT", -8, -32)
    headR:SetText(GREY .. L("need / at or under the limit now") .. "|r")

    rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, panel)
        r:SetSize(WIDTH - 16, ROW_H)
        r:SetPoint("TOPLEFT", 8, -48 - (i - 1) * ROW_H)
        r:RegisterForClicks("RightButtonUp")
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        r.name = Font(r, 12)
        r.name:SetPoint("LEFT", 0, 0)
        r.name:SetWidth(WIDTH - 230)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.right = Font(r, 12)
        r.right:SetPoint("RIGHT", 0, 0)
        r.right:SetJustifyH("RIGHT")
        r:SetScript("OnClick", function(self) if self.itemID then Shop.Remove(self.itemID) end end)
        r:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.itemID then
                local e = Entry(self.itemID)
                GameTooltip:AddLine(NPP.Profit.ItemName(self.itemID), 1, 1, 1)
                if e and (e.ah or 0) > 0 then
                    GameTooltip:AddLine(L("Auction: %d, limit %s each"):format(e.ah, NPP.Coins(e.max)), 0.8, 0.8, 0.8)
                    if (e.handed or 0) > 0 then GameTooltip:AddLine(L("Given to Naowh: %d"):format(e.handed), 0.8, 0.8, 0.8) end
                end
                if e and (e.vendor or 0) > 0 then GameTooltip:AddLine(L("merchant %d"):format(e.vendor), 0.8, 0.8, 0.8) end
            end
            GameTooltip:AddLine(L("Right-click: remove from the list"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", GameTooltip_Hide)
        rows[i] = r
    end
    panel.status = Font(panel, 12)
    panel.status:SetJustifyH("LEFT")
    panel.status:SetWordWrap(true)
    panel.search = Button(panel, L("Search"), 110, 24, function() NPP.Safe("shop search", Shop.Search) end)
    Tip(panel.search, L("Search"), L("Fresh lots of every auction item on the list: how many are listed at or under the plan's limit."))
    panel.hand = Button(panel, L("To Naowh"), 200, 24, function() NPP.Safe("shop to naowh", Shop.HandToNaowh) end)
    Tip(panel.hand, L("To Naowh"), L("HAND_HELP"))
    panel.all = Button(panel, L("All, no limit"), 110, 24, function() NPP.Safe("shop to naowh", Shop.ToNaowh) end)
    Tip(panel.all, L("All, no limit"), L("Adds this list to Naowh's shopping list, to buy with Naowh's buttons. Naowh does not check the price limits."))
    panel:Hide()
end

local function RowRight(x)
    local e, f = x.e, found[x.itemID]
    local bits = {}
    local left = (e.ah or 0) - (e.handed or 0)
    if (e.ah or 0) > 0 then
        local text = L("%d up to %s"):format(e.ah, NPP.Coins(e.max))
        if (e.handed or 0) > 0 then text = text .. GREY .. L(" (Naowh %d)"):format(e.handed) .. "|r" end
        if left > 0 and f then
            if f.kind == "item" then
                text = text .. RED .. L(" - not a trade good") .. "|r"
            elseif f.n >= left then
                text = text .. GREEN .. L(" - all %d"):format(f.n) .. "|r"
            elseif f.n > 0 then
                text = text .. GOLD .. L(" - only %d"):format(f.n) .. "|r"
            else
                text = text .. RED .. L(" - none (from %s)"):format(NPP.Coins(f.cheapest)) .. "|r"
            end
        end
        bits[#bits + 1] = text
    end
    if (e.vendor or 0) > 0 then bits[#bits + 1] = GREY .. L("merchant %d"):format(e.vendor) .. "|r" end
    return table.concat(bits, "  ")
end

function Shop.Render()
    if not (panel and panel:IsShown()) then return end
    local list = Shop.Entries()
    local y = 48
    for i, r in ipairs(rows) do
        local x = list[i]
        if x then
            r.itemID = x.itemID
            r.name:SetText(NPP.Profit.ItemName(x.itemID))
            r.right:SetText(RowRight(x))
            r:Show()
            y = y + ROW_H
        else
            r.itemID = nil
            r:Hide()
        end
    end
    if #list == 0 then
        rows[1].name:SetText(GREY .. L("Empty: press To shopping list on the Buy plan panel.") .. "|r")
        rows[1].right:SetText("")
        rows[1]:Show()
        y = y + ROW_H
    end
    local ready, total = Ready()
    local items = AuctionItems()
    local text
    if searching then
        text = L("Searching lots...")
    elseif #items == 0 then
        local vendor = 0
        for _, x in ipairs(list) do vendor = vendor + (x.e.vendor or 0) end
        text = vendor > 0 and (GREEN .. L("Auction part done. Merchant items left: %d."):format(vendor) .. "|r")
            or (GREEN .. L("Nothing left to buy on the auction house.") .. "|r")
    elseif not next(found) then
        text = L("Press Search: how many units are listed at or under each limit right now.")
    elseif #ready > 0 then
        text = L("At or under the limits now: %d items, about %s. Give them to Naowh and buy them there.")
            :format(#ready, NPP.Coins(total))
    else
        text = RED .. L("Nothing at or under the limits right now: search again later.") .. "|r"
    end
    panel.status:ClearAllPoints()
    panel.status:SetPoint("TOPLEFT", 8, -(y + 6))
    panel.status:SetPoint("RIGHT", -8, 0)
    panel.status:SetText(text)
    y = y + 6 + panel.status:GetStringHeight() + 6
    panel.search:ClearAllPoints()
    panel.search:SetPoint("TOPLEFT", 8, -y)
    panel.hand:ClearAllPoints()
    panel.hand:SetPoint("LEFT", panel.search, "RIGHT", 6, 0)
    panel.all:ClearAllPoints()
    panel.all:SetPoint("LEFT", panel.hand, "RIGHT", 6, 0)
    SetLabel(panel.hand, #ready > 0 and L("To Naowh: %d items"):format(#ready) or L("To Naowh"))
    NPP.FitButton(panel.search, 90)
    NPP.FitButton(panel.hand, 110)
    NPP.FitButton(panel.all, 90)
    NPP.FitButton(panel.clear, 70)
    local naowh = NaowhShopping() ~= nil
    SetEnabled(panel.search, HouseOpen() and not searching and #items > 0 and true or false)
    SetEnabled(panel.hand, naowh and (#ready > 0 or #VendorItems() > 0))
    SetEnabled(panel.all, naowh and #items > 0)
    panel:SetHeight(y + 24 + 10)
end

-- force: show even with an empty list (/km shop)
function Shop.ShowPanel(force)
    if not panel then Build() end
    if not force and #Shop.Entries() == 0 then return end
    Place()
    panel:Show()
    Shop.Render()
end

function Shop.TogglePanel()
    if panel and panel:IsShown() then panel:Hide() else Shop.ShowPanel(true) end
end

---------------------------------------------------------------------------------------------------
-- Merchant
---------------------------------------------------------------------------------------------------

local function MerchantInfo(i)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local info = C_MerchantFrame.GetItemInfo(i)
        if info then return info.price, info.stackCount, info.numAvailable, info.hasExtendedCost end
        return
    end
    local _, _, price, stack, available, _, _, extended = GetMerchantItemInfo(i)
    return price, stack, available, extended
end

-- What of the list this merchant sells: { { index, itemID, qty, cost } }, units, cost.
local function MerchantOffer()
    local out, units, total = {}, 0, 0
    if not (GetMerchantNumItems and GetMerchantItemID) then return out, 0, 0 end
    for i = 1, GetMerchantNumItems() or 0 do
        local id = GetMerchantItemID(i)
        local e = id and Entry(id)
        if e and (e.vendor or 0) > 0 then
            local price, stack, available, extended = MerchantInfo(i)
            if price and price > 0 and not extended then
                local qty = e.vendor
                if available and available >= 0 then qty = math.min(qty, available * math.max(1, stack or 1)) end
                if qty > 0 then
                    local cost = math.floor(price / math.max(1, stack or 1) * qty + 0.5)
                    out[#out + 1] = { index = i, itemID = id, qty = qty, cost = cost }
                    units, total = units + qty, total + cost
                end
            end
        end
    end
    return out, units, total
end

local function BuyFromMerchant()
    if InCombatLockdown() then return end
    local offer, _, total = MerchantOffer()
    if #offer == 0 then return NPP.Print(L("This merchant sells nothing from the list.")) end
    if GetMoney() < total then return NPP.Print(L("Not enough money for this purchase.")) end
    local S = NaowhShopping()
    for _, o in ipairs(offer) do
        local e = Entry(o.itemID)
        local held = e and math.min(o.qty, e.handedVendor or 0) or 0 -- units Naowh's list holds for us
        local left = o.qty
        local most = math.max(1, (GetMerchantItemMaxStack and GetMerchantItemMaxStack(o.index)) or left)
        while left > 0 do
            local n = math.min(left, most)
            BuyMerchantItem(o.index, n)
            left = left - n
        end
        if held > 0 and S and type(S.Bought) == "function" then
            local ok, err = pcall(S.Bought, o.itemID, held)
            if not ok then NPP.Report("shop naowh bought", err) end
        end
    end
    NPP.Print(L("Bought from the merchant for about %s."), NPP.Coins(total))
end

function Shop.UpdateMerchant()
    local b = merchantButton
    if not (b and b:IsShown()) then return end
    local _, units, total = MerchantOffer()
    SetLabel(b, units > 0 and L("Buy from list: %d (%s)"):format(units, NPP.Coins(total)) or L("Buy from list: nothing here"))
    local label = b.label or b:GetFontString()
    local w = label and label.GetStringWidth and label:GetStringWidth()
    if w and w > 0 then b:SetWidth(math.max(140, w + 24)) end
    SetEnabled(b, units > 0)
end

local function BuildMerchantButton()
    local frame = _G.MerchantFrame
    merchantButton = Button(frame, L("Buy from list"), 160, 24, function() NPP.Safe("shop merchant buy", BuyFromMerchant) end)
    local sell = NPP.Sell and NPP.Sell.Button and NPP.Sell.Button()
    if sell then
        merchantButton:SetPoint("LEFT", sell, "RIGHT", 6, 0)
    elseif _G.MerchantFrameTab2 then
        merchantButton:SetPoint("LEFT", _G.MerchantFrameTab2, "RIGHT", 8, 0)
    else
        merchantButton:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -4)
    end
    merchantButton:SetFrameLevel(frame:GetFrameLevel() + 10)
    merchantButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L("Buy from list"), 1, 1, 1)
        for _, o in ipairs((MerchantOffer())) do
            GameTooltip:AddDoubleLine(("%s x%d"):format(NPP.Profit.ItemName(o.itemID), o.qty), NPP.Coins(o.cost), 1, 1, 1, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    merchantButton:HookScript("OnLeave", GameTooltip_Hide)
    merchantButton:HookScript("OnShow", function() NPP.Safe("shop merchant", Shop.UpdateMerchant) end)
end

NPP.Module("shop", { "core" }, function()
    Shop.Data()
    if NPP.Ledger and NPP.Ledger.OnBought then NPP.Ledger.OnBought(OnBought) end
    local events = CreateFrame("Frame")
    for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "MERCHANT_SHOW", "MERCHANT_UPDATE" }) do
        pcall(events.RegisterEvent, events, e)
    end
    events:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_SHOW" then
            if not merchantButton and _G.MerchantFrame then NPP.Safe("shop merchant button", BuildMerchantButton) end
            NPP.Safe("shop merchant", Shop.UpdateMerchant)
        elseif event == "MERCHANT_UPDATE" then
            NPP.Safe("shop merchant", Shop.UpdateMerchant)
        elseif event == "AUCTION_HOUSE_SHOW" then
            NPP.Safe("shop panel", Shop.ShowPanel, false)
            -- check the list on its own a moment after the auction house opens
            if NPP.Get("autoShopCheck") and #AuctionItems() > 0 then
                C_Timer.After(2, function()
                    if HouseOpen() and not searching and not NPP.Live.Busy() then NPP.Safe("shop auto check", Shop.Search, true) end
                end)
            end
        elseif event == "AUCTION_HOUSE_CLOSED" then
            searching = false
            wipe(found)
            if panel then panel:Hide() end
        end
    end)
end)
