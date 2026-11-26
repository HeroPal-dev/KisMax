-- Filters.lua: our profit filters, added to Naowh's own.
-- Naowh's Entries.Build asks P.Filters.Passes(info, r) for every recipe, by field lookup at call time,
-- so wrapping that one function adds our rules to the learned and the unlearned recipes alike.
local _, NPP = ...

local Filters = {}
NPP.Filters = Filters

Filters.MIN_PROFIT = { false, 0, 1000, 5000, 10000, 50000, 100000, 500000 } -- copper
Filters.MIN_ROI = { false, 0, 10, 25, 50, 100, 200 } -- percent

function Filters.Active()
    local n = 0
    if NPP.Get("minProfit") ~= false then n = n + 1 end
    if NPP.Get("minROI") ~= false then n = n + 1 end
    if NPP.Get("hideUnknown") then n = n + 1 end
    return n
end

local warnedNoData = false

local function Ours(info, r)
    if Filters.Active() == 0 then return true end
    local P = NPP.P
    if P.State.linked then return true end -- someone else's profession: leave it as Naowh shows it
    if not NPP.PriceSource.HasData() then
        if not warnedNoData then
            warnedNoData = true
            NPP.Print(NPP.L("Profit filters are paused: no price data (scan the auction house first)."))
        end
        return true
    end
    local v
    if info then v = NPP.Profit.Get(info.recipeID) else v = NPP.Profit.Get(r.spell, r.item) end
    if NPP.Get("hideUnknown") and v.profit == nil then return false end
    local minProfit = NPP.Get("minProfit")
    if minProfit ~= false and not (v.profit and v.profit >= minProfit) then return false end
    local minROI = NPP.Get("minROI")
    if minROI ~= false and not (v.roiInf or (v.roi and v.roi >= minROI)) then return false end
    return true
end

NPP.Module("filters", { "core", "filters" }, function()
    local F = NPP.P.Filters
    if F.__nppOriginalPasses then return end -- already wrapped (should not happen)
    local original = F.Passes
    F.__nppOriginalPasses = original
    F.Passes = function(info, r)
        if not original(info, r) then return false end
        local ok, pass = pcall(Ours, info, r)
        if not ok then
            NPP.Report("filters", pass)
            return true
        end
        return pass
    end
end)
