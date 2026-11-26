-- History.lua: "History by day" window from the ledger's days (Ledger.Days): per day what went to the auction
-- house and merchants, what merchants paid, the result in money, crafts, and the recipe whose results brought
-- the most. Totals for the last 7 and 30 days at the bottom. Auction sales (mail) are not in the ledger yet.
local _, NPP = ...
local L = NPP.L

local History = {}
NPP.History = History

local ROWS, ROW_H = 14, 20
local COLS = {
    { title = "Day", w = 90, align = "LEFT" },
    { title = "Spent", w = 95, align = "RIGHT" },
    { title = "Merchants paid", w = 110, align = "RIGHT" },
    { title = "Result", w = 95, align = "RIGHT" },
    { title = "Crafts", w = 60, align = "RIGHT" },
    { title = "Best recipe", w = 200, align = "LEFT", max = 300 },
}
local PAD = 10
local LIST_W = 0
for _, c in ipairs(COLS) do LIST_W = LIST_W + c.w end
local WIDTH = PAD * 2 + LIST_W
local GREEN, RED, GREY, GOLD = "|cff4dd17a", "|cffff5555", "|cff999999", "|cffffd100"

local frame, rows, totals, heads
local offset = 0

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

local function Net(day) return (day.vendorEarned or 0) - (day.ahSpent or 0) - (day.vendorSpent or 0) end

local function Colored(copper)
    return (copper >= 0 and GREEN or RED) .. NPP.Coins(copper) .. "|r"
end

local function Best(day)
    local best, bestName
    for _, r in pairs(day.recipes or {}) do
        if (r.earned or 0) > 0 and (not best or r.earned > best) then best, bestName = r.earned, r.name end
    end
    return bestName, best
end

local function SortedDays()
    local keys = {}
    for k in pairs(NPP.Ledger.Days()) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return a > b end)
    return keys
end

local function Pretty(key)
    local y, m, d = key:match("^(%d+)-(%d+)-(%d+)$")
    if not y then return key end
    if key == NPP.Ledger.DayKey() then return L("today") end
    if key == NPP.Ledger.DayKey(time() - 86400) then return L("yesterday") end
    return ("%s.%s.%s"):format(d, m, y:sub(3))
end

local function Sum(keys, days, n)
    local since = NPP.Ledger.DayKey(time() - (n - 1) * 86400)
    local s = { spent = 0, earned = 0, crafts = 0 }
    for _, k in ipairs(keys) do
        if k >= since then
            local d = days[k]
            s.spent = s.spent + (d.ahSpent or 0) + (d.vendorSpent or 0)
            s.earned = s.earned + (d.vendorEarned or 0)
            s.crafts = s.crafts + (d.crafts or 0)
        end
    end
    return s
end

function History.Render()
    if not (frame and frame:IsShown()) then return end
    local days = NPP.Ledger.Days()
    local keys = SortedDays()
    offset = math.max(0, math.min(offset, math.max(0, #keys - ROWS)))
    for i, row in ipairs(rows) do
        local key = keys[offset + i]
        local d = key and days[key]
        if d then
            local c = row.cells
            c[1]:SetText(Pretty(key))
            c[2]:SetText(NPP.Coins((d.ahSpent or 0) + (d.vendorSpent or 0)))
            c[3]:SetText(NPP.Coins(d.vendorEarned or 0))
            c[4]:SetText(Colored(Net(d)))
            c[5]:SetText(tostring(d.crafts or 0))
            local name, earned = Best(d)
            c[6]:SetText(name and (name .. GREY .. " (" .. NPP.Coins(earned) .. ")|r") or (GREY .. "-|r"))
            row.day = d
            row:Show()
        else
            row.day = nil
            row:Hide()
        end
    end
    if #keys == 0 then
        rows[1].cells[1]:SetText(GREY .. L("No days recorded yet.") .. "|r")
        for j = 2, #COLS do rows[1].cells[j]:SetText("") end
        rows[1]:Show()
    end
    local w, m = Sum(keys, days, 7), Sum(keys, days, 30)
    totals:SetText(L("7 days: spent %s, merchants paid %s, result %s, crafts %d"):format(NPP.Coins(w.spent),
        NPP.Coins(w.earned), Colored(w.earned - w.spent), w.crafts) .. "\n"
        .. L("30 days: spent %s, merchants paid %s, result %s, crafts %d"):format(NPP.Coins(m.spent),
        NPP.Coins(m.earned), Colored(m.earned - m.spent), m.crafts) .. "\n"
        .. GREY .. L("Auction sales (by mail) are not counted yet.") .. "|r")
    frame:SetWidth(PAD * 2 + NPP.LayoutColumns(COLS, heads, rows, PAD, -44))
end

local function DayTooltip(self)
    local d = self.day
    if not d then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddDoubleLine(L("Auction house"), NPP.Coins(d.ahSpent or 0), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L("Merchants (bought)"), NPP.Coins(d.vendorSpent or 0), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L("Merchants paid"), NPP.Coins(d.vendorEarned or 0), 1, 1, 1, 1, 1, 1)
    local list = {}
    for _, r in pairs(d.recipes or {}) do list[#list + 1] = r end
    table.sort(list, function(a, b) return (a.earned or 0) > (b.earned or 0) end)
    if #list > 0 then
        GameTooltip:AddLine(" ")
        for _, r in ipairs(list) do
            GameTooltip:AddDoubleLine(L("%s: %d crafts"):format(r.name or "?", r.crafts or 0), NPP.Coins(r.earned or 0),
                0.8, 0.8, 0.8, 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

local function Build()
    frame = CreateFrame("Frame", "KisMaxHistory", UIParent)
    frame:SetSize(WIDTH, 60 + 22 + ROWS * ROW_H + 64)
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
    tinsert(UISpecialFrames, "KisMaxHistory")
    local title = Font(frame, 15)
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText(GOLD .. L("History by day") .. "|r")
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
        row:SetScript("OnEnter", DayTooltip)
        row:SetScript("OnLeave", GameTooltip_Hide)
        rows[i] = row
    end
    totals = Font(frame, 12)
    totals:SetPoint("BOTTOMLEFT", PAD, PAD)
    totals:SetPoint("RIGHT", -PAD, 0)
    totals:SetJustifyH("LEFT")
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, offset - delta * 3)
        History.Render()
    end)
    frame:Hide()
end

function History.Toggle()
    if frame and frame:IsShown() then return frame:Hide() end
    if not frame then Build() end
    offset = 0
    frame:Show()
    History.Render()
end

NPP.Module("history", { "core" }, function()
    if NPP.Ledger and NPP.Ledger.OnBought then
        NPP.Ledger.OnBought(function() NPP.Safe("history", History.Render) end)
    end
end)
