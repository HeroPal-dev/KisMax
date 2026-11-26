-- UI.lua: a "Sort" button beside Naowh's Filter button with our menu, our value in the list's
-- right-hand column, and profit and plan lines on the recipe tooltip. Plain (non-secure) frames only:
-- nothing here is protected, so it works in combat too.
local _, NPP = ...
local L = NPP.L

local UI = {}
NPP.UI = UI

local BTN_W = 84
local GOLD = 10000
local GOLD_TEXT = "|cffffd100"

local button, adjusting, pendingWidth
local rows, childCount, hookedRows = {}, -1, {}

local GREEN = { r = 0.3, g = 0.82, b = 0.48 }
local RED = { r = 1, g = 0.3, b = 0.3 }
local GREY = { r = 0.6, g = 0.6, b = 0.6 }

local function Style() return NPP.P.Style end

local function SetColor(fs, c)
    fs:SetTextColor(c.r, c.g, c.b, 1)
end

local function MoneyShort(copper)
    local Text = NPP.P.Text
    if Text and Text.Money then
        local ok, s = pcall(Text.Money, copper, true)
        if ok and s then return s end
    end
    return NPP.Coins(copper)
end

local function Num(x)
    if x == math.floor(x) then return tostring(x) end
    return ("%.1f"):format(x)
end

---------------------------------------------------------------------------------------------------
-- Button label and menu
---------------------------------------------------------------------------------------------------

local MODE_NAMES = { none = "Sort", profit = "Profit", roi = "ROI", total = "Plan", hour = "Per hour" }
local MODE_MENU = {
    none = "Naowh order", profit = "Profit per craft", roi = "ROI", total = "Profit of the whole plan",
    hour = "Profit per hour of crafting",
}
local CHANNELS = { best = "Where it pays more", ah = "Auction house", vendor = "Merchant / disenchant", de = "Merchant / disenchant" }

local function Label()
    local text = L(MODE_NAMES[NPP.Get("sortMode")] or "Sort")
    local n = NPP.Filters and NPP.Filters.Active() or 0
    if n > 0 then text = text .. " (" .. n .. ")" end
    return text
end

function UI.UpdateLabel()
    if not button then return end
    if button.label then button.label:SetText(Label()) elseif button.SetText then button:SetText(Label()) end
end

local function Toggle(key) NPP.Set(key, not NPP.Get(key)) end

local function ProfitText(copper)
    if copper == false then return L("Off") end
    if copper == 0 then return L("Above zero (any profit)") end
    if copper >= GOLD then return ("%dg"):format(copper / GOLD) end
    return ("%ds"):format(copper / 100)
end

local function RoiText(pct)
    if pct == false then return L("Off") end
    return pct .. "%"
end

local function ChefText()
    local manual = NPP.Get("chefPoints")
    if type(manual) == "number" then return tostring(manual) end
    local ranks = NPP.Chef.AutoRanks()
    return ranks and L("auto: %d"):format(ranks) or L("auto: not found")
end

local function NoDataTooltip(tooltip, title)
    GameTooltip_SetTitle(tooltip, title)
    GameTooltip_AddNormalLine(tooltip, L("No price data yet: press Scan Prices at the auction house."))
end

local function Radio(parent, text, key, value)
    return parent:CreateRadio(text, function() return NPP.Get(key) == value end, function() NPP.Set(key, value) end)
end

local function Check(parent, text, key)
    return parent:CreateCheckbox(text, function() return NPP.Get(key) == true end, function() Toggle(key) end)
end

local function SelectedRecipe()
    local W = NPP.P.State
    if W.selectedUnlearned or not W.selectedID then return end
    return W.selectedID
end

local function AddPlanToShopping()
    local id = SelectedRecipe()
    if not id then return NPP.Print(L("Select a learned recipe first.")) end
    local p = NPP.Plan.For(id)
    if not p or p.crafts < 1 then return NPP.Print(L("The plan for this recipe has no profitable crafts.")) end
    NPP.Plan.AddToShopping(id, p.crafts, p)
end

local function SortMenu(root)
    root:CreateTitle(L("Sort"))
    for _, mode in ipairs({ "none", "profit", "roi", "total", "hour" }) do
        local radio = Radio(root, L(MODE_MENU[mode]), "sortMode", mode)
        if mode == "hour" then
            radio:SetTooltip(function(tooltip)
                GameTooltip_SetTitle(tooltip, L(MODE_MENU[mode]))
                GameTooltip_AddNormalLine(tooltip, L("HOUR_HELP"))
            end)
        end
    end
    Check(root, L("Highest first"), "sortDesc")
    Check(root, L("One list without categories"), "flat")
    Check(root, L("Sort unlearned recipes too"), "sortUnlearned")
end

local function FilterMenu(root)
    root:CreateTitle(L("Profit filters"))
    local channel = root:CreateButton(L("Sell to: ") .. L(CHANNELS[NPP.Get("saleChannel")] or "?"))
    for _, key in ipairs({ "best", "ah", "vendor" }) do Radio(channel, L(CHANNELS[key]), "saleChannel", key) end
    local minProfit = root:CreateButton(L("Min profit: ") .. ProfitText(NPP.Get("minProfit")))
    for _, value in ipairs(NPP.Filters.MIN_PROFIT) do Radio(minProfit, ProfitText(value), "minProfit", value) end
    local minROI = root:CreateButton(L("Min ROI: ") .. RoiText(NPP.Get("minROI")))
    for _, value in ipairs(NPP.Filters.MIN_ROI) do Radio(minROI, RoiText(value), "minROI", value) end
    local unknown = Check(root, L("Hide recipes without a price"), "hideUnknown")
    if not NPP.PriceSource.HasData() then
        for _, item in ipairs({ minProfit, minROI, unknown }) do
            item:SetEnabled(false)
            item:SetTooltip(function(tooltip) NoDataTooltip(tooltip, L("Profit filters")) end)
        end
    end
    root:CreateButton(L("Reset profit filters"), function()
        NPP.db.minProfit, NPP.db.minROI = false, false
        NPP.Set("hideUnknown", false)
    end)
end

local function ChefMenu(root)
    root:CreateTitle(L("Master Chef (cooking)"))
    local ranks = root:CreateButton(L("Ranks: ") .. ChefText())
    Radio(ranks, L("Auto (from the Legacy tree)"), "chefPoints", "auto")
    for n = 0, 5 do Radio(ranks, tostring(n), "chefPoints", n) end
    local count = Check(root, L("Count overproduction (extra results)"), "chefCount")
    count:SetTooltip(function(tooltip)
        GameTooltip_SetTitle(tooltip, L("Count overproduction (extra results)"))
        GameTooltip_AddNormalLine(tooltip, L("CHEF_HELP"))
    end)
end

local BUDGETS = { "auto", false, 1, 5, 10, 25, 50, 100, 500 } -- numbers in gold
local INTER = {
    { "hour", "Craft if it raises gold per hour" },
    { "cheap", "Craft if it is cheaper" },
    { "off", "Always buy" },
}

local function BudgetText(value)
    if value == "auto" then return L("gold on the character") end
    if value == false then return L("no limit") end
    return ("%sg"):format(value)
end

local function PlanMenu(root)
    root:CreateTitle(L("Plan"))
    local current = NPP.Get("budget")
    local shown = type(current) == "number" and NPP.Coins(current) or BudgetText(current)
    local budget = root:CreateButton(L("Money for purchases: ") .. shown)
    for _, value in ipairs(BUDGETS) do
        local copper = type(value) == "number" and value * GOLD or value
        Radio(budget, BudgetText(value), "budget", copper)
    end
    budget:SetTooltip(function(tooltip)
        GameTooltip_SetTitle(tooltip, L("Money for purchases: "))
        GameTooltip_AddNormalLine(tooltip, L("BUDGET_HELP"))
    end)
    local atAH = Check(root, L("List plans follow bags only at the AH"), "plansOnlyAtAH")
    atAH:SetTooltip(function(tooltip)
        GameTooltip_SetTitle(tooltip, L("List plans follow bags only at the AH"))
        GameTooltip_AddNormalLine(tooltip, L("ATAH_HELP"))
    end)
    local bags = Check(root, L("Fit in free bag slots"), "limitByBags")
    bags:SetTooltip(function(tooltip)
        GameTooltip_SetTitle(tooltip, L("Fit in free bag slots"))
        GameTooltip_AddNormalLine(tooltip, L("BAGS_HELP"))
    end)
    local inter = root:CreateButton(L("Intermediate reagents"))
    for _, it in ipairs(INTER) do Radio(inter, L(it[2]), "intermediates", it[1]) end
    inter:SetTooltip(function(tooltip)
        GameTooltip_SetTitle(tooltip, L("Intermediate reagents"))
        GameTooltip_AddNormalLine(tooltip, L("INTER_HELP"))
    end)
    local demand = Check(root, L("Auction: no more than TSM sells per day"), "limitByDemand")
    demand:SetTooltip(function(tooltip)
        GameTooltip_SetTitle(tooltip, L("Auction: no more than TSM sells per day"))
        GameTooltip_AddNormalLine(tooltip, L("DEMAND_HELP"))
    end)
    Check(root, L("Buy plan panel under the window"), "planPanel")
    local add = root:CreateButton(L("Add the plan of the selected recipe to Naowh's shopping list"), AddPlanToShopping)
    if not SelectedRecipe() then add:SetEnabled(false) end
end

local function SourceMenu(root)
    local PS = NPP.PriceSource
    local source = root:CreateButton(L("Price source: ") .. PS.Label(NPP.Get("priceSource")))
    for _, key in ipairs({ "auto", "depth", "tsm_chain", "tsm_market", "tsm_minbuyout", "naowh" }) do
        local radio = Radio(source, PS.Label(key), "priceSource", key)
        if key:find("^tsm") and not PS.TSMAvailable() then
            radio:SetEnabled(false)
            radio:SetTooltip(function(tooltip)
                GameTooltip_SetTitle(tooltip, PS.Label(key))
                GameTooltip_AddNormalLine(tooltip, L("TradeSkillMaster is not loaded."))
            end)
        end
    end
    local depth = root:CreateButton(L("Quantity depth: %d%%"):format(NPP.Get("depthPct")))
    for _, pct in ipairs({ 1, 5, 10, 20, 30, 50 }) do Radio(depth, pct .. "%", "depthPct", pct) end
    depth:SetTooltip(function(tooltip)
        GameTooltip_SetTitle(tooltip, L("Quantity depth"))
        GameTooltip_AddNormalLine(tooltip, L("DEPTH_HELP"))
    end)
    Check(root, L("Show value in the list"), "column")
    Check(root, L("Count disenchanting (if your Enchanting can)"), "deChannel")
    Check(root, L("Disenchant value on item tooltips"), "tooltipDE")
    local fit = Check(root, L("Shrink text that does not fit the buttons"), "fitText")
    fit:SetTooltip(function(tooltip)
        GameTooltip_SetTitle(tooltip, L("Shrink text that does not fit the buttons"))
        GameTooltip_AddNormalLine(tooltip, L("FIT_HELP"))
    end)
end

-- The Sort button's menu: sorting and profit filters only. Tools and the other settings are in the KisMax
-- window (minimap button, /km).
local function Generator(_, root)
    SortMenu(root)
    root:CreateDivider()
    FilterMenu(root)
    root:CreateDivider()
    root:CreateButton("|cff33ccffKis|r" .. GOLD_TEXT .. "Max|r  " .. L("tools and settings..."), function()
        if NPP.Hub then NPP.Hub.Open() end
    end)
end
UI.ChefMenu, UI.PlanMenu, UI.SourceMenu = ChefMenu, PlanMenu, SourceMenu -- kept for /km, not in the menu

local function OpenMenu()
    NPP.Safe("menu", MenuUtil.CreateContextMenu, button, Generator)
end

local function ButtonTooltip(self)
    local PS = NPP.PriceSource
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L("KisMax"), 1, 1, 1)
    GameTooltip:AddLine(L("Sorting, profit filters and buy plans for this list."), GREY.r, GREY.g, GREY.b, true)
    local scan, naowh = PS.ScanAge(), PS.NaowhAge()
    GameTooltip:AddLine(scan and L("Our scan: %s ago."):format(scan) or L("No scan of ours yet."), GREY.r, GREY.g, GREY.b)
    GameTooltip:AddLine(naowh and L("Naowh scan: %s ago."):format(naowh) or L("No Naowh scan yet."), GREY.r, GREY.g, GREY.b)
    GameTooltip:AddLine(L("/km - commands"), GREY.r, GREY.g, GREY.b)
    GameTooltip:Show()
end

---------------------------------------------------------------------------------------------------
-- Placing the button: the search box gives up BTN_W so that search, Filter and ours fit as before.
-- Naowh resets the search width (SetWidth) each time the window opens; the hook narrows it again.
---------------------------------------------------------------------------------------------------

local function TargetWidth()
    local St = Style()
    return St.LEFT_W - St.FILTER_W - St.FILTER_GAP - BTN_W - St.FILTER_GAP
end

local function OnSearchWidth(search, width)
    if adjusting or not button then return end
    -- Full width = linked profession: Naowh hides Filter there, and our button goes with it.
    if not width or width >= Style().LEFT_W - 1 then return end
    if InCombatLockdown() and search:IsProtected() then
        pendingWidth = true
        return
    end
    local target = TargetWidth()
    if math.abs(width - target) < 0.5 then return end
    adjusting = true
    search:SetWidth(target)
    adjusting = false
end

local function Attach()
    if button then return end
    local win = NPP.P.State.frame
    if not (win and win.filter and win.search) then
        NPP.Debug("ui: window has no filter/search yet")
        return
    end
    local ns = NPP.ns
    local height = win.filter:GetHeight()
    if not height or height <= 0 then height = 22 end
    if type(ns.Button) == "function" then
        button = ns.Button(win, Label(), BTN_W, height, OpenMenu)
    else
        button = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
        button:SetSize(BTN_W, height)
        button:SetScript("OnClick", OpenMenu)
    end
    button:SetPoint("LEFT", win.filter, "RIGHT", Style().FILTER_GAP, 0)
    button:HookScript("OnEnter", ButtonTooltip)
    button:HookScript("OnLeave", GameTooltip_Hide)
    button:SetShown(win.filter:IsShown())
    win.filter:HookScript("OnShow", function() button:Show() end)
    win.filter:HookScript("OnHide", function() button:Hide() end)
    hooksecurefunc(win.search, "SetWidth", OnSearchWidth)
    hooksecurefunc(win.search, "SetSize", OnSearchWidth)
    OnSearchWidth(win.search, win.search:GetWidth())
    UI.UpdateLabel()
    NPP.Debug("ui: Sort button attached")
end

---------------------------------------------------------------------------------------------------
-- The tooltip
---------------------------------------------------------------------------------------------------

local function AddPlanLines(tooltip, p, detail)
    local PS = NPP.PriceSource
    if not p or p.limit == "noprice" then return end
    if p.crafts < 1 then
        tooltip:AddDoubleLine(L("Plan"), L("no profitable craft (%s)"):format(NPP.Plan.LimitText(p)),
            1, 1, 1, RED.r, RED.g, RED.b)
        return
    end
    tooltip:AddDoubleLine(L("Plan: %d crafts, ~%s items"):format(p.crafts, Num(p.units)),
        NPP.Coins(p.profit), 1, 1, 1, GREEN.r, GREEN.g, GREEN.b)
    tooltip:AddLine(L("Stops at: %s"):format(NPP.Plan.LimitText(p)), GREY.r, GREY.g, GREY.b)
    if p.seconds and p.seconds > 0 then
        tooltip:AddDoubleLine(L("Time: %s"):format(NPP.Plan.TimeText(p.seconds)),
            L("%s per hour"):format(NPP.Coins(p.perHour)), GREY.r, GREY.g, GREY.b, GREY.r, GREY.g, GREY.b)
    end
    if p.soldPerDay then
        tooltip:AddLine(L("TSM region sells ~%s per day"):format(Num(p.soldPerDay)), GREY.r, GREY.g, GREY.b)
    end
    if not detail then return end
    for _, b in ipairs(p.parts) do
        local name = NPP.Profit.ItemName(b.itemID)
        local bits = {}
        if b.own then bits[#bits + 1] = L("own") .. " " .. b.own end
        if (b.crafted or 0) > 0 then bits[#bits + 1] = L("craft %d"):format(b.crafted) end
        if (b.bags or 0) > 0 then bits[#bits + 1] = L("bags") .. " " .. b.bags end
        if (b.ah or 0) > 0 then
            bits[#bits + 1] = L("AH %d up to %s"):format(b.ah, NPP.Coins(b.ahMax))
        end
        if (b.vendor or 0) > 0 then bits[#bits + 1] = L("merchant") .. " " .. b.vendor end
        tooltip:AddDoubleLine((b.sub and "    > " or "  ") .. name .. " x" .. b.need, table.concat(bits, ", "),
            0.8, 0.8, 0.8, 1, 1, 1)
    end
    if p.noDepth then tooltip:AddLine(L("Some reagents have no quantities: their price counts as unlimited."),
        RED.r, RED.g, RED.b, true) end
    if PS.ScanAge() then tooltip:AddLine(L("Quantities from our scan, %s ago."):format(PS.ScanAge()), GREY.r, GREY.g, GREY.b) end
end

function UI.AddTooltip(tooltip, v, p)
    local PS = NPP.PriceSource
    local shift = IsShiftKeyDown()
    tooltip:AddLine(" ")
    tooltip:AddLine(L("KisMax"), 0.2, 0.8, 1)
    if v.profit then
        local roi = v.roi and (" (%d%% ROI)"):format(math.floor(v.roi + 0.5)) or ""
        local c = v.profit >= 0 and GREEN or RED
        tooltip:AddDoubleLine(L("Profit per craft"), NPP.Coins(v.profit) .. roi, 1, 1, 1, c.r, c.g, c.b)
    end
    if v.sale then
        local where = v.channel == "vendor" and L("Sale to a merchant")
            or v.channel == "de" and L("Disenchanted (materials on the AH)") or L("Sale on the AH, after 5% cut")
        tooltip:AddDoubleLine(where .. " x" .. Num(v.made), NPP.Coins(v.sale), 1, 1, 1, 1, 1, 1)
        local other = v.channel == "vendor" and v.ahSale or v.vendorSale
        if other and NPP.Get("saleChannel") == "best" then
            tooltip:AddDoubleLine(v.channel == "vendor" and L("  (on the AH)") or L("  (to a merchant)"),
                NPP.Coins(other), GREY.r, GREY.g, GREY.b, GREY.r, GREY.g, GREY.b)
        end
    end
    if v.parts and #v.parts > 0 then
        local text = NPP.Coins(v.cost)
        if v.missing > 0 then text = text .. " + ?" end
        tooltip:AddDoubleLine(L("Reagents"), text, 1, 1, 1, 1, 1, 1)
    end
    if v.chefRanks and v.chefRanks > 0 then
        tooltip:AddLine(L("Master Chef %d: +%s items per craft on average"):format(v.chefRanks, Num(v.extra or 0)), GREY.r, GREY.g, GREY.b)
    end
    local reason = NPP.Profit.ReasonText(v)
    if reason then tooltip:AddLine(reason, RED.r, RED.g, RED.b, true) end
    AddPlanLines(tooltip, p, shift)
    if shift then
        tooltip:AddLine(L("Price per craft:"), 1, 1, 1)
        for _, part in ipairs(v.parts or {}) do
            local name = ("%s x%d"):format(NPP.Profit.ItemName(part.itemID), part.need)
            local right
            if part.owned then
                right = L("own")
            elseif part.each then
                right = NPP.Coins(part.each * part.need) .. " |cff999999" .. PS.Label(part.from) .. "|r"
            else
                right = "|cffff4444" .. L("no price") .. "|r"
            end
            tooltip:AddDoubleLine("  " .. name, right, 0.8, 0.8, 0.8, 1, 1, 1)
        end
        if v.src then tooltip:AddLine(L("Sale price from: ") .. PS.Label(v.src), GREY.r, GREY.g, GREY.b) end
    elseif v.parts and #v.parts > 0 then
        tooltip:AddLine(L("Shift: reagents and what to buy"), GREY.r, GREY.g, GREY.b)
    end
end

local function RowTooltip(row)
    if not NPP.Get("tooltip") or GameTooltip:GetOwner() ~= row then return end
    local e = row.entry
    if not e or e.cat or NPP.P.State.linked then return end
    local v = NPP.Profit.ForEntry(e)
    if not v then return end
    local p = NPP.Plan.ForEntry(e)
    NPP.Safe("tooltip", UI.AddTooltip, GameTooltip, v, p)
    GameTooltip:Show()
end

---------------------------------------------------------------------------------------------------
-- The list column
---------------------------------------------------------------------------------------------------

-- Naowh's rows are children of win.list with .entry, .profit, .text and .icon.
local function Rows(list)
    local n = list:GetNumChildren()
    if n == childCount then return rows end
    wipe(rows)
    for _, child in ipairs({ list:GetChildren() }) do
        if child.profit and child.text and child.icon then
            rows[#rows + 1] = child
            if not hookedRows[child] then
                hookedRows[child] = true
                child:HookScript("OnEnter", RowTooltip)
            end
        end
    end
    childCount = n
    return rows
end

local function ValueText(e, mode)
    if mode == "total" then
        local p = NPP.Plan.ForEntry(e)
        if p and p.crafts > 0 then return MoneyShort(p.profit), GREEN end
        return ""
    end
    if mode == "hour" then
        local p = NPP.Plan.ForEntry(e)
        if p and p.hourly then return MoneyShort(p.hourly), p.hourly >= 0 and GREEN or RED end
        return ""
    end
    local v = NPP.Profit.ForEntry(e)
    if not v then return "" end
    if mode == "roi" then
        if v.roi then return ("%d%%"):format(math.floor(v.roi + 0.5)), v.roi >= 0 and GREEN or RED end
        if v.roiInf then return L("free"), GREEN end
        return ""
    end
    if v.profit then return MoneyShort(v.profit), v.profit >= 0 and GREEN or RED end
    return ""
end

local function AfterListRender()
    local win = NPP.P.State.frame
    if not (win and win.list) then return end
    local list = Rows(win.list)
    if not NPP.Get("column") or NPP.P.State.linked or not NPP.PriceSource.HasData() then return end
    local St = Style()
    local green, red = St.PROFIT_RGB or GREEN, St.RED_RGB or RED
    local mode = NPP.Get("sortMode")
    for _, row in ipairs(list) do
        local e = row.entry
        if row:IsShown() and e and not e.cat then
            local text, color = ValueText(e, mode)
            row.profit:SetText(text)
            if color then SetColor(row.profit, color == GREEN and green or color == RED and red or color) end
        end
    end
end

local function OnRegen()
    if not pendingWidth then return end
    pendingWidth = nil
    local win = NPP.P.State.frame
    if win and win.search then OnSearchWidth(win.search, win.search:GetWidth()) end
end

---------------------------------------------------------------------------------------------------
-- Naowh's "Buy for / Sell for / Profit" lines by the Create button: our numbers (our prices with quantities, the
-- yield with Master Chef, our sale channel: AH, merchant / disenchant or the best of them). Naowh fills them in
-- P.Lines.RenderProfit; we write over them right after it.
---------------------------------------------------------------------------------------------------

local CHANNEL_NOTE = { ah = "AH, after the 5% cut", vendor = "to a merchant", de = "disenchanted" }

local function OurProfitLines(block, recipeID, output)
    if not (NPP.Get("ourProfitBlock") and block and block:IsShown() and block.buy and block.sell and block.profit) then return end
    local P = NPP.P
    local Lines, Text, St = P.Lines, P.Text, P.Style
    if not (Lines and Lines.Set and Text and Text.Money) then return end
    local v = NPP.Profit.Get(recipeID, output)
    if not v or #(v.parts or {}) == 0 then return end
    local function Money(c, plus) return Text.Money(math.floor(c + 0.5), plus) end
    local none = Lines.None and Lines.None() or "-"
    Lines.Set(block.buy, block.buy.label:GetText(), Money(v.cost),
        v.missing > 0 and L("+ %d without a price"):format(v.missing) or nil)
    local sellNote = v.channel and L(CHANNEL_NOTE[v.channel] or v.channel) or nil
    if sellNote and v.made and v.made ~= 1 then sellNote = sellNote .. (", x%s"):format(Num(v.made)) end
    Lines.Set(block.sell, block.sell.label:GetText(), v.sale and Money(v.sale) or none, sellNote or (not v.sale and NPP.Profit.ReasonText(v)) or nil)
    if v.profit then
        local c = v.profit >= 0 and (St.PROFIT_RGB or GREEN) or (St.RED_RGB or RED)
        Lines.Set(block.profit, block.profit.label:GetText(),
            Text.Hex and (Text.Hex(c) .. Money(v.profit, true) .. "|r") or Money(v.profit, true), "|cff33ccffKM|r")
    else
        Lines.Set(block.profit, block.profit.label:GetText(), none, NPP.Profit.ReasonText(v))
    end
    if block.roi and block.roi:IsShown() then
        local roi = v.roi and ("%d%%"):format(math.floor(v.roi + 0.5)) or (v.roiInf and L("free")) or nil
        Lines.Set(block.roi, block.roi.label:GetText(), roi)
    end
    if Lines.Fit then Lines.Fit(block.lines) end
    block.value = v -- Naowh's tooltip on the lines then lists our reagents and prices
end

NPP.Module("ui", { "core", "ui" }, function()
    local P = NPP.P
    if P.Lines and type(P.Lines.RenderProfit) == "function" then
        hooksecurefunc(P.Lines, "RenderProfit", function(block, recipeID, output)
            NPP.Safe("profit lines", OurProfitLines, block, recipeID, output)
        end)
    end
    hooksecurefunc(P.Window, "Build", function() NPP.Safe("ui attach", Attach) end)
    hooksecurefunc(P.Window, "Render", function()
        if not button then NPP.Safe("ui attach", Attach) end
        UI.UpdateLabel()
    end)
    hooksecurefunc(P.List, "Render", function() NPP.Safe("ui column", AfterListRender) end)
    if P.State.frame then NPP.Safe("ui attach", Attach) end
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function() NPP.Safe("ui regen", OnRegen) end)
end)
