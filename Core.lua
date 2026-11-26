-- Core.lua: namespace, saved settings, chat output, debug output, safe calls, module start-up.
local ADDON, NPP = ...
local L = NPP.L

_G.KisMax = NPP -- for /dump KisMax.db and similar
_G.NaowhProfessionsPlus = NPP -- old name
NPP.ADDON = ADDON

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
NPP.VERSION = (GetMeta and GetMeta(ADDON, "Version")) or "?"

NPP.DEFAULTS = {
    sortMode = "none",      -- "none" (Naowh order) | "profit" | "roi" | "total" (profit of the whole plan)
    sortDesc = true,        -- highest first
    flat = false,           -- learned recipes as one list, without categories
    sortUnlearned = true,   -- also sort inside the unlearned groups
    minProfit = false,      -- false = off, otherwise copper (can be 0)
    minROI = false,         -- false = off, otherwise percent
    hideUnknown = false,    -- hide recipes whose profit cannot be computed
    priceSource = "auto",   -- "auto" | "depth" | "tsm_chain" | "tsm_market" | "tsm_minbuyout" | "naowh"
    tsmPrice = "first(DBMarket, DBHistorical, DBRegionMarketAvg)", -- TSM custom price for tsm_chain
    tsmFallback = true,     -- the chosen source has no price -> our scan, then the Naowh scan
    depthPct = 10,          -- "depth" price: the price below which this % of the listed quantity sits
    saleChannel = "best",   -- "best" | "ah" | "vendor"
    chefPoints = "auto",    -- Master Chef ranks: "auto" (read from the Legacy tree) or 0-5
    chefCount = true,       -- count Master Chef's extra results (the "overproduction") in the yield
    chefTree = false,       -- pinned Legacy tree / node of Master Chef (/km chefnode)
    chefNode = false,
    planMax = 200,          -- most crafts a plan looks at
    planPanel = true,       -- "Buy plan" panel under the profession window
    limitByDemand = true,   -- auction plans: no more than TSM region sold-per-day * demandDays
    demandDays = 1,
    intermediates = "hour", -- reagents you can craft yourself: "hour" (if it raises gold per hour) | "cheap" | "off"
    exploreOnlyProfit = true, -- profession overview: only recipes with a profit
    exploreOnlySold = false,  -- (old)
    exploreMinSold = false,   -- profession overview: hide AH recipes TSM sells fewer than this per day (false = any)
    exploreChannel = "best",  -- profession overview's own sale channel: "best" | "ah" | "vendor" (merchant / disenchant)
    exploreMaxSkill = false,
    shopTarget = "npp",     -- "To shopping list" goes to "npp" (our list with price limits) or "naowh"
    fitText = true,
    ourProfitBlock = true,  -- our numbers in Naowh's Buy for / Sell for / Profit lines by the Create button
    feedNaowh = true,       -- when Naowh's full scan times out but ours read it: give Naowh the prices
    minimapButton = true,   -- KisMax button on the minimap
    minimapAngle = 220,
    deChannel = true,       -- disenchanting counts as a way to sell gear this character's Enchanting can take
    tooltipDE = true,       -- "KM disenchant" line on item tooltips
    levelAH = "off",        -- levelling plan: count auction sales "off" | "demand" (up to TSM sold per day)
    levelTarget = false,
    levelProf = false,      -- levelling plan profession (skill line id); false = the open one or your first
    levelVendor = true,     -- levelling plan: sell results to merchants
    levelDE = true,         -- levelling plan: disenchant results (if your Enchanting can)
    levelRecipesAH = true,  -- levelling plan: recipes may be bought on the AH    -- levelling plan target skill (false = the profession's current cap)         -- shrink button labels that do not fit (Naowh's buttons are sized for English)
    plansOnlyAtAH = true,   -- the list's plans follow bags and money only at the auction house or a merchant
    limitByBags = true,     -- a plan must fit in your free bag slots (purchases, then the crafted results)
    budget = "auto",        -- money for a plan's purchases: "auto" (gold on this character) | copper | false (no limit)
    column = true,          -- write our value into the list's right-hand column
    tooltip = true,         -- profit lines on the recipe tooltip
    lang = "auto",          -- "auto" | "ru" | "en"
    debug = false,
}

local PREFIX = "|cff33ccffKM|r: "
local DEBUG_PREFIX = "|cff999999KM debug:|r "

local function Out(msg)
    local frame = DEFAULT_CHAT_FRAME or _G.ChatFrame1
    if frame then frame:AddMessage(msg) end
end

-- string.format that never throws: nil/booleans/tables become text.
local function Format(fmt, ...)
    local n = select("#", ...)
    if n == 0 then return tostring(fmt) end
    local args = { ... }
    for i = 1, n do
        if type(args[i]) ~= "number" then args[i] = tostring(args[i]) end
    end
    local ok, text = pcall(string.format, tostring(fmt), unpack(args, 1, n))
    if ok then return text end
    return tostring(fmt) .. " [format error]"
end
NPP.Format = Format

function NPP.Print(fmt, ...)
    Out(PREFIX .. Format(fmt, ...))
end

function NPP.Debug(fmt, ...)
    if NPP.db and NPP.db.debug then Out(DEBUG_PREFIX .. Format(fmt, ...)) end
end

-- An error in our code is reported once per place: a chat line and BugSack (via the error handler).
local reported = {}
function NPP.Report(where, err)
    NPP.Debug("error in %s: %s", where, err)
    if reported[where] then return end
    reported[where] = true
    NPP.errorCount = (NPP.errorCount or 0) + 1
    NPP.Print(L("Error in '%s' (details in BugSack). The Naowh window keeps working."), where)
    local handler = geterrorhandler and geterrorhandler()
    if handler then pcall(handler, Format("KisMax [%s]: %s", where, err)) end
end

function NPP.Safe(where, fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if not ok then
        NPP.Report(where, a)
        return false
    end
    return true, a, b, c
end

function NPP.Get(key)
    local db = NPP.db
    if db then
        local v = db[key]
        if v ~= nil then return v end
    end
    return NPP.DEFAULTS[key]
end

-- Redraws Naowh's window if it is open. Window.Render clears the price caches,
-- rebuilds the list (our sort hook runs) and draws it (our column hook runs).
function NPP.Refresh(resetScroll)
    local P = NPP.P
    local W = P and P.State
    local win = W and W.frame
    if not (win and win:IsShown() and P.Window and P.Window.Render) then return end
    if resetScroll then W.offset = 0 end
    NPP.Safe("refresh", P.Window.Render)
end

function NPP.Set(key, value, noRefresh)
    if not NPP.db then return end
    NPP.db[key] = value
    NPP.Debug("set %s = %s", key, value)
    if key == "lang" then NPP.UpdateLanguage() end
    if NPP.Profit then NPP.Profit.ClearCache() end
    if NPP.UI and NPP.UI.UpdateLabel then NPP.UI.UpdateLabel() end
    if not noRefresh then NPP.Refresh(true) end
end

function NPP.ResetSettings()
    local kept = {} -- records, not settings: kept
    for _, k in ipairs({ "sellList", "ledger", "ledgerDays", "shop", "shopPos" }) do kept[k] = NPP.db[k] end
    for k in pairs(NPP.db) do NPP.db[k] = nil end
    for k, v in pairs(NPP.DEFAULTS) do NPP.db[k] = v end
    for k, v in pairs(kept) do NPP.db[k] = v end
    NPP.UpdateLanguage()
    if NPP.Profit then NPP.Profit.ClearCache() end
    if NPP.UI and NPP.UI.UpdateLabel then NPP.UI.UpdateLabel() end
    NPP.Refresh(true)
end

-- Naowh's ns.Button draws its text in btn.label; SetText on the button itself shows nothing there.
function NPP.SetButtonText(btn, text)
    if btn.label and btn.label.SetText then
        btn.label:SetText(text)
    else
        btn:SetText(text)
    end
end

-- Width of a font string's whole text (not cut to the width it was given).
local function TextWidth(fs)
    if not fs then return 0 end
    if fs.GetUnboundedStringWidth then return fs:GetUnboundedStringWidth() or 0 end
    local old = fs:GetWidth()
    fs:SetWidth(0)
    local w = fs:GetStringWidth() or 0
    fs:SetWidth(old)
    return w
end
NPP.TextWidth = TextWidth

-- Tables whose columns fit their text (Russian words are long): each column takes the width of its widest header
-- or shown cell, at least its base width (c.w) and at most c.max (default twice the base). Re-anchors the headers
-- (font strings, or buttons with .text) and each row's cells; returns the table's width.
function NPP.LayoutColumns(cols, headers, rows, left, headerY)
    local widths, total = {}, 0
    for j, c in ipairs(cols) do
        local w = c.w
        local h = headers[j]
        if h then w = math.max(w, TextWidth(h.text or h) + 10) end
        for _, r in ipairs(rows) do
            local fs = r.cells and r.cells[j]
            if fs and r:IsShown() then w = math.max(w, TextWidth(fs) + 10) end
        end
        w = math.ceil(math.min(w, c.max or c.w * 2))
        widths[j] = w
        total = total + w
    end
    local x = 0
    for j = 1, #cols do
        local w = widths[j]
        local h = headers[j]
        if h then
            local parent = h:GetParent()
            h:ClearAllPoints()
            if h.text then
                h:SetPoint("TOPLEFT", parent, "TOPLEFT", left + x, headerY)
                h:SetWidth(w)
                h.text:SetWordWrap(false)
            else
                h:SetPoint("TOPLEFT", parent, "TOPLEFT", left + x + 3, headerY)
                h:SetWidth(w - 6)
                h:SetWordWrap(false)
            end
        end
        for _, r in ipairs(rows) do
            local fs = r.cells and r.cells[j]
            if fs then
                fs:ClearAllPoints()
                fs:SetPoint("LEFT", r, "LEFT", x + 3, 0)
                fs:SetWidth(w - 6)
            end
        end
        x = x + w
    end
    for _, r in ipairs(rows) do r:SetWidth(total) end
    return total
end

-- A button as wide as its text (at least minW). The text is measured at its normal size: TextFit may have shrunk
-- the font to fit the old width, and measuring that would make the button grow a little on every redraw.
function NPP.FitButton(b, minW)
    if not b then return end
    local label = b.label or (b.GetFontString and b:GetFontString())
    local w = label and TextWidth(label)
    if not (w and w > 0) then return end
    local _, size = label:GetFont()
    local base = label.nppBaseSize
    if base and size and size > 0 and size < base then w = w * base / size end
    b:SetWidth(math.max(minW or 0, math.ceil(w + 24)))
end

function NPP.Coins(copper)
    if type(copper) ~= "number" then return "?" end
    local negative = copper < 0
    copper = math.floor(math.abs(copper) + 0.5)
    local text
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        text = C_CurrencyInfo.GetCoinTextureString(copper)
    elseif _G.GetCoinTextureString then
        text = _G.GetCoinTextureString(copper)
    else
        text = copper .. "c"
    end
    return negative and ("-" .. text) or text
end

-- Crafting right now (a recipe cast started or finished in the last few seconds). While crafting, bags change on
-- every craft and Naowh redraws its window each time: our counts then use what they already have (see Plan.For,
-- Profit's hook) and catch up once, after the crafting stops.
local CRAFT_GRACE = 4
local craftingUntil = 0
function NPP.Crafting() return GetTime() < craftingUntil end

-- Is this spell a profession recipe? C_TradeSkillUI.GetRecipeInfo answers for ordinary spells too (combat
-- abilities counted as "crafts"), so: a spell of Naowh's recipe data (every profession), or a recipe of the
-- profession open now (C_TradeSkillUI.GetAllRecipeIDs, read when its list changes).
local recipeSpells, openSpells = nil, {}
function NPP.IsRecipeSpell(spellID)
    if not spellID then return false end
    if recipeSpells == nil then
        recipeSpells = {}
        local ns = _G.NaowhForever
        local data = type(ns) == "table" and type(ns.RecipeData) == "table" and ns.RecipeData or {}
        for _, prof in pairs(data) do
            for _, r in ipairs(type(prof) == "table" and prof.recipes or {}) do
                if r.spell then recipeSpells[r.spell] = true end
            end
        end
    end
    return recipeSpells[spellID] == true or openSpells[spellID] == true
end

local listWatch = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_SHOW" }) do pcall(listWatch.RegisterEvent, listWatch, e) end
listWatch:SetScript("OnEvent", function()
    if not (C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs) then return end
    if C_TradeSkillUI.IsTradeSkillLinked and C_TradeSkillUI.IsTradeSkillLinked() then return end
    for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do openSpells[id] = true end
end)

local castWatch = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START" }) do
    pcall(castWatch.RegisterUnitEvent, castWatch, e, "player")
end
castWatch:SetScript("OnEvent", function(_, _, _, _, spellID)
    if NPP.IsRecipeSpell(spellID) then craftingUntil = GetTime() + CRAFT_GRACE end
end)

-- Modules register here and start after the saved variables are loaded,
-- only if the Naowh parts they need were found (see Compat.lua).
local modules = {}
function NPP.Module(name, needs, init)
    modules[#modules + 1] = { name = name, needs = needs, init = init }
end

local started = {}
function NPP.Started(name) return started[name] == true end

local function Start()
    if type(_G.KisMaxDB) ~= "table" then _G.KisMaxDB = {} end
    local db = _G.KisMaxDB
    for k, v in pairs(NPP.DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    NPP.db = db
    NPP.UpdateLanguage()
    NPP.Compat.Run()
    local names = {}
    for _, m in ipairs(modules) do
        if NPP.Compat.Ready(m.needs) then
            if NPP.Safe("start " .. m.name, m.init) then
                started[m.name] = true
                names[#names + 1] = m.name
            end
        else
            NPP.Debug("module %s not started: required Naowh parts missing", m.name)
        end
    end
    NPP.Debug("v%s loaded; modules: %s", NPP.VERSION, table.concat(names, ", "))
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    Start()
end)
