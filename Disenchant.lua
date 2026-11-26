-- Disenchant.lua: what an item is worth disenchanted, and whether this character can do it.
-- Outcomes (which dust / essence / shard, how many, how often) and the Enchanting skill an item needs come from
-- Naowh's disenchant tables (P.DisenchantValues); the materials are priced with our price source and the 5% AH cut.
-- Used by: the item tooltip line, the "disenchant" sale channel in Profit (when this character's Enchanting is high
-- enough), and the levelling plan (a crafted green can be disenchanted instead of sold).
local _, NPP = ...
local L = NPP.L

local DE = {}
NPP.DE = DE

local ENCHANTING = 333
local AH_CUT = 0.95

local cache = {}       -- [itemID] = { value, outcomes, skill } or false
local enchanting       -- this character's Enchanting skill (0 = none), nil = not read yet

local function Values()
    local P = NPP.P
    return P and type(P.DisenchantValues) == "table" and P.DisenchantValues or nil
end

-- This character's Enchanting skill; 0 without Enchanting.
function DE.Skill()
    if enchanting then return enchanting end
    local skill = 0
    if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, ENCHANTING)
        if ok and info and tonumber(info.skillLevel) and info.skillLevel > 0 then skill = info.skillLevel end
    end
    if skill == 0 and GetProfessions then
        for _, index in pairs({ GetProfessions() }) do
            local _, _, rank, _, _, _, line, modifier = GetProfessionInfo(index)
            if line == ENCHANTING then skill = (rank or 0) + (modifier or 0) end
        end
    end
    enchanting = skill
    return skill
end

local priceTable = setmetatable({}, { __index = function(_, id) return NPP.PriceSource.AH(id) end })

-- { value = copper after the AH cut (nil when a material has no price), outcomes, skill = Enchanting needed }
-- or nil when the item cannot be disenchanted (not gear, not green/blue/purple, or item data not loaded yet).
function DE.Info(itemID)
    if not itemID then return end
    local c = cache[itemID]
    if c ~= nil then return c or nil end
    local V = Values()
    if not V then return end
    local _, _, quality, level, _, _, _, _, equip, _, _, classID = C_Item.GetItemInfo(itemID)
    if not quality then
        if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
        return -- not cached: item data comes later
    end
    if not V.ItemTakes(itemID, classID, quality, equip) then
        cache[itemID] = false
        return
    end
    local outcomes = V.Outcomes(classID, quality, level)
    if not outcomes then
        cache[itemID] = false
        return
    end
    local gross = V.Expected(classID, quality, level, priceTable)
    c = { value = gross and math.floor(gross * AH_CUT) or nil, outcomes = outcomes, skill = V.RequiredSkill(level, quality) }
    cache[itemID] = c
    return c
end

-- Copper one item brings disenchanted (materials sold on the AH), if this character can disenchant it.
function DE.ValueFor(itemID)
    if not NPP.Get("deChannel") then return end
    local info = DE.Info(itemID)
    if not (info and info.value) then return end
    if (info.skill or 1) > DE.Skill() then return end
    return info.value
end

function DE.ClearCache()
    wipe(cache)
end

---------------------------------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------------------------------

local function ItemName(id) return NPP.Profit and NPP.Profit.ItemName(id) or tostring(id) end

-- A tree drawn with tiny inline textures (fonts may not have box-drawing characters): a grey trunk and a twig,
-- "├" for a row with more below it, "└" for the last row.
local LINE = "Interface\\Buttons\\WHITE8X8"
local TRUNK_FULL = ("|T%s:16:1:7:0:8:8:0:8:0:8:105:105:105|t"):format(LINE)
local TRUNK_HALF = ("|T%s:8:1:7:4:8:8:0:8:0:8:105:105:105|t"):format(LINE)
local TWIG = ("|T%s:1:8:0:0:8:8:0:8:0:8:105:105:105|t"):format(LINE)

local function Branch(last) return " " .. (last and TRUNK_HALF or TRUNK_FULL) .. TWIG .. " " end

local function Icon(itemID)
    local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
    return icon and ("|T%s:14:14:0:0:64:64:5:59:5:59|t "):format(icon) or ""
end

-- how likely: often / sometimes / rarely, coloured
local function Likely(pct)
    if pct >= 50 then return L("often"), 0.30, 0.82, 0.48 end
    if pct >= 15 then return L("sometimes"), 1.00, 0.82, 0.00 end
    return L("rarely"), 0.70, 0.70, 0.70
end

local function OnTooltip(tooltip, data)
    if not NPP.Get("tooltipDE") or tooltip ~= GameTooltip then return end
    local id = data and data.id
    if not id and tooltip.GetItem then
        local _, link = tooltip:GetItem()
        id = link and tonumber(link:match("item:(%d+)"))
    end
    local info = id and DE.Info(id)
    if not info then return end
    local mine = DE.Skill()
    local can = (info.skill or 1) <= mine
    local value = info.value and ("~" .. NPP.Coins(info.value)) or ("|cff888888" .. L("no price") .. "|r")
    local r, g, b = 0.70, 0.45, 1.00
    if not can then r, g, b = 0.55, 0.55, 0.55 end
    tooltip:AddDoubleLine("|TInterface\\Icons\\INV_Enchant_Disenchant:14:14:0:0:64:64:5:59:5:59|t " .. L("KM disenchant"),
        value, r, g, b, 1, 1, 1)
    local n = #info.outcomes
    for i, o in ipairs(info.outcomes) do
        local qty = o.minimum == o.maximum and tostring(o.minimum) or (o.minimum .. "-" .. o.maximum)
        local each = NPP.PriceSource.AH(o.itemID)
        local word, lr, lg, lb = Likely(o.chance)
        local left = Branch(i == n) .. Icon(o.itemID) .. ItemName(o.itemID) .. " |cffaaaaaax" .. qty .. "|r"
        local price = each and ("|cff999999" .. NPP.Coins(each) .. L(" each") .. "|r  ") or ""
        local chance = ("|cff%02x%02x%02x%s %s%%|r"):format(lr * 255, lg * 255, lb * 255, word,
            (o.chance == math.floor(o.chance)) and tostring(o.chance) or ("%.1f"):format(o.chance))
        tooltip:AddDoubleLine(left, price .. chance, 0.9, 0.9, 0.9, 1, 1, 1)
    end
    if not can then
        tooltip:AddLine("  " .. L("needs Enchanting %d (you: %d)"):format(info.skill or 1, mine), 0.6, 0.6, 0.6)
    end
end

NPP.Module("disenchant", { "core" }, function()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            NPP.Safe("disenchant tooltip", OnTooltip, tooltip, data)
        end)
    end
    local events = CreateFrame("Frame")
    for _, e in ipairs({ "SKILL_LINES_CHANGED", "TRADE_SKILL_LIST_UPDATE" }) do
        pcall(events.RegisterEvent, events, e)
    end
    events:SetScript("OnEvent", function() enchanting = nil end)
end)
