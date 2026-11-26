-- Sort.lua: reorders Naowh's recipe list after Naowh builds it.
-- P.Entries.list is one array: category headers ({ cat = ... }) followed by their recipes
-- ({ recipe = info } learned, { unlearned = r } not learned). We sort each run of recipes
-- between two headers in place, so categories and groups stay as Naowh made them.
-- Flat mode replaces the learned part with one sorted list without category headers.
local _, NPP = ...

local Sort = {}
NPP.Sort = Sort

local LEARNED_KEY, UNLEARNED_KEY = "profLearnedCollapsed", "profUnlearnedCollapsed"
local ROI_INF = 1e12
local now = debugprofilestop or function() return 0 end

local keys, names, ids = {}, {}, {}
local run, flatRun, flatPool, tail = {}, {}, {}, {}
local learnedInfos, infosDirty = {}, true
local desc = true
local stats = { sorted = 0, unknown = 0 }

local function KeyOf(e, mode)
    if mode == "none" then return nil end
    if mode == "total" then
        local p = NPP.Plan.ForEntry(e)
        if p and p.crafts > 0 then return p.profit end
        return nil
    end
    if mode == "hour" then
        local p = NPP.Plan.ForEntry(e)
        return p and p.hourly
    end
    local v = NPP.Profit.ForEntry(e)
    if not v then return nil end
    if mode == "profit" then return v.profit end
    if mode == "roi" then
        if v.roi then return v.roi end
        if v.roiInf then return ROI_INF end
    end
end

local function NameOf(e)
    if e.recipe then return (e.recipe.name or ""):lower(), e.recipe.recipeID or 0 end
    local spell = e.unlearned.spell or 0
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spell)
    return (name or ""):lower(), spell
end

-- Known values first (highest or lowest first), unknown last; ties by name, then id.
local function Less(a, b)
    local ka, kb = keys[a], keys[b]
    if ka ~= kb then
        if ka == nil then return false end
        if kb == nil then return true end
        if desc then return ka > kb end
        return ka < kb
    end
    local na, nb = names[a], names[b]
    if na ~= nb then return na < nb end
    return ids[a] < ids[b]
end

local function Prepare(e, mode)
    local k = KeyOf(e, mode)
    keys[e] = k
    names[e], ids[e] = NameOf(e)
    stats.sorted = stats.sorted + 1
    if k == nil then stats.unknown = stats.unknown + 1 end
end

local function SortSlice(list, i, j, mode)
    if j <= i then return end
    wipe(run)
    for k = i, j do
        local e = list[k]
        run[#run + 1] = e
        Prepare(e, mode)
    end
    table.sort(run, Less)
    for k = i, j do list[k] = run[k - i + 1] end
end

local function SameKind(e, kind)
    if kind == "recipe" then return e.recipe ~= nil end
    return e.unlearned ~= nil
end

local function SortRuns(list, mode, flat)
    local doLearned = mode ~= "none" and not flat -- flat mode sorts the learned part itself
    local doUnlearned = mode ~= "none" and NPP.Get("sortUnlearned")
    local n, i = #list, 1
    while i <= n do
        local e = list[i]
        local kind = (e.recipe and "recipe") or (e.unlearned and "unlearned") or nil
        if (kind == "recipe" and doLearned) or (kind == "unlearned" and doUnlearned) then
            local j = i
            while j < n and SameKind(list[j + 1], kind) do j = j + 1 end
            SortSlice(list, i, j, mode)
            i = j + 1
        else
            i = i + 1
        end
    end
end

-- Learned recipes of the open profession, read again after Naowh's Collect (new profession, skill-up...).
local function LearnedInfos()
    if not infosDirty then return learnedInfos end
    wipe(learnedInfos)
    for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
        local info = C_TradeSkillUI.GetRecipeInfo(id)
        if info and info.learned then
            info.numAvailable = nil -- as Naowh's Collect does: its count of craftable comes from the bags
            learnedInfos[#learnedInfos + 1] = info
        end
    end
    infosDirty = false
    NPP.Debug("flat: read %d learned recipes", #learnedInfos)
    return learnedInfos
end

-- Same search as Naowh's Entries (name, or a reagent's name).
local function Matches(info)
    local P = NPP.P
    local q = P.State.query or ""
    if q == "" then return true end
    if info.name and info.name:lower():find(q, 1, true) then return true end
    local ok, reagents = pcall(P.Recipes.Reagents, info.recipeID)
    if ok and type(reagents) == "table" then
        for _, r in ipairs(reagents) do
            local name = P.Recipes.ItemName and P.Recipes.ItemName(r.itemID)
            if name and name:lower():find(q, 1, true) then return true end
        end
    end
    return false
end

local function Flat(list, mode)
    local P = NPP.P
    local n, head = #list, nil
    for i = 1, n do
        local c = list[i].cat
        if c and c.key == LEARNED_KEY then head = i break end
    end
    if not head then return end -- no learned recipe passes the filters
    if P.Entries.IsCollapsed(list[head].cat) then return end
    local stop = n + 1
    for i = head + 1, n do
        local c = list[i].cat
        if c and c.key == UNLEARNED_KEY then stop = i break end
    end

    wipe(flatRun)
    for _, info in ipairs(LearnedInfos()) do
        if Matches(info) and P.Filters.Passes(info) then
            local e = flatPool[#flatRun + 1]
            if not e then
                e = {}
                flatPool[#flatRun + 1] = e
            end
            e.cat, e.unlearned, e.recipe = nil, nil, info
            flatRun[#flatRun + 1] = e
            Prepare(e, mode)
        end
    end
    table.sort(flatRun, Less)

    -- Rewrite the same table in place: Naowh's list file holds a reference to it.
    wipe(tail)
    for i = stop, n do tail[#tail + 1] = list[i] end
    local k = head
    for _, e in ipairs(flatRun) do
        k = k + 1
        list[k] = e
    end
    for _, e in ipairs(tail) do
        k = k + 1
        list[k] = e
    end
    for i = n, k + 1, -1 do list[i] = nil end
end

local function AfterBuild()
    local mode, flat = NPP.Get("sortMode"), NPP.Get("flat")
    if mode == "none" and not flat then return end
    local t0 = now()
    desc = NPP.Get("sortDesc")
    stats.sorted, stats.unknown = 0, 0
    local list = NPP.P.Entries.list
    if flat and not NPP.P.State.linked then Flat(list, mode) end
    SortRuns(list, mode, flat and not NPP.P.State.linked)
    wipe(keys)
    wipe(names)
    wipe(ids)
    NPP.Debug("sort %s%s%s: %d recipes, %d without value, %.1f ms", mode, desc and " desc" or " asc",
        flat and " flat" or "", stats.sorted, stats.unknown, now() - t0)
end

function Sort.Stats() return stats end

NPP.Module("sort", { "core", "sort" }, function()
    local E = NPP.P.Entries
    hooksecurefunc(E, "Collect", function() infosDirty = true end)
    hooksecurefunc(E, "Build", function() NPP.Safe("sort", AfterBuild) end)
end)
