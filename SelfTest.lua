-- SelfTest.lua: /km selftest - every part KisMax relies on, checked in one go, one line each in chat:
-- Naowh's version and the parts we hook, our features and modules, prices (TSM, scans), the character's
-- professions, and our records. OK / ? (works, but something is missing) / FAIL. A screenshot of it after a
-- Naowh update shows at once what broke.
local _, NPP = ...
local L = NPP.L

local SelfTest = {}
NPP.SelfTest = SelfTest

local OK, WARN, FAIL = "|cff4dd17aOK|r", "|cffffd100 ?|r", "|cffff5555FAIL|r"

local function Meta(addon, field)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    return get and get(addon, field)
end

local function Path(root, path)
    local t = root
    for part in path:gmatch("[^%.]+") do
        if type(t) ~= "table" then return nil end
        t = t[part]
    end
    return t
end

function SelfTest.Run()
    local counts = { ok = 0, warn = 0, fail = 0 }
    local function Line(state, text, ...)
        local mark = state == true and OK or state == nil and WARN or FAIL
        counts[state == true and "ok" or state == nil and "warn" or "fail"] = counts[state == true and "ok" or state == nil and "warn" or "fail"] + 1
        NPP.Print("%s %s", mark, NPP.Format(text, ...))
    end
    NPP.Print(L("KisMax %s self-test:"), tostring(NPP.VERSION))

    -- Naowh
    local core, prof = Meta("NaowhForever", "Version"), Meta("NaowhForever_Professions", "Version")
    Line(core ~= nil and prof ~= nil, L("Naowh Forever %s, Professions %s"), core or "-", prof or "-")
    local ns, P = NPP.ns, NPP.P
    local parts = {
        { P, "Lines.RenderProfit", "function" }, { P, "Shopping.AddItem", "function" }, { P, "Shopping.Makes", "function" },
        { P, "CraftQueue.Add", "function" }, { ns, "OpenCraftQueue", "function" }, { P, "DisenchantValues.Outcomes", "function" },
        { ns, "RecipeData", "table" }, { ns, "PlaceWaypoint", "function" }, { P, "CooldownRecipes", "table" },
        { ns, "AccountSettings", "function" }, { ns, "AuctionPrice", "function" },
    }
    local missing = {}
    for _, p in ipairs(parts) do
        if type(Path(p[1], p[2])) ~= p[3] then missing[#missing + 1] = p[2] end
    end
    Line(#missing == 0 or nil, L("Naowh parts we use: %d of %d%s"), #parts - #missing, #parts,
        #missing > 0 and (" (" .. L("missing") .. ": " .. table.concat(missing, ", ") .. ")") or "")

    -- our features (Compat) and modules
    for _, f in ipairs({ "core", "sort", "filters", "ui", "scan", "live", "sell" }) do
        local state -- off: "?" for one feature, FAIL for the core (nothing works without it)
        if NPP.Compat.Ready({ f }) then state = true elseif f == "core" then state = false end
        Line(state, L("Feature %s"), f)
    end
    local mods = { "profit", "chef", "disenchant", "ledger", "planpanel", "explorer", "history", "session", "leveling",
        "shop", "hub", "ui", "sort", "filters", "scan", "live", "sell", "pricefloor" }
    local off = {}
    for _, m in ipairs(mods) do
        if not NPP.Started(m) then off[#off + 1] = m end
    end
    Line(#off == 0 or nil, L("Modules started: %d of %d%s"), #mods - #off, #mods,
        #off > 0 and (" (" .. L("off") .. ": " .. table.concat(off, ", ") .. ")") or "")

    -- prices
    local PS = NPP.PriceSource
    local tsm = PS.TSMAvailable and PS.TSMAvailable()
    Line(tsm and true or nil, tsm and L("TradeSkillMaster prices available") or L("TradeSkillMaster not loaded: no TSM prices or sales per day"))
    local linen, from = PS.AH(2589)
    Line(linen and true or nil, L("Price of Linen Cloth: %s (%s)"), linen and NPP.Coins(linen) or L("no price"), from and PS.Label(from) or "-")
    local scanAge = PS.ScanAge and PS.ScanAge()
    Line(scanAge and true or nil, scanAge and L("Our full scan: %s ago, %d items") or L("No full scan of ours yet"), scanAge or "", NPP.Scan.Count() or 0)
    local naowhAge = PS.NaowhAge and PS.NaowhAge()
    Line(naowhAge and true or nil, naowhAge and L("Naowh's scan: %s ago") or L("No Naowh scan yet"), naowhAge or "")

    -- character
    local profs = {}
    if GetProfessions then
        for _, index in pairs({ GetProfessions() }) do
            local name, _, skill, cap = GetProfessionInfo(index)
            if name then profs[#profs + 1] = ("%s %d/%d"):format(name, skill or 0, cap or 0) end
        end
    end
    Line(#profs > 0 or nil, L("Professions: %s"), #profs > 0 and table.concat(profs, ", ") or "-")
    local makes = 0
    local okM, m = pcall(function() return P.Shopping.Makes() end)
    if okM and type(m) == "table" then for _ in pairs(m) do makes = makes + 1 end end
    Line(makes > 0 or nil, L("Recipes Naowh remembers for this character: %d%s"), makes,
        makes == 0 and (" (" .. L("open each profession once") .. ")") or "")
    Line(true, L("Enchanting %d, Master Chef ranks %s"), NPP.DE and NPP.DE.Skill() or 0,
        tostring(NPP.Chef and NPP.Chef.Ranks and NPP.Chef.Ranks() or "-"))

    -- our records
    local days, shop, sell = 0, 0, 0
    for _ in pairs(NPP.Ledger and NPP.Ledger.Days() or {}) do days = days + 1 end
    if NPP.Shop then shop = #NPP.Shop.Entries() end
    if NPP.Sell then for _ in pairs(NPP.Sell.List()) do sell = sell + 1 end end
    Line(true, L("Records: %d days of history, %d items on the shopping list, %d on the sell list"), days, shop, sell)
    Line((NPP.errorCount or 0) == 0 or false, L("Errors since loading: %d%s"), NPP.errorCount or 0,
        (NPP.errorCount or 0) > 0 and (" (" .. L("details in BugSack") .. ")") or "")

    NPP.Print(L("Self-test: %d OK, %d to look at, %d failed."), counts.ok, counts.warn, counts.fail)
end
