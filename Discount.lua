-- Discount.lua: the Legacy perk that lowers merchant prices (10%). Found in the Legacy trees the way Master Chef
-- is (Chef.EachNode): a node whose name, or its spell's description, speaks of merchants and prices. Its percent
-- comes from the description (the first "N%"): on Forever 2 ranks of 5%, so 5 per rank, 10 in all.
-- Setting merchantDiscount: "auto" (the perk), or 0-50 typed by hand (/km discount).
-- Used for: merchant reagents in every price (Naowh's built-in list prices, minus the discount; prices Naowh saw at
-- a merchant are shown prices, the discount already in them) and recipes bought from merchants in the levelling plan.
local _, NPP = ...
local L = NPP.L

local Discount = {}
NPP.Discount = Discount

local DEFAULT_PCT = 10   -- the whole perk
local PER_RANK_PCT = 5   -- one rank of it (2 ranks)
local MAX_PCT = 50
-- names: matched in the name and its lower-cased copy (string.lower changes ASCII letters only)
local NAME_PATTERNS = { "bargain", "haggl", "barter", "discount", "merchant", "vendor", "thrift",
    "скидк", "Скидк", "торг", "Торг", "сделк", "Сделк", "бартер", "Бартер", "купец", "Купец" }
-- descriptions: one word about merchants and one about prices
local DESC_WHO = { "merchant", "vendor", "торговц", "Торговц", "торговец", "Торговец" }
local DESC_WHAT = { "price", "cost", "cheaper", "discount", "цен", "Цен", "стоимост", "скидк", "дешевл" }

local found, searched = nil, false

local function Has(text, list)
    if not text or text == "" then return false end
    local lower = text:lower()
    for _, p in ipairs(list) do
        if lower:find(p, 1, true) or text:find(p, 1, true) then return true end
    end
    return false
end

local function Description(spellID)
    if not spellID then return end
    local get = C_Spell and C_Spell.GetSpellDescription or GetSpellDescription
    if not get then return end
    local ok, text = pcall(get, spellID)
    if ok and type(text) == "string" and text ~= "" then return text end
end

local function Search()
    searched, found = true, nil
    if not (NPP.Chef and NPP.Chef.Supported()) then return end
    local t0 = debugprofilestop()
    NPP.Chef.EachNode(function(treeID, nodeID, name, info, spellID)
        local desc = Description(spellID)
        local byDesc = desc and Has(desc, DESC_WHO) and Has(desc, DESC_WHAT)
        if byDesc or (name and Has(name, NAME_PATTERNS) and (not desc or Has(desc, DESC_WHAT))) then
            found = { tree = treeID, node = nodeID, name = name or "?", spell = spellID, desc = desc }
            return true
        end
    end)
    NPP.Debug("discount: search %.0f ms, %s", debugprofilestop() - t0,
        found and ("'" .. found.name .. "' tree " .. found.tree .. " node " .. found.node) or "not found")
end

-- The perk's percent from the game, its ranks and name; nil when it is not found.
function Discount.Auto()
    if not searched then Search() end
    if not found then return end
    local okC, configID = pcall(C_Traits.GetConfigIDByTreeID, found.tree)
    local ok, info = false, nil
    if okC and configID then ok, info = pcall(C_Traits.GetNodeInfo, configID, found.node) end
    if not ok or type(info) ~= "table" then return end
    local ranks, maxRanks = info.activeRank or info.currentRank or 0, info.maxRanks or 1
    -- the perk on Forever: 2 ranks of 5% (10% in all). The spell's description gives one rank's percent.
    local per = tonumber(found.desc and found.desc:match("(%d+)%%"))
    if not per or per <= 0 then per = maxRanks > 1 and PER_RANK_PCT or DEFAULT_PCT end
    -- a description that shows the whole perk (10% at 2 ranks) would count twice: never above 5% per rank there
    if maxRanks > 1 and per * maxRanks > DEFAULT_PCT then per = DEFAULT_PCT / maxRanks end
    local pct = ranks > 0 and per * (maxRanks > 1 and ranks or 1) or 0
    return math.min(MAX_PCT, pct), ranks, maxRanks, found.name, per
end

-- Percent used in the math, and where it came from: "manual", "auto" or "none".
function Discount.Percent()
    local manual = NPP.Get("merchantDiscount")
    if type(manual) == "number" then return math.max(0, math.min(MAX_PCT, manual)), "manual" end
    local pct = Discount.Auto()
    if pct then return pct, "auto" end
    return 0, "none"
end

-- What a merchant asks per copper of list price (0.9 with 10% off).
function Discount.Factor()
    return 1 - Discount.Percent() / 100
end

function Discount.Found() return found end

function Discount.Rescan() searched, found = false, nil end

-- One line for /km discount and the self-test.
function Discount.Text()
    local pct, how = Discount.Percent()
    if how == "manual" then return L("%d%% (typed by hand)"):format(pct) end
    if how == "auto" then
        local _, ranks, maxRanks, name, per = Discount.Auto()
        return L("%d%% (perk \"%s\", rank %d/%d, %s%% each)"):format(pct, name or "?", ranks or 0, maxRanks or 1,
            tostring(per or "?"))
    end
    return L("none (perk not found or not taken)")
end

NPP.Module("discount", { "core" }, function()
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_CONFIG_LIST_UPDATED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event)
        if event == "TRAIT_CONFIG_LIST_UPDATED" and not found then searched = false end
        if NPP.PriceSource and NPP.PriceSource.ClearCache then NPP.PriceSource.ClearCache() end
    end)
end)
