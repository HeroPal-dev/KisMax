-- Session.lua: "Session plan" - what to craft for the best result with your money and bag space, over several
-- recipes at once (100 of one food and 100 of another, when that pays more than 200 of one).
-- Candidates: learned recipes of the open profession that make a profit at today's prices (Profit.Get), the best
-- MAX_CANDIDATES by profit per hour, so not every recipe is counted again.
-- They share one supply of every reagent (bags, auction lots cheapest first, merchant), the money (budget) and the
-- bag slots. One craft at a time is added: the one that gives the most profit per second of crafting right now
-- (its next lots may be dearer than its first). A recipe stops at its own limits too: planMax, TSM demand for
-- auction sales, no profitable next craft, lots used up. Counted in steps so the game does not freeze.
-- Then: "To shopping list" (what the whole session buys, with the price limits) and "To craft queue" (Naowh's
-- crafting queue: it crafts a batch per click and adds intermediate crafts, e.g. cured hide, itself).
-- Buy first, queue after: Naowh's queue asks its own shopping list for what is missing from your bags.
local _, NPP = ...
local L = NPP.L

local Session = {}
NPP.Session = Session

local MAX_CANDIDATES = 15
local MAX_CRAFTS = 1000
local PER_STEP = 20
local ROWS, ROW_H = 15, 20
local COLS = {
    { title = "Recipe", w = 230, align = "LEFT", max = 320 },
    { title = "Crafts", w = 60, align = "RIGHT" },
    { title = "Profit", w = 100, align = "RIGHT" },
    { title = "Per hour", w = 95, align = "RIGHT" },
    { title = "Time", w = 75, align = "RIGHT" },
}
local PAD = 10
local LIST_W = 0
for _, c in ipairs(COLS) do LIST_W = LIST_W + c.w end
local WIDTH = PAD * 2 + LIST_W
local GREEN, RED, GREY, GOLD = "|cff4dd17a", "|cffff5555", "|cff999999", "|cffffd100"

local frame, rows, info, buttons, heads
local result -- { cands, totals, state, limits } of the last count
local job

---------------------------------------------------------------------------------------------------
-- Counting
---------------------------------------------------------------------------------------------------

local function I() return NPP.Plan.internal end

-- Items a candidate takes from: its reagents and its intermediates' reagents.
local function ItemsOf(v)
    local ids, seen = {}, {}
    local function Add(id)
        if id and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    for _, part in ipairs(v.parts) do
        if not part.owned then
            Add(part.itemID)
            if part.maker then
                for _, sub in ipairs(part.maker.parts) do
                    if not sub.owned then Add(sub.itemID) end
                end
            end
        end
    end
    return ids
end

local function Save(state, ids)
    local snap = {}
    for _, id in ipairs(ids) do
        local s = state[id]
        if s then snap[id] = { s.at, s.used, s.taken, s.spare, s.subCrafts } end
    end
    return snap
end

local function Load(state, snap)
    for id, t in pairs(snap) do
        local s = state[id]
        s.at, s.used, s.taken, s.spare, s.subCrafts = t[1], t[2], t[3], t[4], t[5]
    end
end

-- One craft of a candidate from the shared supplies: cost, cash, extra seconds, or nil, why.
local function TakeOne(c, Get)
    local P = I()
    local cost, cash, secs = 0, 0, 0
    for _, part in ipairs(c.v.parts) do
        if not part.owned then
            local x, m, t
            if part.maker then
                x, m, t = P.TakeIntermediate(part, part.need, c.v.rate or 0, Get)
            else
                x, m = P.TakeFrom(Get(part.itemID), part.need)
            end
            if not x then return nil, m end
            cost, cash, secs = cost + x, cash + m, secs + (t or 0)
        end
    end
    return cost, cash, secs
end

local function Candidates()
    local list = {}
    local W = NPP.P.State
    if W.linked or not C_TradeSkillUI.GetAllRecipeIDs then return list end
    local cap = math.max(1, tonumber(NPP.Get("planMax")) or 200)
    for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
        local ri = C_TradeSkillUI.GetRecipeInfo(id)
        if ri and ri.learned then
            local ok, v = pcall(NPP.Profit.Get, id)
            if ok and v and v.profit and v.profit > 0 and v.unitSale and v.missing == 0 and #v.parts > 0 then
                local c = { id = id, v = v, name = ri.name or tostring(id), info = ri, count = 0, cost = 0, sale = 0,
                    secs = 0, cash = 0, perCraft = v.unitSale * v.made, base = NPP.Profit.CraftSeconds(id), cap = cap }
                if v.channel == "ah" and NPP.Get("limitByDemand") then
                    local sold = NPP.PriceSource.SoldPerDay(v.output)
                    if sold then
                        local byDemand = math.floor(sold * (tonumber(NPP.Get("demandDays")) or 1) / math.max(v.made, 1))
                        if byDemand < c.cap then c.cap, c.demandCap = byDemand, true end
                    end
                end
                -- a recipe on a cooldown (transmutes): one craft, and only when it is ready now
                local cd, left = NPP.RecipeCooldown(id)
                if cd then c.cap, c.cooldown = (left > 0) and 0 or 1, true end
                c.hour = v.profit / math.max(v.seconds or c.base, 0.1)
                if c.cap > 0 then list[#list + 1] = c end
            end
        end
    end
    table.sort(list, function(a, b) return a.hour > b.hour end)
    for i = #list, MAX_CANDIDATES + 1, -1 do list[i] = nil end
    return list
end

-- Slots the whole session needs at its fullest: new stacks bought, or the results crafted.
local function Slots(r)
    local P = I()
    local buy = 0
    for id, s in pairs(r.state) do buy = buy + P.NewStacks(s.have, math.max(0, s.taken - s.have), P.StackSize(id)) end
    local made = 0
    for _, c in ipairs(r.cands) do
        if c.count > 0 and c.v.output then
            made = made + P.NewStacks(c.outHave or 0, math.ceil(c.count * c.v.made), P.StackSize(c.v.output))
        end
    end
    return math.max(buy, made), buy, made
end

local Render

local function Finish(r)
    job = nil
    local t = r.totals
    t.profit = math.floor(t.sale - t.cost)
    t.perHour = t.secs > 0 and math.floor(t.profit * 3600 / t.secs) or nil
    t.slots, t.slotsBuy, t.slotsMade = Slots(r)
    NPP.Debug("session: %d crafts, profit %s", t.crafts, t.profit)
    Render()
end

local function Step()
    local r = job
    if not r then return end
    local P = I()
    local budget, minProfit, free = r.budget, NPP.Get("minProfit"), r.free
    local t = r.totals
    for _ = 1, PER_STEP do
        if t.crafts >= MAX_CRAFTS then return Finish(r) end
        local best, bestScore, bestMargin
        for _, c in ipairs(r.cands) do
            if not c.blocked then
                if c.count >= c.cap then
                    c.blocked = c.demandCap and "demand" or "cap"
                else
                    local snap = Save(r.state, c.items)
                    local cost, cash, secs = TakeOne(c, r.Get)
                    Load(r.state, snap)
                    if not cost then
                        c.blocked = cash == "partial" and "partial" or "supply"
                    else
                        local margin = c.perCraft - cost
                        if margin <= 0 or (minProfit ~= false and margin < minProfit) then
                            c.blocked = "profit"
                        elseif budget and t.cash + cash > budget then
                            c.blocked = "money"
                        else
                            local score = margin / (c.base + secs)
                            if not bestScore or score > bestScore then best, bestScore, bestMargin = c, score, margin end
                        end
                    end
                end
            end
        end
        if not best then return Finish(r) end
        local snap = Save(r.state, best.items)
        local cost, cash, secs = TakeOne(best, r.Get)
        best.count = best.count + 1
        if free and Slots(r) > free then
            best.count = best.count - 1
            Load(r.state, snap)
            best.blocked = "bags"
        else
            best.cost, best.sale, best.cash = best.cost + cost, best.sale + best.perCraft, best.cash + cash
            best.secs = best.secs + best.base + secs
            t.cost, t.sale, t.cash, t.secs, t.crafts = t.cost + cost, t.sale + best.perCraft, t.cash + cash,
                t.secs + best.base + secs, t.crafts + 1
            best.lastMargin = bestMargin
        end
    end
    Render()
    C_Timer.After(0, function() if job == r then NPP.Safe("session", Step) end end)
end

function Session.Count()
    if not NPP.P.State.frame or not NPP.P.State.frame:IsShown() then
        return NPP.Print(L("Open a profession first: the session uses its learned recipes."))
    end
    if NPP.P.State.linked then return NPP.Print(L("This is someone else's profession: open your own.")) end
    local P = I()
    local r = { cands = Candidates(), totals = { cost = 0, sale = 0, cash = 0, secs = 0, crafts = 0 } }
    local p = {}
    r.state, r.Get = P.NewState(p)
    r.p = p
    for _, c in ipairs(r.cands) do
        c.items = ItemsOf(c.v)
        for _, part in ipairs(c.v.parts) do
            if not part.owned then
                local s = r.Get(part.itemID)
                if part.maker then
                    s.made = part.maker.made
                    for _, sub in ipairs(part.maker.parts) do
                        if not sub.owned then r.Get(sub.itemID) end
                    end
                end
            end
        end
        if c.v.output then
            local ok, n = pcall(NPP.P.Recipes.ItemCount, c.v.output)
            c.outHave = ok and tonumber(n) or 0
        end
    end
    r.budget = NPP.Plan.Budget()
    r.free = NPP.Get("limitByBags") and NPP.Plan.FreeSlots() or nil
    result, job = r, r
    Session.Open(true)
    NPP.Safe("session", Step)
end

---------------------------------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------------------------------

local function Chosen()
    local out = {}
    for _, c in ipairs(result and result.cands or {}) do
        if c.count > 0 then out[#out + 1] = c end
    end
    table.sort(out, function(a, b) return (a.sale - a.cost) > (b.sale - b.cost) end)
    return out
end

function Session.ToShopping()
    if not (result and not job) then return end
    local P = I()
    local parts = {}
    for id, s in pairs(result.state) do
        if s.taken > 0 then
            local b = P.Breakdown(s.levels, s.taken)
            b.itemID = id
            parts[#parts + 1] = b
        end
    end
    local p = { parts = parts }
    if NPP.Shop and NPP.Started("shop") and NPP.Get("shopTarget") ~= "naowh" then
        if NPP.Shop.AddPlan(p) and NPP.Live and NPP.Live.Open() then NPP.Shop.ShowPanel(true) end
    else
        local S = NPP.P.Shopping
        if not (S and type(S.AddItem) == "function") then return NPP.Print(L("Naowh's shopping list is not available.")) end
        for _, b in ipairs(parts) do
            local n = (b.ah or 0) + (b.vendor or 0)
            if n > 0 then pcall(S.AddItem, b.itemID, n) end
        end
        NPP.Print(L("Passed to Naowh's shopping list: %s. Naowh does not know the price limits."), L("session"))
    end
end

local function BagCount(itemID)
    local ok, n = pcall(NPP.P.Recipes.ItemCount, itemID)
    if ok and tonumber(n) then return tonumber(n) end
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(itemID) or 0 end
    return 0
end

-- How many crafts of each chosen recipe the bags allow now, sharing the reagents in the session's order.
-- An intermediate (e.g. cured hide) counts as there when its own reagents are in the bags.
local function Craftable(chosen)
    local left = {}
    local function Have(id)
        if left[id] == nil then left[id] = BagCount(id) end
        return left[id]
    end
    local out = {}
    for _, c in ipairs(chosen) do
        local n = c.count
        for _, part in ipairs(c.v.parts) do
            if not part.owned then
                local avail = Have(part.itemID)
                local m = part.maker
                if m then
                    local subs = math.huge
                    for _, sub in ipairs(m.parts) do
                        if not sub.owned then subs = math.min(subs, math.floor(Have(sub.itemID) / sub.need)) end
                    end
                    if subs < math.huge then avail = avail + subs * m.made end
                end
                n = math.min(n, math.floor(avail / part.need))
            end
        end
        n = math.max(0, n)
        -- take what these crafts use
        for _, part in ipairs(c.v.parts) do
            if not part.owned then
                local want = n * part.need
                local fromBags = math.min(want, Have(part.itemID))
                left[part.itemID] = Have(part.itemID) - fromBags
                local rest = want - fromBags
                if rest > 0 and part.maker then
                    local crafts = math.ceil(rest / part.maker.made)
                    for _, sub in ipairs(part.maker.parts) do
                        if not sub.owned then left[sub.itemID] = Have(sub.itemID) - crafts * sub.need end
                    end
                end
            end
        end
        out[c] = n
    end
    return out
end

-- Sets each chosen recipe in Naowh's crafting queue to the crafts its materials in the bags allow (pressing again
-- after buying the rest raises it; pressing twice does not add twice). Naowh's queue puts what a queued craft
-- misses on its own shopping list, so nothing is queued before its materials are bought.
function Session.ToQueue()
    if not (result and not job) then return end
    local Q = NPP.P.CraftQueue
    if not (Q and type(Q.Add) == "function") then return NPP.Print(L("Naowh's crafting queue is not available.")) end
    local chosen = Chosen()
    if #chosen == 0 then return NPP.Print(L("The session has no crafts.")) end
    local can = Craftable(chosen)
    local mine = type(Q.List) == "function" and Q.List() or nil
    local bits, short = {}, {}
    for _, c in ipairs(chosen) do
        local target = can[c] or 0
        local entry = mine and mine.crafts and mine.crafts[c.id]
        local have = entry and tonumber(entry.count) or 0
        local ok, err = true, nil
        if target > 0 and have == 0 then
            local ri = C_TradeSkillUI.GetRecipeInfo(c.id) or c.info
            ok, err = pcall(Q.Add, ri, target, nil, false)
        elseif target > 0 and have ~= target and type(Q.Step) == "function" then
            ok, err = pcall(Q.Step, c.id, nil, target - have)
        elseif target == 0 and have > 0 and type(Q.Remove) == "function" then
            ok, err = pcall(Q.Remove, c.id, nil)
        end
        if not ok then return NPP.Report("session queue", err) end
        if target > 0 then bits[#bits + 1] = ("%dx %s"):format(target, c.name) end
        if target < c.count then short[#short + 1] = ("%s %d/%d"):format(c.name, target, c.count) end
    end
    if #bits > 0 then
        NPP.Print(L("Crafting queue now: %s. In the queue window: Start Queue, then Craft Next for each batch."), table.concat(bits, ", "))
        if NPP.ns and type(NPP.ns.OpenCraftQueue) == "function" then pcall(NPP.ns.OpenCraftQueue) end
    end
    if #short > 0 then
        NPP.Print(L("Not all is in your bags yet (%s): buy the rest from the shopping list, then press To craft queue again."),
            table.concat(short, ", "))
    end
end

---------------------------------------------------------------------------------------------------
-- Window
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

local function Tip(b, title, text)
    b:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title, 1, 1, 1)
        GameTooltip:AddLine(text, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", GameTooltip_Hide)
end

local WHY = {
    cap = "plan limit (/km planmax)", demand = "demand (TSM sold per day)", supply = "reagents on sale run out",
    partial = "only part of the lots is loaded (refresh lots again)", profit = "next craft would not pay",
    money = "not enough money", bags = "not enough bag space",
}

local function RowTooltip(self)
    local c = self.c
    if not c then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(c.name, 1, 1, 1)
    GameTooltip:AddDoubleLine(L("Crafts"), tostring(c.count), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L("Sale"), NPP.Coins(c.sale), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L("Reagents"), NPP.Coins(c.cost), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L("Pay"), NPP.Coins(c.cash), 1, 1, 1, 1, 1, 1)
    if c.lastMargin then GameTooltip:AddDoubleLine(L("Last craft makes"), NPP.Coins(c.lastMargin), 1, 1, 1, 1, 1, 1) end
    if c.blocked then GameTooltip:AddLine(L("Stops at: %s"):format(L(WHY[c.blocked] or c.blocked)), 0.6, 0.6, 0.6, true) end
    GameTooltip:Show()
end

local function Build()
    frame = CreateFrame("Frame", "KisMaxSession", UIParent)
    frame:SetSize(WIDTH, 60 + 22 + ROWS * ROW_H + 110)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    local ns, T = NPP.ns, NPP.ns and NPP.ns.THEME
    if ns and ns.Solid and T then
        ns.Solid(frame, "BACKGROUND", T.bg, 0.95):SetAllPoints()
        if ns.Border then ns.Border(frame, T.line) end
    else
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.9)
    end
    tinsert(UISpecialFrames, "KisMaxSession")
    local title = Font(frame, 15)
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText(GOLD .. L("Session plan") .. "|r")
    local close = Button(frame, "X", 24, 22, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", -PAD, -PAD + 2)

    local x = PAD
    heads = {}
    for _, c in ipairs(COLS) do
        local h = Font(frame, 12)
        h:SetPoint("TOPLEFT", x + 3, -44)
        h:SetWidth(c.w - 6)
        h:SetJustifyH(c.align)
        h:SetText(GOLD .. L(c.title) .. "|r")
        heads[#heads + 1] = h
        x = x + c.w
    end
    rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, frame)
        row:SetSize(LIST_W, ROW_H)
        row:SetPoint("TOPLEFT", PAD, -62 - (i - 1) * ROW_H)
        if i % 2 == 0 then
            local stripe = row:CreateTexture(nil, "BACKGROUND")
            stripe:SetAllPoints()
            stripe:SetColorTexture(1, 1, 1, 0.03)
        end
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        row.cells = {}
        local cx = 0
        for j, c in ipairs(COLS) do
            local fs = Font(row, 12)
            fs:SetPoint("LEFT", cx + 3, 0)
            fs:SetWidth(c.w - 6)
            fs:SetJustifyH(c.align)
            fs:SetWordWrap(false)
            row.cells[j] = fs
            cx = cx + c.w
        end
        row:SetScript("OnEnter", RowTooltip)
        row:SetScript("OnLeave", GameTooltip_Hide)
        rows[i] = row
    end
    info = Font(frame, 12)
    info:SetPoint("TOPLEFT", PAD, -(62 + ROWS * ROW_H + 8))
    info:SetPoint("RIGHT", -PAD, 0)
    info:SetJustifyH("LEFT")
    info:SetWordWrap(true)

    buttons = {}
    buttons.count = Button(frame, L("Recount"), 120, 24, function() NPP.Safe("session", Session.Count) end)
    buttons.count:SetPoint("BOTTOMLEFT", PAD, PAD)
    buttons.shop = Button(frame, L("To shopping list"), 150, 24, function() NPP.Safe("session shop", Session.ToShopping) end)
    buttons.shop:SetPoint("LEFT", buttons.count, "RIGHT", 6, 0)
    Tip(buttons.shop, L("To shopping list"), L("What the whole session buys, with the price limits, goes to the KM shopping list. Buy it first."))
    buttons.queue = Button(frame, L("To craft queue"), 150, 24, function() NPP.Safe("session queue", Session.ToQueue) end)
    buttons.queue:SetPoint("LEFT", buttons.shop, "RIGHT", 6, 0)
    Tip(buttons.queue, L("To craft queue"), L("QUEUE_HELP"))
    frame:Hide()
end

function Render()
    if not (frame and frame:IsShown()) then return end
    local chosen = Chosen()
    for i, row in ipairs(rows) do
        local c = chosen[i]
        row.c = c
        if c then
            local profit = c.sale - c.cost
            row.cells[1]:SetText(c.name)
            row.cells[2]:SetText(tostring(c.count))
            row.cells[3]:SetText((profit >= 0 and GREEN or RED) .. NPP.Coins(profit) .. "|r")
            row.cells[4]:SetText(c.secs > 0 and NPP.Coins(math.floor(profit * 3600 / c.secs)) or "")
            row.cells[5]:SetText(NPP.Plan.TimeText(c.secs))
            row:Show()
        else
            row:Hide()
        end
    end
    local text
    if not result then
        text = L("Press Recount.")
    else
        local t = result.totals
        if job then
            text = L("Counting... %d crafts so far."):format(t.crafts)
        elseif t.crafts == 0 then
            text = RED .. L("Nothing pays with your money and bag space at today's prices.") .. "|r"
                .. GREY .. L(" (recipes counted: %d)"):format(#result.cands) .. "|r"
        else
            text = L("Total: %d crafts, profit %s, pay %s, time %s, %s per hour."):format(t.crafts,
                GREEN .. NPP.Coins(t.profit) .. "|r", NPP.Coins(math.floor(t.cash)), NPP.Plan.TimeText(t.secs),
                NPP.Coins(t.perHour or 0))
            local money = result.budget and L("money %s of %s"):format(NPP.Coins(math.floor(t.cash)), NPP.Coins(result.budget)) or ""
            local bags = result.free and L("bags %d of %d slots"):format(t.slots or 0, result.free) or ""
            text = text .. "\n" .. GREY .. table.concat({ money, bags }, ", ") .. "|r"
            if result.p.noDepth then text = text .. "\n" .. RED .. L("Some reagents have no quantities: their price counts as unlimited.") .. "|r" end
            text = text .. "\n" .. GREY .. L("Recipes counted: %d (the most profitable per hour). Hover a row for why it stops.")
                :format(#result.cands) .. "|r"
        end
    end
    info:SetText(text)
    frame:SetWidth(math.max(PAD * 2 + NPP.LayoutColumns(COLS, heads, rows, PAD, -44), 500))
    for _, b in pairs(buttons) do NPP.FitButton(b, 110) end
    local ready = result and not job and result.totals.crafts > 0
    SetEnabled(buttons.count, not job)
    SetEnabled(buttons.shop, ready and true or false)
    SetEnabled(buttons.queue, ready and true or false)
end

function Session.Open(keep)
    if not frame then Build() end
    frame:Show()
    if not keep and not result and not job then return Session.Count() end
    Render()
end

function Session.Toggle()
    if frame and frame:IsShown() then return frame:Hide() end
    Session.Open()
end

NPP.Module("session", { "core", "ui" }, function() end)
