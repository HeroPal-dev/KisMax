-- PlanPanel.lua: "Buy plan" panel under Naowh's profession window for the selected recipe:
-- how many crafts still pay, what to buy on the auction house (how many units, up to which unit price),
-- what from a merchant, the profit, and how fresh the lots are. "Refresh lots" (at the auction house)
-- searches the recipe's reagents and result; "To shopping list" hands the crafts to Naowh's list.
-- Child of Naowh's window, so it shows and hides with it; outside its edge, so it covers nothing of it.
local _, NPP = ...
local L = NPP.L

local PlanPanel = {}
NPP.PlanPanel = PlanPanel

local PAD, GAP, LINE_GAP = 8, 4, 3
local BTN_H, BTN_REFRESH_W, BTN_LIST_W, BTN_SELL_W = 20, 120, 120, 200
local MAX_LINES = 18

local panel, lines, title
local GREEN = "|cff4dd17a"
local RED = "|cffff5555"
local GREY = "|cff999999"
local GOLD = "|cffffd100"

local function Font(parent, size)
    local ns = NPP.ns
    if ns and type(ns.Font) == "function" then return ns.Font(parent, size, nil) end
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    return fs
end

local function Num(x)
    if x == math.floor(x) then return tostring(x) end
    return ("%.1f"):format(x)
end

local function Selected()
    local W = NPP.P.State
    if W.linked then return end
    if W.selectedUnlearned then
        local r = W.selectedUnlearned
        return r.spell, r.item, C_Spell.GetSpellName(r.spell), false
    end
    if W.selectedID then
        local info = C_TradeSkillUI.GetRecipeInfo(W.selectedID)
        return W.selectedID, nil, info and info.name, info and info.learned
    end
end

local function OnRefresh()
    local id, item = Selected()
    if id then NPP.Live.RefreshRecipe(id, item) end
    PlanPanel.Render()
end

local function OnShopping()
    local id, item = Selected()
    if not id then return end
    local p = NPP.Plan.For(id, item)
    if not p or p.crafts < 1 then return NPP.Print(L("The plan for this recipe has no profitable crafts.")) end
    NPP.Plan.AddToShopping(id, p.crafts, p)
end

local function OnSellToggle()
    local id, item = Selected()
    if not (id and NPP.Sell) then return end
    local v = NPP.Profit.Get(id, item)
    if not v.output then return NPP.Print(L("This recipe makes no item to sell.")) end
    NPP.Sell.Toggle(v.output)
end

local function Button(text, w, onClick)
    local ns = NPP.ns
    local b
    if ns and type(ns.Button) == "function" then
        b = ns.Button(panel, text, w, BTN_H, onClick)
    else
        b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetSize(w, BTN_H)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
    end
    return b
end

local function SetEnabled(b, on)
    if b.SetEnabled then b:SetEnabled(on) end
    b:SetAlpha(on and 1 or 0.45)
end

local function Build(win)
    local P = NPP.P
    local St = P.Style
    local ns, T = NPP.ns, NPP.ns.THEME
    panel = CreateFrame("Frame", nil, win)
    panel:SetWidth(St.MID_W or 400)
    panel:SetHeight(60)
    panel:EnableMouse(true)
    if ns.Solid and T then
        ns.Solid(panel, "BACKGROUND", T.bg, St.WINDOW_ALPHA or 0.95):SetAllPoints()
        if ns.Border then ns.Border(panel, St.BORDER_RGB or T.line) end
    else
        local bg = panel:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.85)
    end
    title = Font(panel, (St.FONT or 12) + 1)
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    panel.refresh = Button(L("Refresh lots"), BTN_REFRESH_W, OnRefresh)
    panel.refresh:SetPoint("TOPRIGHT", -PAD, -PAD + 3)
    panel.refresh:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L("Refresh lots"), 1, 1, 1)
        GameTooltip:AddLine(L("At the auction house: searches this recipe's reagents and result and reads every lot with its quantity."), 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    panel.refresh:HookScript("OnLeave", GameTooltip_Hide)
    panel.list = Button(L("To shopping list"), BTN_LIST_W, OnShopping)
    panel.list:SetPoint("RIGHT", panel.refresh, "LEFT", -GAP, 0)
    title:SetPoint("RIGHT", panel.list, "LEFT", -GAP, 0)
    panel.sell = Button(L("Sell to merchants: no"), BTN_SELL_W, OnSellToggle)
    panel.sell:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L("Sell list"), 1, 1, 1)
        GameTooltip:AddLine(L("SELL_HELP"), 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    panel.sell:HookScript("OnLeave", GameTooltip_Hide)
    panel.session = Button(L("Session plan"), 150, function()
        if NPP.Session then NPP.Safe("session", NPP.Session.Count) end
    end)
    panel.session:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L("Session plan"), 1, 1, 1)
        GameTooltip:AddLine(L("SESSION_HELP"), 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    panel.session:HookScript("OnLeave", GameTooltip_Hide)
    lines = {}
    for i = 1, MAX_LINES do
        local fs = Font(panel, St.FONT or 12)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetPoint("LEFT", PAD, 0)
        fs:SetPoint("RIGHT", -PAD, 0)
        lines[i] = fs
    end
    panel:Hide()
end

local function Place(win, height)
    panel:ClearAllPoints()
    local St = NPP.P.Style
    local x = St.MID_X or 356
    local bottom = win:GetBottom() -- in the window's own scale, as the panel's height is (it is its child)
    if bottom and bottom - height - GAP < 0 then
        panel:SetPoint("BOTTOMLEFT", win, "TOPLEFT", x, GAP)
    else
        panel:SetPoint("TOPLEFT", win, "BOTTOMLEFT", x, -GAP)
    end
end

local function Age(t)
    return t and NPP.PriceSource.Age(t) or "?"
end

local function LotsLine(p)
    local live, scan, none
    for _, b in ipairs(p.parts or {}) do
        if not b.own then
            if b.lotsFrom == "live" then
                live = math.min(live or math.huge, b.lotsAt or 0)
            elseif b.lotsFrom == "scan" then
                scan = b.lotsAt
            elseif (b.vendor or 0) == 0 then
                none = true
            end
        end
    end
    local bits = {}
    if live then bits[#bits + 1] = L("search %s ago"):format(Age(live)) end
    if scan then bits[#bits + 1] = L("full scan %s ago"):format(Age(scan)) end
    if none then bits[#bits + 1] = L("some without quantities") end
    if #bits == 0 then return end
    local text = GREY .. L("Lots: ") .. table.concat(bits, ", ") .. "|r"
    if none or (not live) then text = text .. GREY .. L(" - open the AH and press Refresh lots") .. "|r" end
    return text
end

local function PartLine(b, p)
    local name = NPP.Profit.ItemName(b.itemID)
    local bits = {}
    if b.own then bits[#bits + 1] = L("own") end
    if (b.crafted or 0) > 0 then
        bits[#bits + 1] = GREEN .. L("craft %d yourself (%d crafts)"):format(b.crafted, b.crafts) .. "|r"
    end
    if (b.bags or 0) > 0 then bits[#bits + 1] = L("bags %d"):format(b.bags) end
    if (b.ah or 0) > 0 then
        bits[#bits + 1] = GOLD .. L("buy on the AH %d up to %s each (%s)"):format(b.ah, NPP.Coins(b.ahMax), NPP.Coins(b.ahCost)) .. "|r"
    end
    if (b.vendor or 0) > 0 then
        bits[#bits + 1] = L("merchant %d (%s)"):format(b.vendor, NPP.Coins(b.vendorCost))
    end
    if p.crafts == 0 and b.lotsTotal then bits[#bits + 1] = GREY .. L("%d on the AH"):format(b.lotsTotal) .. "|r" end
    if b.makeEach and (b.crafted or 0) < b.need then
        -- why (part of) it is bought, not crafted
        local why
        if b.buyEach and b.makeEach < b.buyEach then
            why = L("craft is cheaper, but buying gives more gold per hour")
        else
            why = L("buying is cheaper")
        end
        bits[#bits + 1] = GREY .. L("yourself: %s each + %s s (%s)"):format(NPP.Coins(b.makeEach), Num(math.floor(b.makeSecs * 10 + 0.5) / 10), why) .. "|r"
    end
    return ("%s%s x%d: %s"):format(b.sub and (GREY .. "  > |r") or "", name, b.need,
        #bits > 0 and table.concat(bits, ", ") or "-")
end

local function Fill(id, item, name)
    local v = NPP.Profit.Get(id, item)
    local p = NPP.Plan.For(id, item, true)
    local out = {}
    title:SetText(GOLD .. L("Buy plan: ") .. "|r" .. (name or "?"))
    if v.unitSale then
        local where = v.channel == "vendor" and L("to a merchant")
            or v.channel == "de" and L("disenchanted") or L("on the AH (after 5% cut)")
        out[#out + 1] = L("Sale %s: %s each, x%s per craft"):format(where, NPP.Coins(v.unitSale), Num(v.made))
            .. (v.chefRanks and v.chefRanks > 0 and (GREY .. L(" (Master Chef %d)"):format(v.chefRanks) .. "|r") or "")
    end
    if p.limit == "noprice" then
        out[#out + 1] = RED .. (NPP.Profit.ReasonText(v) or L("no prices")) .. "|r"
    elseif p.crafts > 0 then
        out[#out + 1] = GREEN .. L("Pays: %d crafts (~%s items), profit %s"):format(p.crafts, Num(p.units), NPP.Coins(p.profit))
            .. "|r" .. GREY .. L(" - cost %s, sale %s"):format(NPP.Coins(p.cost), NPP.Coins(p.sale)) .. "|r"
    else
        out[#out + 1] = RED .. L("No craft pays at today's prices.") .. "|r"
    end
    if p.limit ~= "noprice" then
        local stop = GREY .. L("Stops at: %s"):format(NPP.Plan.LimitText(p))
        if p.nextMargin then stop = stop .. L(" (next craft: %s)"):format(NPP.Coins(p.nextMargin)) end
        if p.soldPerDay then stop = stop .. L(", TSM ~%s sold per day"):format(Num(math.floor(p.soldPerDay * 10 + 0.5) / 10)) end
        out[#out + 1] = stop .. "|r"
        if p.crafts > 0 and p.seconds then
            out[#out + 1] = L("Time: %s%s (%s s per craft), ~%s per hour"):format(
                p.castGuess and "~" or "", NPP.Plan.TimeText(p.seconds), Num(p.castTime), NPP.Coins(p.perHour))
                .. (p.castGuess and (GREY .. L(" (cast time unknown, 3 s assumed)") .. "|r") or "")
        end
        if p.budget then
            local have = NPP.Get("budget") == "auto" and L("you have %s") or L("budget %s")
            out[#out + 1] = L("Money: pay %s, "):format(NPP.Coins(p.cash)) .. have:format(NPP.Coins(p.budget))
            if p.limit == "money" and p.freeCrafts and p.freeCrafts > p.crafts then
                out[#out + 1] = GREY .. L("With more money: %d crafts, profit %s, pay %s"):format(
                    p.freeCrafts, NPP.Coins(p.freeProfit), NPP.Coins(p.freeCash)) .. "|r"
            end
        end
        if p.freeSlots then
            local color = p.limit == "bags" and RED or ""
            out[#out + 1] = color .. L("Bags: needs %d slots (purchases %d, results %d), %d free"):format(
                p.slots or 0, p.slotsBuy or 0, p.slotsMade or 0, p.freeSlots) .. (color ~= "" and "|r" or "")
            if p.limit == "bags" and p.freeCrafts and p.freeCrafts > p.crafts then
                out[#out + 1] = GREY .. L("With more bag space: %d crafts, profit %s, needs %d slots"):format(
                    p.freeCrafts, NPP.Coins(p.freeProfit), p.freeSlotsNeeded or 0) .. "|r"
            end
        end
        if p.subSeconds and p.subSeconds > 0 then
            out[#out + 1] = GREY .. L("Of the time, crafting intermediates: %s"):format(NPP.Plan.TimeText(p.subSeconds)) .. "|r"
        end
        for _, b in ipairs(p.parts) do
            if #out < MAX_LINES - 4 then out[#out + 1] = PartLine(b, p) end
        end
        if p.noDepth then out[#out + 1] = RED .. L("Some reagents have no quantities: their price counts as unlimited.") .. "|r" end
        local lots = LotsLine(p)
        if lots then out[#out + 1] = lots end
        local fact = NPP.Ledger and NPP.Started("ledger") and NPP.Ledger.Recipe(id)
        if fact then
            local color = fact.net >= 0 and GREEN or RED
            out[#out + 1] = L("Real: crafted %d, sold %d for %s, reagents %s%s, result "):format(fact.crafts,
                fact.sold, NPP.Coins(fact.earned), fact.estimated and "~" or "", NPP.Coins(fact.cost))
                .. color .. NPP.Coins(fact.net) .. "|r"
        end
    end
    return out, p
end

function PlanPanel.Render()
    if not panel then return end
    local W = NPP.P.State
    local win = W.frame
    if not (NPP.Get("planPanel") and win and win:IsShown() and win.mid and win.mid:IsShown()) then
        panel:Hide()
        return
    end
    local id, item, name, learned = Selected()
    if not id then
        panel:Hide()
        return
    end
    local out, p = Fill(id, item, name)
    local y = PAD + math.max(title:GetStringHeight(), BTN_H) + GAP
    for i, fs in ipairs(lines) do
        local text = out[i]
        if text then
            fs:SetText(text)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", PAD, -y)
            fs:SetPoint("RIGHT", -PAD, 0)
            fs:Show()
            y = y + fs:GetStringHeight() + LINE_GAP
        else
            fs:Hide()
        end
    end
    local sellOn = NPP.Sell and NPP.Started("sell")
    local sessionOn = NPP.Session and NPP.Started("session")
    local output = sellOn and NPP.Profit.Get(id, item).output
    if sellOn then
        panel.sell:ClearAllPoints()
        panel.sell:SetPoint("TOPLEFT", PAD, -y)
        NPP.SetButtonText(panel.sell, NPP.Sell.Has(output) and (GREEN .. L("Sell to merchants: yes") .. "|r")
            or (GREY .. L("Sell to merchants: no") .. "|r"))
        SetEnabled(panel.sell, output ~= nil)
        panel.sell:Show()
    else
        panel.sell:Hide()
    end
    if sessionOn then
        panel.session:ClearAllPoints()
        if sellOn then
            panel.session:SetPoint("LEFT", panel.sell, "RIGHT", GAP, 0)
        else
            panel.session:SetPoint("TOPLEFT", PAD, -y)
        end
        panel.session:Show()
    else
        panel.session:Hide()
    end
    if sellOn or sessionOn then y = y + BTN_H + LINE_GAP end
    local height = y + PAD
    panel:SetHeight(height)
    Place(win, height)
    SetEnabled(panel.refresh, NPP.Live and NPP.Live.Open() and not NPP.Live.Busy() or false)
    local shop = NPP.P.Shopping
    local items = shop and type(shop.AddItem) == "function"
    SetEnabled(panel.list, p.crafts > 0 and (items or (learned == true and not item)))
    panel:Show()
end

local function Attach()
    if panel then return end
    local win = NPP.P.State.frame
    if not (win and win.mid) then return end
    Build(win)
    NPP.Debug("plan panel attached")
end

NPP.Module("planpanel", { "core", "ui" }, function()
    local P = NPP.P
    hooksecurefunc(P.Window, "Render", function()
        if not panel then NPP.Safe("plan panel attach", Attach) end
        NPP.Safe("plan panel", PlanPanel.Render)
    end)
    if type(P.Detail) == "table" and type(P.Detail.Render) == "function" then
        hooksecurefunc(P.Detail, "Render", function() NPP.Safe("plan panel", PlanPanel.Render) end)
    end
    if P.State.frame then NPP.Safe("plan panel attach", Attach) end
end)
