-- Hub.lua: the KisMax window and its minimap button. Left: the tools (profession overview, levelling plan,
-- session plan, shopping list, history). Right: every setting that is not about sorting the list, in sections,
-- with on/off switches and value pickers (left click: next value, right click: previous).
-- The minimap button: left click opens this window, right click a short list of the tools; drag to move it.
local _, NPP = ...
local L = NPP.L

local Hub = {}
NPP.Hub = Hub

local GOLD = 10000
local WIDTH, HEIGHT = 820, 620
local LEFT_W = 260
local PAD = 14
local ROW_H = 24
local C_GOLD, C_GREY, C_GREEN = "|cffffd100", "|cff999999", "|cff4dd17a"

local frame, settingRows, minimapButton

---------------------------------------------------------------------------------------------------
-- Small widgets in Naowh's style
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

local function Panel(parent, alpha)
    local ns, T = NPP.ns, NPP.ns and NPP.ns.THEME
    if ns and ns.Solid and T then
        ns.Solid(parent, "BACKGROUND", T.bg, alpha or 0.96):SetAllPoints()
        if ns.Border then ns.Border(parent, T.line) end
    else
        local bg = parent:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.05, 0.07, alpha or 0.95)
    end
end

local function SetLabel(b, text)
    if NPP.SetButtonText then NPP.SetButtonText(b, text) elseif b.SetText then b:SetText(text) end
end

local function Help(region, title, text)
    if not text then return end
    region:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title, 1, 1, 1)
        GameTooltip:AddLine(text, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    region:HookScript("OnLeave", GameTooltip_Hide)
end

---------------------------------------------------------------------------------------------------
-- Tools
---------------------------------------------------------------------------------------------------

local function Shown(name)
    local f = _G[name]
    return f and f:IsShown()
end

local TOOLS = {
    { title = "Profession overview", text = "Every profession's recipes by profit per hour.", icon = "Interface\\Icons\\INV_Misc_Book_09",
      frame = "KisMaxExplorer", open = function() if NPP.Explorer then NPP.Explorer.Open() end end },
    { title = "Levelling plan", text = "The cheapest way to your target skill.", icon = "Interface\\Icons\\INV_Misc_Note_01",
      frame = "KisMaxLeveling", open = function() if NPP.Leveling then NPP.Leveling.Open() end end },
    { title = "Session plan", text = "Several profitable recipes with your money and bags.", icon = "Interface\\Icons\\INV_Misc_Coin_02",
      frame = "KisMaxSession", open = function() if NPP.Session then NPP.Session.Open() end end },
    { title = "KM shopping list", text = "What to buy, with the plans' price limits.", icon = "Interface\\Icons\\INV_Misc_Bag_10",
      frame = "KisMaxShop", open = function() if NPP.Shop then NPP.Shop.ShowPanel(true) end end },
    { title = "History by day", text = "What you spent and earned crafting.", icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
      frame = "KisMaxHistory", open = function() if NPP.History and not Shown("KisMaxHistory") then NPP.History.Toggle() end end },
}

-- A "back to KisMax" tab on the top edge of a tool's window (outside it, so it covers nothing of the window).
local function AttachBack(name)
    local f = _G[name]
    if not f or f.kmBack then return end
    local b = Button(f, "< KisMax", 90, 20, function()
        f:Hide()
        Hub.Open()
    end)
    b:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 2)
    if NPP.FitButton then NPP.FitButton(b, 80) end
    f.kmBack = b
end

-- A tool opens in place of the KisMax window.
function Hub.Launch(tool)
    if frame then frame:Hide() end
    NPP.Safe("hub tool", tool.open)
    if tool.frame then NPP.Safe("hub back", AttachBack, tool.frame) end
end

local function ToolCard(parent, tool, y)
    local card = CreateFrame("Button", nil, parent)
    card:SetSize(LEFT_W - PAD, 56)
    card:SetPoint("TOPLEFT", PAD, y)
    local bg = card:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 0.04)
    local hl = card:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0, 0.10)
    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("LEFT", 10, 0)
    icon:SetTexture(tool.icon)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local title = Font(card, 14)
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -1)
    title:SetPoint("RIGHT", -8, 0)
    title:SetJustifyH("LEFT")
    title:SetText(C_GOLD .. L(tool.title) .. "|r")
    local text = Font(card, 11)
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    text:SetPoint("RIGHT", -8, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    text:SetText(C_GREY .. L(tool.text) .. "|r")
    card:SetScript("OnClick", function() Hub.Launch(tool) end)
    return card
end

---------------------------------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------------------------------

local function PS() return NPP.PriceSource end

local BUDGETS = { "auto", false, 1 * GOLD, 5 * GOLD, 10 * GOLD, 25 * GOLD, 50 * GOLD, 100 * GOLD, 500 * GOLD }
local function BudgetText(v)
    if v == "auto" then return L("gold on the character") end
    if v == false then return L("no limit") end
    return NPP.Coins(v)
end

local INTER = { "hour", "cheap", "off" }
local INTER_TEXT = { hour = "Craft if it raises gold per hour", cheap = "Craft if it is cheaper", off = "Always buy" }

local CHEF = { "auto", 0, 1, 2, 3, 4, 5 }
local function ChefText(v)
    if v ~= "auto" then return tostring(v) end
    local ranks = NPP.Chef and NPP.Chef.AutoRanks and NPP.Chef.AutoRanks()
    return ranks and L("auto: %d"):format(ranks) or L("auto: not found")
end

local DISCOUNTS = { "auto", 0, 5, 10, 15, 20 }
local function DiscountText(v)
    if v ~= "auto" then return v .. "%" end
    local pct = NPP.Discount and NPP.Discount.Auto and NPP.Discount.Auto()
    return pct and L("auto: %d%%"):format(pct) or L("auto: not found")
end

local LANGS = { "auto", "ru", "en" }
local LANG_TEXT = { auto = "Game language", ru = "Russian", en = "English" }

-- kind "toggle": key; kind "cycle": key, values, text(v)
local SETTINGS = {
    { header = "Prices and selling" },
    { kind = "cycle", key = "priceSource", label = "Price source",
      values = { "auto", "depth", "tsm_chain", "tsm_market", "tsm_minbuyout", "naowh" }, text = function(v) return PS().Label(v) end },
    { kind = "cycle", key = "depthPct", label = "Quantity depth", values = { 1, 5, 10, 20, 30, 50 },
      text = function(v) return v .. "%" end, help = "DEPTH_HELP" },
    { kind = "toggle", key = "deChannel", label = "Count disenchanting (if your Enchanting can)" },
    { kind = "toggle", key = "tooltipDE", label = "Disenchant value on item tooltips" },
    { kind = "toggle", key = "tooltipFloor", label = "Cost and lowest AH price on crafted items' tooltips" },
    { kind = "toggle", key = "tooltipCheap", label = "\"Cheap now\" on reagent tooltips" },
    { kind = "cycle", key = "cheapPct", label = "Cheap means under the usual price by", values = { 20, 30, 40, 50 },
      text = function(v) return v .. "%" end },
    { kind = "toggle", key = "autoShopCheck", label = "At the AH: check the shopping list by itself" },
    { kind = "toggle", key = "feedNaowh", label = "Give our full scan to Naowh when its scan gives up", help = "FEED_HELP" },
    { header = "Buy plans" },
    { kind = "cycle", key = "budget", label = "Money for purchases", values = BUDGETS, text = BudgetText, help = "BUDGET_HELP" },
    { kind = "toggle", key = "limitByBags", label = "Fit in free bag slots", help = "BAGS_HELP" },
    { kind = "toggle", key = "limitByDemand", label = "Auction: no more than TSM sells per day", help = "DEMAND_HELP" },
    { kind = "cycle", key = "intermediates", label = "Intermediate reagents", values = INTER,
      text = function(v) return L(INTER_TEXT[v] or v) end, help = "INTER_HELP" },
    { kind = "toggle", key = "planPanel", label = "Buy plan panel under the window" },
    { kind = "toggle", key = "plansOnlyAtAH", label = "List plans follow bags only at the AH", help = "ATAH_HELP" },
    { kind = "cycle", key = "merchantDiscount", label = "Merchant discount (Legacy perk)", values = DISCOUNTS,
      text = DiscountText, help = "DISCOUNT_HELP" },
    { header = "Master Chef (cooking)" },
    { kind = "cycle", key = "chefPoints", label = "Ranks", values = CHEF, text = ChefText },
    { kind = "toggle", key = "chefCount", label = "Count overproduction (extra results)", help = "CHEF_HELP" },
    { header = "Interface" },
    { kind = "toggle", key = "column", label = "Show value in the list" },
    { kind = "toggle", key = "ourProfitBlock", label = "Our numbers in Buy for / Sell for / Profit by the Create button" },
    { kind = "toggle", key = "tooltip", label = "Lines on the recipe tooltip" },
    { kind = "toggle", key = "fitText", label = "Shrink text that does not fit the buttons", help = "FIT_HELP" },
    { kind = "toggle", key = "minimapButton", label = "Minimap button" },
    { kind = "cycle", key = "lang", label = "Language", values = LANGS, text = function(v) return L(LANG_TEXT[v] or v) end },
}

local function IndexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then return i end
    end
    return 1
end

local function Paint(row)
    local s = row.setting
    local v = NPP.Get(s.key)
    if s.kind == "toggle" then
        SetLabel(row.control, v and (C_GREEN .. L("On") .. "|r") or (C_GREY .. L("Off") .. "|r"))
    else
        SetLabel(row.control, s.text(v))
    end
end

function Hub.Render()
    if not (frame and frame:IsShown()) then return end
    for _, row in ipairs(settingRows) do
        if row.control then Paint(row) end
    end
    if minimapButton then
        if NPP.Get("minimapButton") then minimapButton:Show() else minimapButton:Hide() end
    end
end

local function OnControl(row, mouse)
    local s = row.setting
    if s.kind == "toggle" then
        NPP.Set(s.key, not NPP.Get(s.key))
    else
        local i = IndexOf(s.values, NPP.Get(s.key))
        i = mouse == "RightButton" and (i - 2) % #s.values + 1 or i % #s.values + 1
        NPP.Set(s.key, s.values[i])
    end
    Hub.Render()
end

local function Build()
    frame = CreateFrame("Frame", "KisMaxHub", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    Panel(frame)
    tinsert(UISpecialFrames, "KisMaxHub")

    local logo = frame:CreateTexture(nil, "ARTWORK")
    logo:SetSize(30, 30)
    logo:SetPoint("TOPLEFT", PAD, -PAD + 2)
    logo:SetTexture("Interface\\Icons\\INV_Misc_Coin_17")
    logo:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local title = Font(frame, 20)
    title:SetPoint("LEFT", logo, "RIGHT", 10, 4)
    title:SetText("|cff33ccffKis|r" .. C_GOLD .. "Max|r")
    local sub = Font(frame, 11)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    sub:SetText(C_GREY .. L("Profit, plans and trading for your professions") .. "  v" .. tostring(NPP.VERSION) .. "|r")
    local close = Button(frame, "X", 24, 22, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", -PAD, -PAD + 2)

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.08)
    divider:SetPoint("TOPLEFT", LEFT_W + 6, -60)
    divider:SetPoint("BOTTOMLEFT", LEFT_W + 6, PAD)
    divider:SetWidth(1)

    local tools = Font(frame, 13)
    tools:SetPoint("TOPLEFT", PAD, -66)
    tools:SetText(C_GOLD .. L("Tools") .. "|r")
    for i, tool in ipairs(TOOLS) do ToolCard(frame, tool, -88 - (i - 1) * 62) end

    local x0 = LEFT_W + 20
    local settingsTitle = Font(frame, 13)
    settingsTitle:SetPoint("TOPLEFT", x0, -66)
    settingsTitle:SetText(C_GOLD .. L("Settings") .. "|r")
    settingRows = {}
    local y = -88
    for _, s in ipairs(SETTINGS) do
        local row = CreateFrame("Frame", nil, frame)
        row:SetPoint("TOPLEFT", x0, y)
        row:SetPoint("RIGHT", -PAD, 0)
        row.setting = s
        if s.header then
            row:SetHeight(ROW_H)
            local h = Font(row, 12)
            h:SetPoint("BOTTOMLEFT", 0, 3)
            h:SetText(C_GOLD .. L(s.header) .. "|r")
            local line = row:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(1, 0.82, 0, 0.25)
            line:SetHeight(1)
            line:SetPoint("BOTTOMLEFT", 0, 1)
            line:SetPoint("BOTTOMRIGHT", 0, 1)
            y = y - ROW_H - 2
        else
            row:SetHeight(ROW_H - 2)
            local hl = row:CreateTexture(nil, "BACKGROUND")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.02)
            local label = Font(row, 12)
            label:SetPoint("LEFT", 6, 0)
            label:SetPoint("RIGHT", -180, 0)
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
            label:SetText(L(s.label))
            local w = s.kind == "toggle" and 70 or 170
            row.control = Button(row, "", w, 20, function() end)
            row.control:SetPoint("RIGHT", 0, 0)
            row.control:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row.control:SetScript("OnClick", function(_, mouse) NPP.Safe("hub setting", OnControl, row, mouse) end)
            local tip = s.help and L(s.help) or nil
            if s.kind == "cycle" then
                local hint = L("Left click: next value, right click: previous.")
                tip = tip and (tip .. "\n\n" .. hint) or hint
            end
            if tip then Help(row.control, L(s.label), tip) end
            y = y - ROW_H
        end
        settingRows[#settingRows + 1] = row
    end

    local reset = Button(frame, L("Reset settings"), 150, 24, function()
        NPP.ResetSettings()
        Hub.Render()
        NPP.Print(L("Settings reset."))
    end)
    reset:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    if NPP.FitButton then NPP.FitButton(reset, 120) end
    local hint = Font(frame, 11)
    hint:SetPoint("BOTTOMLEFT", PAD, PAD)
    hint:SetWidth(LEFT_W - PAD)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText(C_GREY .. L("/km - commands. Sorting and profit filters stay on the Sort button of the profession window.") .. "|r")
    -- tall enough for the longer column, the hint and the reset button
    local toolsBottom = 88 + #TOOLS * 62
    frame:SetHeight(math.max(-y, toolsBottom + hint:GetStringHeight() + 10) + PAD + 34)
    frame:Hide()
end

function Hub.Open()
    if not frame then Build() end
    frame:Show()
    Hub.Render()
end

function Hub.Toggle()
    if frame and frame:IsShown() then return frame:Hide() end
    Hub.Open()
end

---------------------------------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------------------------------

local function PlaceMinimap()
    local angle = math.rad(tonumber(NPP.Get("minimapAngle")) or 220)
    local r = (Minimap:GetWidth() / 2) + 6
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function DragUpdate(self)
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
    if NPP.db then NPP.db.minimapAngle = angle end
    PlaceMinimap()
end

local function ToolMenu(owner)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return Hub.Toggle() end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("KisMax")
        for _, tool in ipairs(TOOLS) do
            root:CreateButton(L(tool.title), function() Hub.Launch(tool) end)
        end
        root:CreateDivider()
        root:CreateButton(L("Settings") .. "...", Hub.Open)
    end)
end

local function BuildMinimap()
    if minimapButton or not Minimap then return end
    local b = CreateFrame("Button", "KisMaxMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_17")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    b:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" then ToolMenu(self) else Hub.Toggle() end
    end)
    b:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", DragUpdate) end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff33ccffKis|r|cffffd100Max|r")
        GameTooltip:AddLine(L("Left click: the KisMax window"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L("Right click: tools"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L("Drag: move the button"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    minimapButton = b
    PlaceMinimap()
    if not NPP.Get("minimapButton") then b:Hide() end
end

NPP.Module("hub", { "core" }, function()
    NPP.Safe("minimap button", BuildMinimap)
end)
