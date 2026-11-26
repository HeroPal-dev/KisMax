-- Chef.lua: the Master Chef Legacy perk (Professions Legacy tree). Per rank, +10% chance that a
-- cooking craft gives its whole result twice, up to 5 ranks (50%). Expected yield = base * (1 + 0.1 * ranks).
-- Legacy perk trees are C_Traits trees (Naowh reads the Adventure tree 1188 the same way). The tree and
-- node IDs of Master Chef are not known to us, so the trees are searched once for a node by that name.
-- If that fails (e.g. a Russian name we do not know), /km perks lists the nodes and /km chefnode pins one,
-- or /km chef 0-5 sets the ranks by hand.
local _, NPP = ...

local Chef = {}
NPP.Chef = Chef

local PER_RANK = 0.10
local MAX_RANKS = 5
local TREE_FROM, TREE_TO = 1000, 1600
local COOKING_SKILL_LINE = 185
-- Matched in the name and in its lower-cased copy (string.lower changes ASCII letters only).
local NAME_PATTERNS = { "master chef", "шеф", "Шеф" }

local found, searched = nil, false

function Chef.Supported()
    return type(C_Traits) == "table" and type(C_Traits.GetConfigIDByTreeID) == "function"
        and type(C_Traits.GetTreeNodes) == "function" and type(C_Traits.GetNodeInfo) == "function"
        and type(C_Traits.GetEntryInfo) == "function" and type(C_Traits.GetDefinitionInfo) == "function"
end

local function ConfigID(treeID)
    local ok, configID = pcall(C_Traits.GetConfigIDByTreeID, treeID)
    if ok and configID then return configID end
end

local function NodeInfo(configID, nodeID)
    local ok, info = pcall(C_Traits.GetNodeInfo, configID, nodeID)
    if ok and type(info) == "table" then return info end
end

-- Name of a node: its definition's override name, or its spell's name.
local function NodeName(configID, info)
    for _, entryID in ipairs(info.entryIDs or {}) do
        local okE, entry = pcall(C_Traits.GetEntryInfo, configID, entryID)
        if okE and type(entry) == "table" and entry.definitionID then
            local okD, def = pcall(C_Traits.GetDefinitionInfo, entry.definitionID)
            if okD and type(def) == "table" then
                local name = def.overrideName
                if (not name or name == "") and def.spellID and C_Spell and C_Spell.GetSpellName then
                    name = C_Spell.GetSpellName(def.spellID)
                end
                if name and name ~= "" then return name, def.spellID end
            end
        end
    end
end

-- Calls fn(treeID, nodeID, name, info, spellID) for every node of every tree this character has;
-- fn returning true stops the walk.
function Chef.EachNode(fn)
    if not Chef.Supported() then return end
    for treeID = TREE_FROM, TREE_TO do
        local configID = ConfigID(treeID)
        if configID then
            local ok, nodes = pcall(C_Traits.GetTreeNodes, treeID)
            if ok and type(nodes) == "table" then
                for _, nodeID in ipairs(nodes) do
                    local info = NodeInfo(configID, nodeID)
                    if info then
                        local name, spellID = NodeName(configID, info)
                        if fn(treeID, nodeID, name, info, spellID) then return end
                    end
                end
            end
        end
    end
end

local function Matches(name)
    local lower = name:lower()
    for _, pattern in ipairs(NAME_PATTERNS) do
        if lower:find(pattern, 1, true) or name:find(pattern, 1, true) then return true end
    end
    return false
end

local function Search()
    searched, found = true, nil
    if not Chef.Supported() then
        NPP.Debug("chef: C_Traits is not available, use /km chef 0-5")
        return
    end
    local tree, node = NPP.Get("chefTree"), NPP.Get("chefNode")
    if tree and node then
        found = { tree = tree, node = node, pinned = true }
        NPP.Debug("chef: pinned node %s in tree %s", node, tree)
        return
    end
    local t0 = debugprofilestop()
    Chef.EachNode(function(treeID, nodeID, name)
        if name and Matches(name) then
            found = { tree = treeID, node = nodeID, name = name }
            return true
        end
    end)
    NPP.Debug("chef: search %.0f ms, %s", debugprofilestop() - t0,
        found and ("'" .. found.name .. "' tree " .. found.tree .. " node " .. found.node) or "not found")
end

-- Ranks from the game, or nil when the node cannot be read.
function Chef.AutoRanks()
    if not searched then Search() end
    if not found then return end
    local configID = ConfigID(found.tree)
    local info = configID and NodeInfo(configID, found.node)
    if not info then return end
    return info.activeRank or info.currentRank or 0, info.maxRanks
end

-- Ranks used in the math, and where they came from: "manual", "auto" or "none".
function Chef.Ranks()
    local manual = NPP.Get("chefPoints")
    if type(manual) == "number" then return math.max(0, math.min(MAX_RANKS, manual)), "manual" end
    local ranks = Chef.AutoRanks()
    if ranks then return math.min(MAX_RANKS, ranks), "auto" end
    return 0, "none"
end

function Chef.Found() return found end

function Chef.Rescan()
    searched, found = false, nil
end

function Chef.IsCooking()
    local P = NPP.P
    if P and P.State and P.State.linked then return false end -- someone else's perks are unknown
    local ok, base = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
    if not ok or type(base) ~= "table" then return false end
    if base.professionID == COOKING_SKILL_LINE then return true end
    if Enum and Enum.Profession and Enum.Profession.Cooking and base.profession == Enum.Profession.Cooking then
        return true
    end
    return _G.PROFESSIONS_COOKING ~= nil and base.professionName == _G.PROFESSIONS_COOKING
end

-- A Master Chef proc adds ONE more item to the craft (seen in game: a recipe making 2 gives 3, not 4), so it
-- adds on average PER_RANK * ranks items per craft, whatever the recipe's own yield.
-- Extra items per craft on average for the open profession, and the ranks behind it.
function Chef.Factor()
    if not NPP.Get("chefCount") or not Chef.IsCooking() then return 0, 0 end
    local ranks = Chef.Ranks()
    return PER_RANK * ranks, ranks
end

-- Cooking recipes by spell, from Naowh's recipe data; nil when that data is missing.
local cookingSpells
local function CookingSpells()
    if cookingSpells ~= nil then return cookingSpells or nil end
    local ns = NPP.ns
    local data = ns and type(ns.RecipeData) == "table" and ns.RecipeData[COOKING_SKILL_LINE]
    if not (data and type(data.recipes) == "table") then
        cookingSpells = false
        return nil
    end
    cookingSpells = {}
    for _, r in ipairs(data.recipes) do
        if r.spell then cookingSpells[r.spell] = true end
    end
    return cookingSpells
end

-- Extra items per craft on average for one recipe: Master Chef counts for cooking recipes whatever profession
-- is open (the profession overview counts every profession). Without Naowh's data: the open profession decides.
function Chef.FactorFor(recipeID)
    if not NPP.Get("chefCount") then return 0, 0 end
    local spells = CookingSpells()
    if not spells then return Chef.Factor() end
    if not spells[recipeID] then return 0, 0 end
    local P = NPP.P
    if P and P.State and P.State.linked then return 0, 0 end
    local ranks = Chef.Ranks()
    return PER_RANK * ranks, ranks
end

NPP.Module("chef", { "core" }, function()
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_CONFIG_LIST_UPDATED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event)
        if event == "TRAIT_CONFIG_LIST_UPDATED" and not found then searched = false end
        if NPP.Profit then NPP.Profit.ClearCache() end
    end)
end)
