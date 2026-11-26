-- Compat.lua: checks, once at load, every NaowhForever_Professions part this addon relies on.
-- These are Naowh's internal tables, not a public API: an update may rename them. A missing
-- part turns off only the feature that needs it, with one line in chat, instead of Lua errors.
local _, NPP = ...
local L = NPP.L

local Compat = {}
NPP.Compat = Compat

local ORDER = { "core", "sort", "filters", "ui", "scan", "live", "sell" }

local REQUIRE = {
    core = {
        { "ns.Professions.State", "table" },
        { "ns.Professions.Recipes.Reagents", "function" },
        { "ns.Professions.Recipes.OutputItem", "function" },
        { "ns.Professions.Recipes.Owned", "function" },
        { "ns.Professions.Prices.ClearCache", "function" },
        { "ns.Professions.Vendors.Price", "function" },
        { "_G.C_TradeSkillUI.GetRecipeSchematic", "function" },
    },
    sort = {
        { "ns.Professions.Entries.Build", "function" },
        { "ns.Professions.Entries.Collect", "function" },
        { "ns.Professions.Entries.IsCollapsed", "function" },
        { "ns.Professions.Entries.list", "table" },
        { "ns.Professions.Filters.Passes", "function" },
        { "_G.C_TradeSkillUI.GetAllRecipeIDs", "function" },
        { "_G.C_TradeSkillUI.GetRecipeInfo", "function" },
    },
    filters = {
        { "ns.Professions.Filters.Passes", "function" },
    },
    ui = {
        { "ns.Professions.Window.Build", "function" },
        { "ns.Professions.Window.Render", "function" },
        { "ns.Professions.List.Render", "function" },
        { "ns.Professions.Style.LEFT_W", "number" },
        { "ns.Professions.Style.FILTER_W", "number" },
        { "ns.Professions.Style.FILTER_GAP", "number" },
        { "_G.MenuUtil.CreateContextMenu", "function" },
    },
    scan = {
        { "_G.C_AuctionHouse.GetNumReplicateItems", "function" },
        { "_G.C_AuctionHouse.GetReplicateItemInfo", "function" },
    },
    live = {
        { "_G.C_AuctionHouse.SendSearchQuery", "function" },
        { "_G.C_AuctionHouse.MakeItemKey", "function" },
        { "_G.C_AuctionHouse.GetNumCommoditySearchResults", "function" },
        { "_G.C_AuctionHouse.GetCommoditySearchResultInfo", "function" },
        { "_G.C_AuctionHouse.GetNumItemSearchResults", "function" },
        { "_G.C_AuctionHouse.GetItemSearchResultInfo", "function" },
    },
    sell = {
        { "_G.C_Container.UseContainerItem", "function" },
        { "_G.C_Container.GetContainerNumSlots", "function" },
        { "_G.C_Container.GetContainerItemInfo", "function" },
        { "_G.MerchantFrame", "table" },
    },
}

local state, missing = {}, {}

local function Resolve(path)
    local t
    for part in path:gmatch("[^%.]+") do
        if t == nil then
            if part == "ns" then t = _G.NaowhForever elseif part == "_G" then t = _G else return nil end
        else
            if type(t) ~= "table" then return nil end
            t = t[part]
        end
    end
    return t
end
Compat.Resolve = Resolve

function Compat.Run()
    local ns = _G.NaowhForever
    NPP.ns = type(ns) == "table" and ns or nil
    NPP.P = NPP.ns and type(NPP.ns.Professions) == "table" and NPP.ns.Professions or nil
    if not NPP.P then
        for _, f in ipairs(ORDER) do state[f], missing[f] = false, { "NaowhForever.Professions" } end
        NPP.Print(L("NaowhForever_Professions was not found: the addon does nothing."))
        return
    end
    for _, f in ipairs(ORDER) do
        local miss = {}
        for _, req in ipairs(REQUIRE[f]) do
            if type(Resolve(req[1])) ~= req[2] then miss[#miss + 1] = req[1] end
        end
        missing[f] = miss
        state[f] = #miss == 0 and (f == "core" or state.core == true)
        if #miss > 0 then
            NPP.Print(L("'%s' is off: Naowh has changed (missing: %s). Send me /km status."),
                f, table.concat(miss, ", "))
        end
    end
end

function Compat.Ready(needs)
    for _, f in ipairs(needs or {}) do
        if not state[f] then return false end
    end
    return true
end

function Compat.Report()
    for _, f in ipairs(ORDER) do
        local miss = missing[f] or {}
        if state[f] then
            NPP.Print("  %s: |cff33ff33OK|r", f)
        else
            NPP.Print("  %s: |cffff4444OFF|r %s", f, #miss > 0 and table.concat(miss, ", ") or "(core)")
        end
    end
end
