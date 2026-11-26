-- Commands.lua: /km
local _, NPP = ...
local L = NPP.L

local GOLD = 10000

local function OnOff(v) return v and "|cff33ff33on|r" or "|cffff4444off|r" end

local function Help()
    NPP.Print(L("v%s. Commands:"), NPP.VERSION)
    NPP.Print(L("  /km status - what was found, prices, settings"))
    NPP.Print(L("  /km profit - profit breakdown of the selected recipe"))
    NPP.Print(L("  /km plan [add] - buy plan of the selected recipe (add: to Naowh's shopping list)"))
    NPP.Print(L("  /km lots - at the AH: refresh lots of the selected recipe; /km panel - plan panel on/off"))
    NPP.Print(L("  /km debug - debug output on/off"))
    NPP.Print(L("  /km sort none|profit|roi|total|hour, /km order (high/low first), /km flat"))
    NPP.Print(L("  /km minprofit <gold>|off, /km minroi <percent>|off, /km hideunknown"))
    NPP.Print(L("  /km channel best|ah|vendor|de - where the result is sold (de: disenchant it)"))
    NPP.Print(L("  /km chef auto|0-5, /km overprod (count Master Chef extras), /km perks [text], /km chefnode <id>|auto"))
    NPP.Print(L("  /km source auto|depth|tsm|tsmmarket|tsmmin|naowh, /km tsmprice <TSM price>"))
    NPP.Print(L("  /km depth <percent>, /km demand on|off|<days>, /km planmax <crafts>"))
    NPP.Print(L("  /km budget auto|off|<gold> - money a plan may spend"))
    NPP.Print(L("  /km inter hour|cheap|off - craft intermediate reagents yourself"))
    NPP.Print(L("  /km bags - plan fits in free bag slots on/off"))
    NPP.Print(L("  /km explore - profession overview: every profession's recipes by profit per hour"))
    NPP.Print(L("  /km shop [clear|naowh|km] - our shopping list (naowh/km: where To shopping list goes)"))
    NPP.Print(L("  /km history [reset] - what you spent and earned by day (reset: clear it)"))
    NPP.Print(L("  /km selftest - check everything KisMax relies on (send me a screenshot of it)"))
    NPP.Print(L("  /km session - session plan: several profitable recipes with your money and bag space"))
    NPP.Print(L("  /km level [target] - levelling plan: the cheapest way to the target skill"))
    NPP.Print(L("  /km ledger [reset] - what you really spent and earned (reset: start counting again)"))
    NPP.Print(L("  /km sell - at a merchant: sell the sell list; /km sell list|clear|add <item>|remove <item>"))
    NPP.Print(L("  /km column, /km lang auto|ru|en, /km reset"))
end

local function Status()
    local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    local naowhVersion = GetMeta and GetMeta("NaowhForever_Professions", "Version") or "?"
    NPP.Print(L("v%s, NaowhForever_Professions v%s, debug %s"), NPP.VERSION, naowhVersion, OnOff(NPP.Get("debug")))
    local P = NPP.P
    if P and type(P.On) == "function" then
        local ok, on = pcall(P.On)
        NPP.Print(L("  Naowh profession window: %s"), OnOff(ok and on))
    end
    NPP.Print(L("Naowh parts:"))
    NPP.Compat.Report()
    NPP.Print(L("Prices:"))
    NPP.PriceSource.Status()
    local minProfit, minROI = NPP.Get("minProfit"), NPP.Get("minROI")
    NPP.Print(L("Settings: sort %s, %s, flat %s, unlearned %s, column %s"), NPP.Get("sortMode"),
        NPP.Get("sortDesc") and L("high first") or L("low first"), OnOff(NPP.Get("flat")),
        OnOff(NPP.Get("sortUnlearned")), OnOff(NPP.Get("column")))
    NPP.Print(L("Filters: min profit %s, min ROI %s, hide unknown %s"),
        minProfit == false and L("off") or NPP.Coins(minProfit),
        minROI == false and L("off") or (minROI .. "%"), OnOff(NPP.Get("hideUnknown")))
    local ranks, how = NPP.Chef.Ranks()
    local found = NPP.Chef.Found()
    local where = ""
    if found then
        where = (" tree %d node %d%s"):format(found.tree, found.node, found.name and (" '" .. found.name .. "'") or "")
    end
    NPP.Print(L("Master Chef: %d ranks (%s)%s, overproduction counted %s, sell to %s"), ranks, how, where,
        OnOff(NPP.Get("chefCount")), NPP.Get("saleChannel"))
    NPP.Print(L("Plan: up to %d crafts, demand limit %s (%s days), depth %s%%"), NPP.Get("planMax"),
        OnOff(NPP.Get("limitByDemand")), NPP.Get("demandDays"), NPP.Get("depthPct"))
    local budget = NPP.Plan and NPP.Plan.Budget()
    NPP.Print(L("Money for purchases: %s (%s)"), budget and NPP.Coins(budget) or L("no limit"), tostring(NPP.Get("budget")))
    if NPP.Sort then
        local s = NPP.Sort.Stats()
        NPP.Print(L("Last sort: %d recipes, %d without value."), s.sorted, s.unknown)
    end
end

local function Selected()
    local P = NPP.P
    local W = P and P.State
    if not W then return end
    if W.selectedUnlearned then
        local r = W.selectedUnlearned
        return r.spell, r.item, C_Spell.GetSpellName(r.spell)
    end
    if W.selectedID then
        local info = C_TradeSkillUI.GetRecipeInfo(W.selectedID)
        return W.selectedID, nil, info and info.name
    end
end

local function ProfitBreakdown()
    if not NPP.Started("profit") then return NPP.Print(L("Profit calculation is off (see /km status).")) end
    local id, item, name = Selected()
    if not id then return NPP.Print(L("Open a profession and select a recipe first.")) end
    local v = NPP.Profit.Get(id, item, true)
    local PS = NPP.PriceSource
    NPP.Print("%s (recipe %s, item %s)", name or "?", id, v.output or "-")
    for _, part in ipairs(v.parts) do
        local price
        if part.owned then
            price = L("own (free)")
        elseif part.each then
            price = ("%s x%d = %s (%s)"):format(NPP.Coins(part.each), part.need, NPP.Coins(part.each * part.need),
                PS.Label(part.from))
            if part.craft and part.buyEach then
                price = price .. L(", buying: %s each"):format(NPP.Coins(part.buyEach))
            end
        else
            price = "|cffff4444" .. L("no price") .. "|r"
        end
        NPP.Print("  %s: %s", NPP.Profit.ItemName(part.itemID), price)
    end
    NPP.Print(L("  Reagents: %s%s"), NPP.Coins(v.cost), v.missing > 0 and (" + " .. v.missing .. " ?") or "")
    NPP.Print(L("  Yield: %s (base %s, Master Chef +%s, %d ranks)"), v.made, v.baseMade, v.extra or 0, v.chefRanks)
    if v.each then
        NPP.Print(L("  AH: %s each (%s), after 5%% cut: %s"), NPP.Coins(v.each), PS.Label(v.src), NPP.Coins(v.ahSale))
    end
    if v.vendorEach then
        NPP.Print(L("  Merchant: %s each, total %s"), NPP.Coins(v.vendorEach), NPP.Coins(v.vendorSale))
    end
    NPP.Print(L("  Sold to: %s"), v.channel or "-")
    if v.profit then
        NPP.Print(L("  Profit: %s, ROI: %s"), NPP.Coins(v.profit),
            v.roi and ("%.0f%%"):format(v.roi) or (v.roiInf and L("free") or "-"))
    end
    local reason = NPP.Profit.ReasonText(v)
    if reason then NPP.Print("  |cffff4444%s|r", reason) end
end

local INTER_TEXT = {
    hour = "craft if it raises gold per hour",
    cheap = "craft if it is cheaper",
    off = "always buy",
}

local function LedgerReport()
    local Ledger = NPP.Ledger
    local d = Ledger.Data()
    NPP.Print(L("Ledger since %s (%s ago):"), date("%d.%m %H:%M", d.started), NPP.PriceSource.Age(d.started))
    local net = d.vendorEarned + (d.ahEarned or 0) - d.ahSpent - d.vendorSpent
    if (d.ahEarned or 0) > 0 then NPP.Print(L("  Auction sales (mail): %s"), NPP.Coins(d.ahEarned)) end
    NPP.Print(L("  Spent: auction %s, merchant %s. Merchants paid %s. Money: %s"), NPP.Coins(d.ahSpent),
        NPP.Coins(d.vendorSpent), NPP.Coins(d.vendorEarned), (net >= 0 and "|cff4dd17a" or "|cffff5555") .. NPP.Coins(net) .. "|r")
    local rows = {}
    for recipeID in pairs(d.recipes) do
        local ok, r = pcall(Ledger.Recipe, recipeID)
        if ok and r then rows[#rows + 1] = r end
    end
    table.sort(rows, function(a, b) return a.net > b.net end)
    for _, r in ipairs(rows) do
        NPP.Print(L("  %s: crafted %d, sold %d for %s, reagents %s%s, result %s"), r.name or "?", r.crafts, r.sold,
            NPP.Coins(r.earned), r.estimated and "~" or "", NPP.Coins(r.cost),
            (r.net >= 0 and "|cff4dd17a" or "|cffff5555") .. NPP.Coins(r.net) .. "|r")
    end
    if #rows == 0 then NPP.Print(L("  No crafts recorded yet.")) end
    NPP.Print(L("  Not counted: auction sales (mail), deposits, repairs. ~ = some reagents at market price (none bought)."))
end

local function PlanCommand(rest)
    local id, item, name = Selected()
    if not id then return NPP.Print(L("Open a profession and select a recipe first.")) end
    local p = NPP.Plan.For(id, item)
    local v = p.v
    NPP.Print(L("Plan for %s (sell to %s, yield %s per craft):"), name or "?", v.channel or "-", v.made)
    if p.limit == "noprice" then
        return NPP.Print("  |cffff4444%s|r", NPP.Profit.ReasonText(v) or L("no prices"))
    end
    NPP.Print(L("  %d crafts, ~%s items. Cost %s, sale %s, profit %s. Stops at: %s."), p.crafts, p.units,
        NPP.Coins(p.cost), NPP.Coins(p.sale), NPP.Coins(p.profit), NPP.Plan.LimitText(p))
    if p.nextMargin then NPP.Print(L("  The next craft would make %s."), NPP.Coins(p.nextMargin)) end
    if p.crafts > 0 and p.seconds then
        NPP.Print(L("  Time: %s (%s s per craft%s), ~%s per hour."), NPP.Plan.TimeText(p.seconds), p.castTime,
            p.castGuess and L(", guessed") or "", NPP.Coins(p.perHour))
    end
    if p.budget then NPP.Print(L("  Money: pay %s of %s."), NPP.Coins(p.cash), NPP.Coins(p.budget)) end
    if p.freeCrafts and p.freeCrafts > p.crafts then
        NPP.Print(L("  With more money: %d crafts, profit %s, pay %s."), p.freeCrafts, NPP.Coins(p.freeProfit), NPP.Coins(p.freeCash))
    end
    if p.soldPerDay then NPP.Print(L("  TSM region sells ~%s per day."), ("%.1f"):format(p.soldPerDay)) end
    for _, b in ipairs(p.parts) do
        local bits = {}
        if b.own then bits[#bits + 1] = L("own") .. " " .. b.own end
        if (b.crafted or 0) > 0 then bits[#bits + 1] = L("craft %d yourself (%d crafts)"):format(b.crafted, b.crafts) end
        if (b.bags or 0) > 0 then bits[#bits + 1] = L("bags") .. " " .. b.bags end
        if (b.ah or 0) > 0 then
            bits[#bits + 1] = L("buy on the AH %d for %s (up to %s each)"):format(b.ah, NPP.Coins(b.ahCost),
                NPP.Coins(b.ahMax))
        end
        if (b.vendor or 0) > 0 then
            bits[#bits + 1] = L("buy from a merchant %d for %s"):format(b.vendor, NPP.Coins(b.vendorCost))
        end
        NPP.Print("  %s%s x%d: %s", b.sub and "  > " or "", NPP.Profit.ItemName(b.itemID), b.need, table.concat(bits, "; "))
    end
    if p.noDepth then NPP.Print(L("  Some reagents have no quantities: their price counts as unlimited.")) end
    if rest == "add" then
        if p.crafts < 1 then return NPP.Print(L("The plan for this recipe has no profitable crafts.")) end
        NPP.Plan.AddToShopping(id, p.crafts, p)
    end
end

local function Perks(filter)
    if not NPP.Chef.Supported() then return NPP.Print(L("C_Traits is not available here: use /km chef 0-5.")) end
    local shown = 0
    NPP.Chef.EachNode(function(treeID, nodeID, name, info)
        local match = filter == "" or (name and (name:lower():find(filter:lower(), 1, true) or name:find(filter, 1, true)))
        if match then
            shown = shown + 1
            if shown <= 60 then
                NPP.Print("  tree %d node %d: %s (%s/%s)", treeID, nodeID, name or "?",
                    info.activeRank or info.currentRank or 0, info.maxRanks or "?")
            end
        end
    end)
    NPP.Print(L("Nodes listed: %d. Pin Master Chef with /km chefnode <node>."), shown)
end

local function ChefNode(rest)
    if rest == "auto" then
        NPP.db.chefTree, NPP.db.chefNode = false, false
        NPP.Chef.Rescan()
        NPP.Set("chefPoints", "auto")
        return NPP.Print(L("Master Chef: searched for by name again."))
    end
    local node = tonumber(rest)
    if not node then return NPP.Print("/km chefnode <node>|auto") end
    local tree
    NPP.Chef.EachNode(function(treeID, nodeID)
        if nodeID == node then
            tree = treeID
            return true
        end
    end)
    if not tree then return NPP.Print(L("Node %d was not found in your Legacy trees (see /km perks)."), node) end
    NPP.db.chefTree, NPP.db.chefNode = tree, node
    NPP.Chef.Rescan()
    NPP.Set("chefPoints", "auto")
    NPP.Print(L("Master Chef pinned: tree %d node %d, ranks %s."), tree, node, NPP.Chef.AutoRanks() or "?")
end

local function Number(text)
    local cleaned = (text or ""):gsub(",", ".")
    return tonumber(cleaned)
end

local SOURCES = {
    auto = "auto", depth = "depth", naowh = "naowh",
    tsm = "tsm_chain", tsmmarket = "tsm_market", tsmmin = "tsm_minbuyout",
}

local function Handle(msg)
    local cmd, raw = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd, raw = (cmd or ""):lower(), raw or ""
    local rest = raw:lower()
    if cmd == "" then
        if NPP.Hub then return NPP.Hub.Toggle() end
        Help()
    elseif cmd == "help" then
        Help()
    elseif cmd == "selftest" or cmd == "test" then
        NPP.SelfTest.Run()
    elseif cmd == "status" then
        Status()
    elseif cmd == "debug" then
        NPP.Set("debug", not NPP.Get("debug"), true)
        NPP.Print(L("Debug output %s."), OnOff(NPP.Get("debug")))
    elseif cmd == "profit" then
        ProfitBreakdown()
    elseif cmd == "plan" then
        PlanCommand(rest)
    elseif cmd == "sort" then
        if rest ~= "none" and rest ~= "profit" and rest ~= "roi" and rest ~= "total" and rest ~= "hour" then
            return NPP.Print("/km sort none|profit|roi|total|hour")
        end
        NPP.Set("sortMode", rest)
        NPP.Print(L("Sort: %s."), rest)
    elseif cmd == "order" then
        NPP.Set("sortDesc", not NPP.Get("sortDesc"))
        NPP.Print(L("Order: %s."), NPP.Get("sortDesc") and L("high first") or L("low first"))
    elseif cmd == "flat" then
        NPP.Set("flat", not NPP.Get("flat"))
        NPP.Print(L("One list without categories %s."), OnOff(NPP.Get("flat")))
    elseif cmd == "minprofit" then
        if rest == "off" then
            NPP.Set("minProfit", false)
        else
            local gold = Number(rest)
            if not gold then return NPP.Print(L("Example: /km minprofit 2.5 (gold) or /km minprofit off")) end
            NPP.Set("minProfit", math.floor(gold * GOLD + 0.5))
        end
        NPP.Print(L("Min profit: %s."), NPP.Get("minProfit") == false and L("off") or NPP.Coins(NPP.Get("minProfit")))
    elseif cmd == "minroi" then
        if rest == "off" then
            NPP.Set("minROI", false)
        else
            local pct = Number(rest)
            if not pct then return NPP.Print(L("Example: /km minroi 30 or /km minroi off")) end
            NPP.Set("minROI", pct)
        end
        NPP.Print(L("Min ROI: %s."), NPP.Get("minROI") == false and L("off") or (NPP.Get("minROI") .. "%"))
    elseif cmd == "hideunknown" then
        NPP.Set("hideUnknown", not NPP.Get("hideUnknown"))
        NPP.Print(L("Hide recipes without a price %s."), OnOff(NPP.Get("hideUnknown")))
    elseif cmd == "channel" then
        if rest ~= "best" and rest ~= "ah" and rest ~= "vendor" and rest ~= "de" then
            return NPP.Print("/km channel best|ah|vendor|de")
        end
        NPP.Set("saleChannel", rest)
        NPP.Print(L("Sell to: %s."), rest)
    elseif cmd == "chef" then
        local n = tonumber(rest)
        if rest == "auto" then
            NPP.Set("chefPoints", "auto")
        elseif n and n >= 0 and n <= 5 then
            NPP.Set("chefPoints", math.floor(n))
        else
            return NPP.Print("/km chef auto|0-5")
        end
        local ranks, how = NPP.Chef.Ranks()
        NPP.Print(L("Master Chef: %d ranks (%s)."), ranks, how)
    elseif cmd == "overprod" then
        NPP.Set("chefCount", not NPP.Get("chefCount"))
        NPP.Print(L("Master Chef extra results counted %s."), OnOff(NPP.Get("chefCount")))
    elseif cmd == "perks" then
        Perks(raw)
    elseif cmd == "chefnode" then
        ChefNode(rest)
    elseif cmd == "source" then
        local key = SOURCES[rest]
        if not key then return NPP.Print("/km source auto|depth|tsm|tsmmarket|tsmmin|naowh") end
        NPP.Set("priceSource", key)
        NPP.Print(L("Price source: %s."), NPP.PriceSource.Label(key))
        if key:find("^tsm") and not NPP.PriceSource.TSMAvailable() then
            NPP.Print(L("TradeSkillMaster is not loaded: the Naowh scan is used."))
        end
    elseif cmd == "tsmprice" then
        if raw == "" then
            return NPP.Print(L("TSM price chain: %s. Example: /km tsmprice first(DBMarket, DBHistorical)"),
                NPP.Get("tsmPrice"))
        end
        NPP.Set("tsmPrice", raw)
        NPP.Print(L("TSM price chain: %s."), raw)
    elseif cmd == "depth" then
        local pct = Number(rest)
        if not pct or pct <= 0 or pct > 100 then return NPP.Print("/km depth <1-100>") end
        NPP.Set("depthPct", pct)
        NPP.Print(L("Quantity depth: %s%%."), pct)
    elseif cmd == "demand" then
        local days = Number(rest)
        if rest == "on" or rest == "off" then
            NPP.Set("limitByDemand", rest == "on")
        elseif days and days > 0 then
            NPP.db.demandDays = days
            NPP.Set("limitByDemand", true)
        else
            return NPP.Print("/km demand on|off|<days>")
        end
        NPP.Print(L("Demand limit %s, %s days."), OnOff(NPP.Get("limitByDemand")), NPP.Get("demandDays"))
    elseif cmd == "ledger" then
        if not (NPP.Ledger and NPP.Started("ledger")) then return NPP.Print(L("The ledger is off (see /km status).")) end
        if rest == "reset" then
            NPP.Ledger.Reset()
            if NPP.PlanPanel then NPP.PlanPanel.Render() end
            return NPP.Print(L("Ledger reset: counting from now."))
        end
        LedgerReport()
    elseif cmd == "sell" then
        if not (NPP.Sell and NPP.Started("sell")) then return NPP.Print(L("Selling is off (see /km status).")) end
        local sub, arg = (rest or ""):match("^(%S*)%s*(.-)$")
        if sub == "" then
            NPP.Sell.Run()
        elseif sub == "list" then
            local any = false
            for id in pairs(NPP.Sell.List()) do
                any = true
                NPP.Print("  %s (%d)", NPP.Profit.ItemName(id), id)
            end
            if not any then NPP.Print(L("The sell list is empty: add items on the Buy plan panel.")) end
        elseif sub == "clear" then
            wipe(NPP.Sell.List())
            NPP.Sell.Update()
            if NPP.PlanPanel then NPP.PlanPanel.Render() end
            NPP.Print(L("Sell list cleared."))
        elseif sub == "add" or sub == "remove" then
            local id = tonumber(arg:match("item:(%d+)") or arg:match("^(%d+)$"))
            if not id then return NPP.Print("/km sell " .. sub .. " <itemID|link>") end
            NPP.Sell.Set(id, sub == "add")
        else
            return NPP.Print("/km sell [list|clear|add <item>|remove <item>]")
        end
    elseif cmd == "shop" then
        if not (NPP.Shop and NPP.Started("shop")) then return NPP.Print(L("The shopping list is off (see /km status).")) end
        if rest == "clear" then
            NPP.Shop.Clear()
            return NPP.Print(L("Shopping list cleared."))
        elseif rest == "naowh" or rest == "npp" or rest == "km" then
            NPP.Set("shopTarget", rest == "naowh" and "naowh" or "npp", true)
            return NPP.Print(L("To shopping list now goes to: %s."), rest == "naowh" and "Naowh" or "KisMax")
        end
        NPP.Shop.TogglePanel()
    elseif cmd == "level" then
        if not (NPP.Leveling and NPP.Started("leveling")) then return NPP.Print(L("The levelling plan is off (see /km status).")) end
        local t = tonumber(rest)
        if t then NPP.Set("levelTarget", t, true) end
        NPP.Leveling.Toggle()
    elseif cmd == "session" then
        if not (NPP.Session and NPP.Started("session")) then return NPP.Print(L("The session plan is off (see /km status).")) end
        NPP.Session.Toggle()
    elseif cmd == "history" then
        if not (NPP.History and NPP.Started("history")) then return NPP.Print(L("The history is off (see /km status).")) end
        if rest == "reset" then
            NPP.Ledger.ResetDays()
            NPP.History.Render()
            return NPP.Print(L("History cleared: counting from now."))
        end
        NPP.History.Toggle()
    elseif cmd == "explore" then
        if not (NPP.Explorer and NPP.Started("explorer")) then return NPP.Print(L("The overview is off (see /km status).")) end
        NPP.Explorer.Toggle()
    elseif cmd == "bags" then
        NPP.Set("limitByBags", not NPP.Get("limitByBags"))
        NPP.Print(L("Bag space limit %s (%s free slots)."), OnOff(NPP.Get("limitByBags")), NPP.Plan.FreeSlots() or "?")
    elseif cmd == "inter" then
        if rest ~= "hour" and rest ~= "cheap" and rest ~= "off" then return NPP.Print("/km inter hour|cheap|off") end
        NPP.Set("intermediates", rest)
        NPP.Print(L("Intermediate reagents: %s."), L(INTER_TEXT[rest]))
    elseif cmd == "budget" then
        local gold = Number(rest)
        if rest == "auto" then
            NPP.Set("budget", "auto")
        elseif rest == "off" then
            NPP.Set("budget", false)
        elseif gold and gold >= 0 then
            NPP.Set("budget", math.floor(gold * 10000 + 0.5))
        else
            return NPP.Print("/km budget auto|off|<gold>")
        end
        local budget = NPP.Plan.Budget()
        NPP.Print(L("Money for purchases: %s (%s)"), budget and NPP.Coins(budget) or L("no limit"), tostring(NPP.Get("budget")))
    elseif cmd == "planmax" then
        local n = Number(rest)
        if not n or n < 1 then return NPP.Print("/km planmax <crafts>") end
        NPP.Set("planMax", math.floor(n))
        NPP.Print(L("Plan looks at up to %d crafts."), NPP.Get("planMax"))
    elseif cmd == "lots" then
        if not NPP.Started("live") then return NPP.Print(L("Live lots are off (see /km status).")) end
        local id, item = Selected()
        if not id then return NPP.Print(L("Open a profession and select a recipe first.")) end
        NPP.Live.RefreshRecipe(id, item)
    elseif cmd == "panel" then
        NPP.Set("planPanel", not NPP.Get("planPanel"))
        NPP.Print(L("Buy plan panel %s."), OnOff(NPP.Get("planPanel")))
        if NPP.PlanPanel then NPP.PlanPanel.Render() end
    elseif cmd == "column" then
        NPP.Set("column", not NPP.Get("column"))
        NPP.Print(L("Value in the list %s."), OnOff(NPP.Get("column")))
    elseif cmd == "lang" then
        if rest ~= "auto" and rest ~= "ru" and rest ~= "en" then return NPP.Print("/km lang auto|ru|en") end
        NPP.Set("lang", rest)
        NPP.Print(L("Language: %s."), rest)
    elseif cmd == "reset" then
        NPP.ResetSettings()
        NPP.Print(L("Settings reset."))
    else
        Help()
    end
end

SLASH_KISMAX1 = "/km"
SLASH_KISMAX2 = "/kismax"
SLASH_KISMAX3 = "/npp" -- the old name still works
SlashCmdList.KISMAX = function(msg)
    if not NPP.db then return NPP.Print("not loaded yet") end
    NPP.Safe("command", Handle, msg)
end
