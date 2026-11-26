-- Explorer.lua: "Profession overview" window. Every recipe of every profession in Naowh's recipe data
-- (ns.RecipeData: what it makes, its skill, where it is learned), learned or not, profession learned or not:
-- profit per craft, per hour of crafting and TSM sales per day, with the same prices and rules as the
-- profession window. Reagents come from the game (C_TradeSkillUI.GetRecipeSchematic works for any recipe).
-- Counted in steps (a few dozen recipes per frame) so the game does not freeze; "Recount" starts again.
-- Items the game has not loaded yet have no merchant sell price at first: when their data arrives
-- (GET_ITEM_INFO_RECEIVED), the recipes still without a profit are counted again (a few rounds at most).
-- Not counted here: Master Chef (only when cooking is the open profession), your own crafted intermediates
-- of other professions, and the cost of levelling the profession.
local _, NPP = ...
local L = NPP.L

local Explorer = {}
NPP.Explorer = Explorer

local PER_STEP = 40
local ROWS, ROW_H = 20, 20
local LEFT_W, PAD, HEAD_H, TOP_H = 190, 10, 22, 64
local COLS = {
    { key = "name", title = "Recipe", w = 230, align = "LEFT", max = 320 },
    { key = "skill", title = "Skill", w = 50, align = "CENTER" },
    { key = "learn", title = "Learn", w = 125, align = "LEFT" },
    { key = "profit", title = "Per craft", w = 80, align = "RIGHT" },
    { key = "hour", title = "Per hour", w = 85, align = "RIGHT" },
    { key = "sold", title = "Sold/day", w = 70, align = "RIGHT" },
    { key = "channel", title = "Sell", w = 60, align = "CENTER" },
}
local LIST_W = 0
for _, c in ipairs(COLS) do LIST_W = LIST_W + c.w end
local WIDTH = PAD + LEFT_W + PAD + LIST_W + PAD
local HEIGHT = TOP_H + HEAD_H + ROWS * ROW_H + PAD * 2

local GREEN, RED, GREY, GOLD = "|cff4dd17a", "|cffff5555", "|cff999999", "|cffffd100"
local DEFAULT_DESC = { name = false, skill = false, learn = false, profit = true, hour = true, sold = true, channel = false }

local frame, rows, profButtons, status, headers
local profs, results = {}, {}
local selected
local job
local sortKey, sortDesc = "hour", true
local shown = {}
local offset = 0

---------------------------------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------------------------------

local function RecipeData()
    local ns = NPP.ns
    return ns and type(ns.RecipeData) == "table" and ns.RecipeData or nil
end

local function Short(copper)
    if type(copper) ~= "number" then return "?" end
    local a = math.abs(copper)
    local text
    if a >= 10000 then
        text = L("%sg"):format(("%.1f"):format(a / 10000))
    elseif a >= 100 then
        text = L("%ds"):format(math.floor(a / 100))
    else
        text = L("%dc"):format(math.floor(a))
    end
    return copper < 0 and ("-" .. text) or text
end

local function MyFaction()
    return UnitFactionGroup("player") == "Horde" and "H" or "A"
end

-- What learning a recipe costs and how: copper or nil, kind.
local function LearnCost(r)
    local PS = NPP.PriceSource
    local kind = r.source or "unknown"
    if kind == "trainer" or kind == "teacher" then return r.cost or 0, kind end
    local best
    if kind == "vendor" and type(r.vendors) == "table" then
        local side = MyFaction()
        for _, v in ipairs(r.vendors) do
            local price = tonumber(v[7])
            if price and (type(v[3]) ~= "string" or v[3]:find(side, 1, true)) and (not best or price < best) then best = price end
        end
    end
    if r.recipe then
        local ah = PS.AH(r.recipe)
        if ah and (not best or ah < best) then best, kind = ah, kind == "vendor" and kind or (kind .. "_ah") end
    end
    return best, kind
end

local LEARN_TEXT = {
    trainer = "Trainer", teacher = "Trainer", vendor = "Merchant", drop = "Drop", quest = "Quest",
    unknown = "?", drop_ah = "AH", quest_ah = "AH", unknown_ah = "AH",
}

local function Evaluate(r, prof)
    local PS = NPP.PriceSource
    local row = { r = r, prof = prof, spell = r.spell, item = r.item, skill = r.skill or 0 }
    row.name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(r.spell)) or ("spell " .. tostring(r.spell))
    row.learnCost, row.learnKind = LearnCost(r)
    if not r.item then
        row.reason = L("Makes no item")
        return row
    end
    local ok, v = pcall(NPP.Profit.Get, r.spell, r.item, true, NPP.Get("exploreChannel"))
    if not ok or type(v) ~= "table" then
        row.reason = L("no data")
        return row
    end
    row.v = v
    row.profit, row.channel, row.seconds = v.profit, v.channel, v.seconds
    if v.profit and v.seconds and v.seconds > 0 then row.hour = math.floor(v.profit * 3600 / v.seconds) end
    row.reason = NPP.Profit.ReasonText(v)
    row.reasonKey = v.reason
    row.sold = PS.SoldPerDay(r.item)
    return row
end

local function ProfName(id, data)
    local name = data.skillSpell and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(data.skillSpell)
    return name or ("#" .. tostring(id))
end

local function BuildProfs()
    wipe(profs)
    local data = RecipeData()
    if not data then return end
    for id, d in pairs(data) do
        if type(d.recipes) == "table" and #d.recipes > 0 then
            profs[#profs + 1] = { id = id, name = ProfName(id, d), recipes = d.recipes, done = 0 }
        end
    end
    table.sort(profs, function(a, b) return a.name < b.name end)
end

local function Summarize(p)
    p.best, p.bestRow, p.profitable, p.unknown, p.losing = nil, nil, 0, 0, 0
    p.reasons = {}
    for _, r in ipairs(p.recipes) do
        local row = results[r.spell]
        if row and row.item and not row.profit then
            p.unknown = p.unknown + 1
            local key = row.reasonKey or "nodata"
            p.reasons[key] = (p.reasons[key] or 0) + 1
        elseif row and row.profit and row.profit <= 0 then
            p.losing = p.losing + 1
        end
        if row and row.profit and row.profit > 0 then
            p.profitable = p.profitable + 1
            if row.hour and (not p.best or row.hour > p.best) then p.best, p.bestRow = row.hour, row end
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------------------------------

local Render

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

local function Background(f, alpha)
    local ns, T = NPP.ns, NPP.ns and NPP.ns.THEME
    if ns and ns.Solid and T then
        ns.Solid(f, "BACKGROUND", T.bg, alpha or 0.95):SetAllPoints()
        if ns.Border then ns.Border(f, T.line) end
    else
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, alpha or 0.9)
    end
end

local function Visible(row)
    if NPP.Get("exploreOnlyProfit") and not (row.profit and row.profit > 0) then return false end
    -- TSM sold per day (region-wide) only matters for what goes to the auction house: a merchant buys everything
    local minSold = tonumber(NPP.Get("exploreMinSold"))
    if minSold and row.channel == "ah" and not (row.sold and row.sold >= minSold) then return false end
    local max = tonumber(NPP.Get("exploreMaxSkill"))
    if max and row.skill > max then return false end
    return true
end

local function SortValue(row, key)
    if key == "name" then return row.name end
    if key == "skill" then return row.skill end
    if key == "learn" then return row.learnCost end
    if key == "profit" then return row.profit end
    if key == "hour" then return row.hour end
    if key == "sold" then return row.sold end
    if key == "channel" then return row.channel end
end

local function Less(a, b)
    local x, y = SortValue(a, sortKey), SortValue(b, sortKey)
    if x ~= y then
        if x == nil then return false end
        if y == nil then return true end
        if sortDesc then return x > y end
        return x < y
    end
    if a.skill ~= b.skill then return a.skill < b.skill end
    return a.spell < b.spell
end

local function Collect()
    wipe(shown)
    local p = selected
    if not p then return end
    for _, r in ipairs(p.recipes) do
        local row = results[r.spell]
        if row and Visible(row) then shown[#shown + 1] = row end
    end
    table.sort(shown, Less)
end

local function LearnText(row)
    local kind = L(LEARN_TEXT[row.learnKind] or "?")
    if row.learnCost then
        if row.learnCost == 0 then return kind .. " " .. L("free") end
        return kind .. " " .. Short(row.learnCost)
    end
    return GREY .. kind .. "|r"
end

local function Tooltip(self)
    local row = self.row
    if not row then return end
    local PS = NPP.PriceSource
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(row.name, 1, 1, 1)
    local v = row.v
    if row.item then
        GameTooltip:AddLine(L("Makes: %s x%s"):format(NPP.Profit.ItemName(row.item), v and v.made or "?"), 0.8, 0.8, 0.8)
    end
    local r = row.r
    GameTooltip:AddLine(L("Skill %d (yellow %s, grey %s)"):format(row.skill, r.yellow or "?", r.grey or "?"), 0.8, 0.8, 0.8)
    if v and v.parts then
        GameTooltip:AddLine(L("Reagents"), 1, 0.82, 0)
        for _, part in ipairs(v.parts) do
            local right
            if part.owned then
                right = L("own")
            elseif part.each then
                right = NPP.Coins(part.each * part.need) .. " |cff999999" .. PS.Label(part.from) .. "|r"
            else
                right = RED .. L("no price") .. "|r"
            end
            GameTooltip:AddDoubleLine("  " .. NPP.Profit.ItemName(part.itemID) .. " x" .. part.need, right, 0.8, 0.8, 0.8, 1, 1, 1)
        end
        if v.sale then
            local where = v.channel == "vendor" and L("Sale to a merchant") or L("Sale on the AH, after 5% cut")
            GameTooltip:AddDoubleLine(where, NPP.Coins(v.sale), 1, 1, 1, 1, 1, 1)
        end
    end
    if row.profit then
        local c = row.profit >= 0 and { 0.3, 0.82, 0.48 } or { 1, 0.33, 0.33 }
        GameTooltip:AddDoubleLine(L("Profit per craft"), NPP.Coins(row.profit), 1, 1, 1, c[1], c[2], c[3])
    end
    if row.seconds then
        GameTooltip:AddDoubleLine(L("Time per craft"), ("%.1f s"):format(row.seconds), 1, 1, 1, 1, 1, 1)
    end
    if row.hour then GameTooltip:AddDoubleLine(L("Per hour"), NPP.Coins(row.hour), 1, 1, 1, 1, 1, 1) end
    if row.sold then
        GameTooltip:AddDoubleLine(L("TSM region sells per day"), ("%.1f"):format(row.sold), 1, 1, 1, 1, 1, 1)
        if row.channel == "ah" and row.sold > 0 then
            -- how long a batch takes to sell if you got every sale of the region (you will not: count it as the best case)
            GameTooltip:AddLine(L("At that rate: 5 sell in ~%s, 20 in ~%s (whole region; yours will be slower)."):format(
                NPP.Plan.TimeText(5 / row.sold * 86400), NPP.Plan.TimeText(20 / row.sold * 86400)), 0.6, 0.6, 0.6, true)
        end
    end
    if row.reason then GameTooltip:AddLine(row.reason, 1, 0.33, 0.33, true) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L("Learn: ") .. LearnText(row), 1, 1, 1)
    if r.source == "vendor" and type(r.vendors) == "table" then
        local side = MyFaction()
        for _, vendor in ipairs(r.vendors) do
            if type(vendor[3]) ~= "string" or vendor[3]:find(side, 1, true) then
                GameTooltip:AddLine(("  %s (%.1f, %.1f)"):format(tostring(vendor[2]), tonumber(vendor[5]) or 0,
                    tonumber(vendor[6]) or 0), 0.8, 0.8, 0.8)
            end
        end
    end
    if r.recipe then
        local ah = PS.AH(r.recipe)
        GameTooltip:AddLine(L("Recipe item on the AH: %s"):format(ah and NPP.Coins(ah) or L("no price")), 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine(L("Shift-click: link the item in chat"), 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function OnRowClick(self)
    local row = self.row
    if not (row and row.item and IsShiftKeyDown()) then return end
    local link = select(2, C_Item.GetItemInfo(row.item))
    if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
end

local function SetSort(key)
    if sortKey == key then
        sortDesc = not sortDesc
    else
        sortKey, sortDesc = key, DEFAULT_DESC[key]
    end
    offset = 0
    Render()
end

local function Toggle(key)
    NPP.db[key] = not NPP.Get(key)
    offset = 0
    Render()
end

local function SetLabel(b, text)
    if NPP.SetButtonText then NPP.SetButtonText(b, text) else b:SetText(text) end
end

local function Build()
    frame = CreateFrame("Frame", "KisMaxExplorer", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    Background(frame)
    tinsert(UISpecialFrames, "KisMaxExplorer")

    local title = Font(frame, 15)
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText(GOLD .. L("Profession overview") .. "|r")
    local close = Button(frame, "X", 24, 22, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", -PAD, -PAD + 2)
    local recount = Button(frame, L("Recount"), 110, 22, function() Explorer.Scan() end)
    recount:SetPoint("RIGHT", close, "LEFT", -6, 0)

    frame.channel = Button(frame, "", 170, 22, function()
        local order = { "best", "ah", "vendor" }
        local now = NPP.Get("exploreChannel")
        local nextOne = order[1]
        for i, k in ipairs(order) do
            if k == now then nextOne = order[i % #order + 1] end
        end
        NPP.db.exploreChannel = nextOne
        Explorer.Scan()
    end)
    frame.channel:SetPoint("TOPLEFT", PAD + LEFT_W + PAD, -(PAD + 26))
    frame.channel:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L("Sell"), 1, 1, 1)
        GameTooltip:AddLine(L("EXPLORE_CHANNEL_HELP"), 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    frame.channel:HookScript("OnLeave", GameTooltip_Hide)
    frame.onlyProfit = Button(frame, "", 170, 22, function() Toggle("exploreOnlyProfit") end)
    frame.onlyProfit:SetPoint("LEFT", frame.channel, "RIGHT", 6, 0)
    frame.onlySold = Button(frame, "", 210, 22, function()
        local steps = { false, 0.5, 1, 3, 10 }
        local now = NPP.Get("exploreMinSold")
        local nextOne = steps[1]
        for i, v in ipairs(steps) do
            if v == now then nextOne = steps[i % #steps + 1] end
        end
        NPP.db.exploreMinSold = nextOne
        offset = 0
        Render()
    end)
    frame.onlySold:SetPoint("LEFT", frame.onlyProfit, "RIGHT", 6, 0)
    frame.onlySold:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L("AH demand"), 1, 1, 1)
        GameTooltip:AddLine(L("DEMAND_FILTER_HELP"), 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    frame.onlySold:HookScript("OnLeave", GameTooltip_Hide)
    status = Font(frame, 11)
    status:SetPoint("LEFT", frame.onlySold, "RIGHT", 10, 0)
    status:SetPoint("RIGHT", -PAD, 0)
    status:SetJustifyH("RIGHT")

    -- professions
    profButtons = {}
    local data = RecipeData()
    local n = 0
    for _ in pairs(data or {}) do n = n + 1 end
    for i = 1, math.max(n, 1) do
        local b = CreateFrame("Button", nil, frame)
        b:SetSize(LEFT_W, 36)
        b:SetPoint("TOPLEFT", PAD, -(TOP_H + (i - 1) * 38))
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetColorTexture(1, 1, 1, 0.05)
        b.name = Font(b, 13)
        b.name:SetPoint("TOPLEFT", 6, -4)
        b.name:SetPoint("RIGHT", -6, 0)
        b.name:SetJustifyH("LEFT")
        b.best = Font(b, 11)
        b.best:SetPoint("BOTTOMLEFT", 6, 4)
        b.best:SetPoint("RIGHT", -6, 0)
        b.best:SetJustifyH("LEFT")
        b:SetScript("OnClick", function(self)
            selected = self.prof
            offset = 0
            Render()
        end)
        b:SetScript("OnEnter", function(self)
            local p = self.prof
            if not p then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(p.name, 1, 1, 1)
            if p.bestRow then
                GameTooltip:AddLine(L("Best per hour: %s (skill %d), %s"):format(p.bestRow.name, p.bestRow.skill, NPP.Coins(p.best)), 0.8, 0.8, 0.8, true)
            end
            GameTooltip:AddLine(L("Profitable recipes: %d of %d"):format(p.profitable or 0, #p.recipes), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(L("At a loss: %d"):format(p.losing or 0), 0.8, 0.8, 0.8)
            if (p.unknown or 0) > 0 then
                GameTooltip:AddLine(L("No price: %d"):format(p.unknown), 1, 0.6, 0.3)
                for key, n in pairs(p.reasons or {}) do
                    local text = NPP.Profit.ReasonText({ reason = key, missing = 1 }) or key
                    GameTooltip:AddLine(("  %d: %s"):format(n, text), 0.7, 0.7, 0.7, true)
                end
                GameTooltip:AddLine(L("Turn off \"Only profitable\" to see them; hover a recipe for the reason."), 0.6, 0.6, 0.6, true)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        profButtons[i] = b
    end

    -- header
    headers = {}
    local x = PAD + LEFT_W + PAD
    local headY = -TOP_H
    for i, c in ipairs(COLS) do
        local h = CreateFrame("Button", nil, frame)
        h:SetSize(c.w, HEAD_H)
        h:SetPoint("TOPLEFT", x, headY)
        h.text = Font(h, 12)
        h.text:SetAllPoints()
        h.text:SetJustifyH(c.align)
        h.col = c
        h:SetScript("OnClick", function() SetSort(c.key) end)
        headers[i] = h
        x = x + c.w
    end

    -- rows
    rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, frame)
        row:SetSize(LIST_W, ROW_H)
        row:SetPoint("TOPLEFT", PAD + LEFT_W + PAD, headY - HEAD_H - (i - 1) * ROW_H)
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
        row:SetScript("OnEnter", Tooltip)
        row:SetScript("OnLeave", GameTooltip_Hide)
        row:SetScript("OnClick", OnRowClick)
        rows[i] = row
    end
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, math.min(math.max(0, #shown - ROWS), offset - delta * 3))
        Render()
    end)
    frame:Hide()
end

local CHANNEL_TEXT = { ah = "AH", vendor = "Merchant" }

function Render()
    if not (frame and frame:IsShown()) then return end
    for i, b in ipairs(profButtons) do
        local p = profs[i]
        b.prof = p
        if p then
            b.name:SetText((p == selected and GOLD or "") .. p.name .. (p == selected and "|r" or ""))
            local text
            if p.best then
                text = GREEN .. L("up to %s/h"):format(Short(p.best)) .. "|r " .. GREY .. L("(%d profitable)"):format(p.profitable) .. "|r"
            elseif p.done < #p.recipes then
                text = GREY .. L("counting...") .. "|r"
            else
                text = GREY .. L("nothing profitable") .. "|r"
                if (p.unknown or 0) > 0 then text = text .. GREY .. L(" (no price: %d)"):format(p.unknown) .. "|r" end
            end
            b.best:SetText(text)
            b.bg:SetColorTexture(1, 1, 1, p == selected and 0.12 or 0.04)
            b:Show()
        else
            b:Hide()
        end
    end
    for _, h in ipairs(headers) do
        local mark = h.col.key == sortKey and (sortDesc and " v" or " ^") or ""
        h.text:SetText(GOLD .. L(h.col.title) .. mark .. "|r")
    end
    SetLabel(frame.onlyProfit, L("Only profitable: ") .. (NPP.Get("exploreOnlyProfit") and L("yes") or L("no")))
    local minSold = tonumber(NPP.Get("exploreMinSold"))
    SetLabel(frame.onlySold, L("AH demand: ") .. (minSold and L("%s+/day"):format(minSold) or L("any")))
    local CH = { best = "Where it pays more", ah = "Auction house", vendor = "Merchant / disenchant" }
    SetLabel(frame.channel, L("Sell: ") .. L(CH[NPP.Get("exploreChannel")] or CH.best))
    NPP.FitButton(frame.channel, 120)
    NPP.FitButton(frame.onlyProfit, 150)
    NPP.FitButton(frame.onlySold, 120)
    Collect()
    offset = math.max(0, math.min(offset, math.max(0, #shown - ROWS)))
    for i, row in ipairs(rows) do
        local data = shown[offset + i]
        row.row = data
        if data then
            local c = row.cells
            c[1]:SetText(data.name)
            c[2]:SetText(tostring(data.skill))
            c[3]:SetText(LearnText(data))
            if data.profit then
                c[4]:SetText((data.profit >= 0 and GREEN or RED) .. Short(data.profit) .. "|r")
            else
                c[4]:SetText(GREY .. "?" .. "|r")
            end
            c[5]:SetText(data.hour and ((data.hour >= 0 and GREEN or RED) .. Short(data.hour) .. "|r") or (GREY .. "?|r"))
            c[6]:SetText(data.sold and ("%.1f"):format(data.sold) or (GREY .. "-|r"))
            c[7]:SetText(data.channel and L(CHANNEL_TEXT[data.channel] or data.channel) or "")
            row:Show()
        else
            row:Hide()
        end
    end
    local total, done = 0, 0
    for _, p in ipairs(profs) do total, done = total + #p.recipes, done + p.done end
    local text = L("Shown %d-%d of %d"):format(#shown > 0 and offset + 1 or 0, math.min(offset + ROWS, #shown), #shown)
    if job then text = L("Counting %d of %d... "):format(done, total) .. text end
    status:SetText(GREY .. text .. "|r")
    local width = NPP.LayoutColumns(COLS, headers, rows, PAD + LEFT_W + PAD, -TOP_H)
    frame:SetWidth(PAD + LEFT_W + PAD + width + PAD)
end

---------------------------------------------------------------------------------------------------
-- Counting
---------------------------------------------------------------------------------------------------

local retries = 0
local MAX_RETRIES = 4

local function Step()
    local j = job
    if not j then return end
    if j.list then
        -- a recount of the recipes still without a profit
        local n = 0
        while n < PER_STEP and j.i <= #j.list do
            local e = j.list[j.i]
            results[e.r.spell] = Evaluate(e.r, e.p)
            j.i, n = j.i + 1, n + 1
        end
        if j.i > #j.list then
            job = nil
            for _, q in ipairs(profs) do Summarize(q) end
            NPP.Debug("explorer: recounted %d recipes without a price", #j.list)
            Render()
            return
        end
    else
        local n = 0
        while n < PER_STEP do
            local p = profs[j.p]
            if not p then
                job = nil
                for _, q in ipairs(profs) do Summarize(q) end
                NPP.Debug("explorer: counted")
                Render()
                return
            end
            local r = p.recipes[j.r]
            if r then
                if type(r.spell) == "number" then results[r.spell] = Evaluate(r, p) end
                p.done = j.r
                j.r = j.r + 1
                n = n + 1
            else
                Summarize(p)
                j.p, j.r = j.p + 1, 1
            end
        end
    end
    Render()
    C_Timer.After(0, function() if job == j then NPP.Safe("explorer", Step) end end)
end

-- Counts again the recipes that make an item but got no profit (item data may have arrived since).
local function Retry()
    if job or retries >= MAX_RETRIES then return end
    local list = {}
    for _, p in ipairs(profs) do
        for _, r in ipairs(p.recipes) do
            local row = results[r.spell]
            if row and row.item and not row.profit then list[#list + 1] = { r = r, p = p } end
        end
    end
    if #list == 0 then return end
    retries = retries + 1
    NPP.PriceSource.ClearCache()
    job = { list = list, i = 1 }
    NPP.Safe("explorer", Step)
end

function Explorer.Scan()
    if not RecipeData() then return NPP.Print(L("Naowh's recipe data was not found.")) end
    BuildProfs()
    wipe(results)
    if not selected or not selected.id then selected = profs[1] end
    for _, p in ipairs(profs) do
        if selected and p.id == selected.id then selected = p end
    end
    retries = 0
    job = { p = 1, r = 1 }
    Render()
    NPP.Safe("explorer", Step)
end

function Explorer.Open()
    if not RecipeData() then return NPP.Print(L("Naowh's recipe data was not found.")) end
    if not frame then Build() end
    frame:Show()
    if not next(results) and not job then
        Explorer.Scan()
    else
        Render()
    end
end

function Explorer.Toggle()
    if frame and frame:IsShown() then frame:Hide() else Explorer.Open() end
end

NPP.Module("explorer", { "core" }, function()
    local events = CreateFrame("Frame")
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    local pending = false
    events:SetScript("OnEvent", function()
        if pending or not (frame and frame:IsShown()) then return end
        pending = true
        C_Timer.After(2, function()
            pending = false
            if job then return NPP.Safe("explorer", Render) end
            NPP.Safe("explorer retry", Retry)
        end)
    end)
end)
