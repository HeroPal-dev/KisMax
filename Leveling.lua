-- Leveling.lua: "Levelling plan" - the cheapest way from your skill to a target skill at today's prices.
-- Profession: chosen with the tabs (your professions, or any other one to plan learning it); the profession window
-- need not be open. Learned recipes: the open window's, or those Naowh remembers for this character (profMakes).
-- Past the current cap the plan adds the trainer ranks (Journeyman, Expert, ...) with their price.
-- Recipes: every recipe of that profession in Naowh's recipe data (learned or not). Not learned ones cost their
-- price once: trainer, merchant (your faction) or, if allowed, the recipe item on the AH; recipes you cannot get
-- that way (drops, quests not on the AH) are left out. Colours: orange from the recipe's skill, yellow, grey (data),
-- green halfway. A point: orange = every craft; yellow and green = (grey - skill) / (grey - yellow) of the crafts.
-- Reagents come from one shared supply, as in the buy plans: your bags first, then the auction lots cheapest first
-- (so the price rises as the cheap lots run out), merchants; intermediates you craft yourself when that is cheaper.
-- What a craft brings back is the best allowed way: merchant (money at once), disenchant (if your Enchanting can),
-- auction house (only up to TSM sold per day * demandDays units of each result).
-- Grey comes from the game where it knows it (the open profession's recipes: maxTrivialLevel), else the data;
-- recipes on a cooldown (transmutes and such, Naowh's list) are left out.
-- It keeps the recipe it is on while another is not at least STICKY cheaper per point (fewer switches for a
-- few copper), and after a route it counts it again without each recipe it would buy: a cheaper route wins.
-- Point by point the plan takes the recipe whose next point costs least (an unbought recipe's price is spread over
-- the points it can still give); crafts are taken from the supply as the expected count reaches a whole craft.
local _, NPP = ...
local L = NPP.L

local Leveling = {}
NPP.Leveling = Leveling

local ROWS, ROW_H = 14, 20
local LEARN_ROWS = 8
local COLS = {
    { title = "Skill", w = 75, align = "LEFT" },
    { title = "Recipe", w = 220, align = "LEFT", max = 300 },
    { title = "Crafts", w = 55, align = "RIGHT" },
    { title = "Cost", w = 90, align = "RIGHT" },
    { title = "Back", w = 90, align = "RIGHT" },
    { title = "Result", w = 90, align = "RIGHT" },
}
local PAD = 12
local TOP = 120
local GREEN, RED, GREY, GOLD = "|cff4dd17a", "|cffff5555", "|cff999999", "|cffffd100"

local frame, rows, heads, info, total, buttons, learnLines
local tabs = {}
local RenderTabs -- defined after the window code, used by Leveling.Render
local result

---------------------------------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------------------------------

local function MyFaction() return UnitFactionGroup("player") == "Horde" and "H" or "A" end

local function Mine(side)
    return type(side) ~= "string" or side:find(MyFaction(), 1, true) ~= nil
end

local function RecipeData()
    local ns = NPP.ns
    return ns and type(ns.RecipeData) == "table" and ns.RecipeData or {}
end

local function ProfName(id)
    local d = RecipeData()[id]
    local name = d and d.skillSpell and C_Spell.GetSpellName(d.skillSpell)
    return name or ("#" .. tostring(id))
end

-- The profession whose window is open now (your own), or nil.
local function OpenProfession()
    local W = NPP.P and NPP.P.State
    if not W or W.linked or not (W.frame and W.frame:IsShown()) then return end
    local ok, base = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
    if not ok or type(base) ~= "table" or not base.professionID or (base.skillLevel or 0) <= 0 then return end
    return base.professionID
end

-- Your professions that have recipes: { { id, name, skill, cap } }
local function MyProfessions()
    local list = {}
    if not GetProfessions then return list end
    for _, index in pairs({ GetProfessions() }) do
        local name, _, skill, cap, _, _, line = GetProfessionInfo(index)
        if line and RecipeData()[line] and type(RecipeData()[line].recipes) == "table" and #RecipeData()[line].recipes > 0 then
            list[#list + 1] = { id = line, name = name or ProfName(line), skill = skill or 0, cap = cap or 0 }
        end
    end
    return list
end

-- Professions you do not have, by name.
local function OtherProfessions()
    local mine, list = {}, {}
    for _, p in ipairs(MyProfessions()) do mine[p.id] = true end
    for id, d in pairs(RecipeData()) do
        if not mine[id] and type(d.recipes) == "table" and #d.recipes > 0 then list[#list + 1] = { id = id, name = ProfName(id) } end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- The profession to plan: id, skill, cap, name, known (you have it)
local function Profession()
    local want = NPP.Get("levelProf")
    local mine = MyProfessions()
    if not want then want = OpenProfession() or (mine[1] and mine[1].id) end
    if not want then return end
    for _, p in ipairs(mine) do
        if p.id == want then return p.id, p.skill, p.cap, p.name, true end
    end
    if RecipeData()[want] then return want, 1, 75, ProfName(want), false end
end

-- Recipes of a profession you have learned: the open window knows; otherwise what Naowh remembers.
local function LearnedSet(profID)
    if OpenProfession() == profID then return nil end -- ask the window per recipe
    local set = {}
    local S = NPP.P and NPP.P.Shopping
    local ok, makes = false, nil
    if S and type(S.Makes) == "function" then ok, makes = pcall(S.Makes) end
    for _, m in pairs(ok and type(makes) == "table" and makes or {}) do
        if type(m) == "table" and m.prof == profID and m.recipe then set[m.recipe] = true end
    end
    return set
end

-- Trainers who teach a rank or a recipe: t = indices into the profession's trainer list (Naowh's data), your
-- faction only; without t, every trainer of the profession.
local function TrainersFor(d, t, price)
    local list = {}
    local all = type(d.trainers) == "table" and d.trainers or {}
    if type(t) == "table" then
        for _, i in ipairs(t) do
            local tr = all[i]
            if tr and Mine(tr[3]) then
                list[#list + 1] = { kind = "trainer", name = tr[2], map = tr[4], x = tr[5], y = tr[6], price = price }
            end
        end
        return list
    end
    for _, tr in ipairs(all) do
        if Mine(tr[3]) then list[#list + 1] = { kind = "trainer", name = tr[2], map = tr[4], x = tr[5], y = tr[6], price = price } end
    end
    return list
end

-- Trainer ranks needed to go from cap to target: { { name, cost, sources } }
local function RankSteps(profID, cap, target)
    local d = RecipeData()[profID]
    local out = {}
    if not (d and type(d.ranks) == "table") then return out end
    local ranks = {}
    for _, r in ipairs(d.ranks) do ranks[#ranks + 1] = r end
    table.sort(ranks, function(a, b) return (a.cap or 0) < (b.cap or 0) end)
    local prev = cap
    for _, rank in ipairs(ranks) do
        if (rank.cap or 0) > cap and prev < target then
            local cost, sources = rank.cost or 0, {}
            if type(rank.vendors) == "table" then
                for _, v in ipairs(rank.vendors) do
                    if Mine(v[3]) and tonumber(v[7]) then
                        sources[#sources + 1] = { kind = "vendor", name = v[2], map = v[4], x = v[5], y = v[6], price = tonumber(v[7]) }
                        cost = tonumber(v[7])
                    end
                end
            end
            if #sources == 0 then
                if type(rank.teachers) == "table" then
                    for _, tr in ipairs(rank.teachers) do
                        if Mine(tr[3]) then
                            sources[#sources + 1] = { kind = "trainer", name = tr[2], map = tr[4], x = tr[5], y = tr[6], price = cost }
                        end
                    end
                else
                    sources = TrainersFor(d, rank.t, cost)
                end
            end
            out[#out + 1] = { name = rank.name or L("Rank up to %d"):format(rank.cap), learnCost = cost, sources = sources,
                rank = true, quest = rank.quest ~= nil, skill = rank.skill, level = rank.level }
            prev = rank.cap
        end
    end
    return out
end


local function ZoneName(map)
    local mi = map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    return mi and mi.name or ("#" .. tostring(map))
end

-- Where to get a recipe you have not learned: { { kind, name, map, x, y, price } } cheapest first,
-- and the price and kind the plan uses (nil when it cannot be had).
local function Sources(r, profData)
    local list = {}
    local kind = r.source or "unknown"
    if kind == "trainer" or kind == "teacher" then
        for _, src in ipairs(TrainersFor(profData, r.t, r.cost or 0)) do list[#list + 1] = src end
        if #list == 0 then list[1] = { kind = "trainer", price = r.cost or 0 } end
    end
    if kind == "vendor" and type(r.vendors) == "table" then
        for _, v in ipairs(r.vendors) do
            if Mine(v[3]) and tonumber(v[7]) then
                list[#list + 1] = { kind = "vendor", name = v[2], map = v[4], x = v[5], y = v[6], price = tonumber(v[7]) }
            end
        end
    end
    if r.recipe and NPP.Get("levelRecipesAH") then
        local ah = NPP.PriceSource.AH(r.recipe)
        if ah then list[#list + 1] = { kind = "ah", price = ah, item = r.recipe } end
    end
    table.sort(list, function(a, b) return a.price < b.price end)
    local best = list[1]
    return list, best and best.price, best and best.kind
end

local function Chance(c, s)
    if s < c.available or s >= c.grey then return 0 end
    if s < c.yellow then return 1 end
    return (c.grey - s) / math.max(1, c.grey - c.yellow)
end

local STICKY = 0.10   -- keep the current recipe unless another point is at least 10% cheaper
local MAX_RUNS = 10   -- routes counted when trying without bought recipes

local function Cooldown(spell)
    local P = NPP.P
    return P and type(P.CooldownRecipes) == "table" and P.CooldownRecipes[spell] and true or false
end

local function Candidates(profID, from, to, excluded)
    local data = RecipeData()[profID]
    local list = {}
    if not (data and type(data.recipes) == "table") then return list end
    local learnedSet = LearnedSet(profID)
    local days = tonumber(NPP.Get("demandDays")) or 1
    for _, r in ipairs(data.recipes) do
        local ri = learnedSet == nil and r.spell and C_TradeSkillUI.GetRecipeInfo(r.spell) or nil
        local yellow = r.yellow or r.skill
        local grey = r.grey
        -- the game's own grey for the open profession beats the data
        if ri and tonumber(ri.maxTrivialLevel) and ri.maxTrivialLevel > 0 then grey = ri.maxTrivialLevel end
        if r.spell and r.item and grey and yellow and yellow <= grey and grey > from
            and not (excluded and excluded[r.spell]) and not Cooldown(r.spell) then
            local learned
            if learnedSet then learned = learnedSet[r.spell] == true else learned = ri and ri.learned or false end
            local sources, learnCost, how = {}, 0, "learned"
            if not learned then sources, learnCost, how = Sources(r, data) end
            if learnCost then
                local ok, v = pcall(NPP.Profit.Get, r.spell, r.item)
                if ok and v and v.missing == 0 and #v.parts > 0 then
                    local c = {
                        r = r, v = v, name = (ri and ri.name) or C_Spell.GetSpellName(r.spell) or tostring(r.spell),
                        learned = learned, learnCost = learnCost, learnHow = how, sources = sources,
                        available = learned and 0 or math.min(r.skill or yellow, yellow),
                        yellow = yellow, grey = grey, liveGrey = grey ~= r.grey,
                        vendor = v.vendorSale or 0, de = v.deSale, ahLeft = 0,
                        secs = NPP.Profit.CraftSeconds(r.spell), done = 0, acc = 0,
                    }
                    if v.ahSale then
                        local sold = NPP.PriceSource.SoldPerDay(v.output)
                        if sold then c.ah, c.ahLeft = v.ahSale, math.floor(sold * days) end
                    end
                    if c.available < to then list[#list + 1] = c end
                end
            end
        end
    end
    return list
end

-- What one craft brings back now with the allowed ways, and how.
local function Back(c)
    local best, via = 0, "none"
    -- merchant and disenchanting are one way: sold at once (disenchanting only if your Enchanting can)
    if NPP.Get("levelVendor") then
        if c.vendor > best then best, via = c.vendor, "vendor" end
        if c.de and c.de > best then best, via = c.de, "de" end
    end
    if NPP.Get("levelAH") == "demand" and c.ah and c.ahLeft >= c.v.made and c.ah > best then best, via = c.ah, "ah" end
    return best, via
end

---------------------------------------------------------------------------------------------------
-- Shared supply (Plan.internal, as the session plan uses it)
---------------------------------------------------------------------------------------------------

local function I() return NPP.Plan.internal end

local function ItemsOf(v)
    local ids, seen = {}, {}
    local function Add(id)
        if id and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    for _, part in ipairs(v.parts) do
        if not part.owned then
            Add(part.itemID)
            if part.maker then
                for _, sub in ipairs(part.maker.parts) do
                    if not sub.owned then Add(sub.itemID) end
                end
            end
        end
    end
    return ids
end

local function Save(state, ids)
    local snap = {}
    for _, id in ipairs(ids) do
        local s = state[id]
        if s then snap[id] = { s.at, s.used, s.taken, s.spare, s.subCrafts } end
    end
    return snap
end

local function Load(state, snap)
    for id, t in pairs(snap) do
        local s = state[id]
        s.at, s.used, s.taken, s.spare, s.subCrafts = t[1], t[2], t[3], t[4], t[5]
    end
end

-- One craft from the supply: cost (bags counted at market value), cash (what you pay: AH and merchants),
-- or nil when a reagent runs out.
local function TakeOne(c, Get)
    local P = I()
    local cost, cash = 0, 0
    for _, part in ipairs(c.v.parts) do
        if not part.owned then
            local x, m
            if part.maker then
                x, m = P.TakeIntermediate(part, part.need, c.v.rate or 0, Get)
            else
                x, m = P.TakeFrom(Get(part.itemID), part.need)
            end
            if not x then return nil end
            cost, cash = cost + x, cash + (m or 0)
        end
    end
    return cost, cash
end

---------------------------------------------------------------------------------------------------
-- Counting
---------------------------------------------------------------------------------------------------

-- One route from skill to target, recipes in excluded left out.
local function Run(profID, skill, cap, target, excluded, meta)
    local P = I()
    local cands = Candidates(profID, skill, target, excluded)
    local r = { profID = profID, known = meta.known, profName = meta.profName, skill = skill, target = target, cap = cap,
        segments = {}, cands = cands, excluded = excluded,
        spend = 0, cash = 0, learnSpend = 0, back = 0, backBy = { vendor = 0, de = 0, ah = 0, none = 0 }, crafts = 0, secs = 0,
        toLearn = {}, p = {} }
    r.state, r.Get = P.NewState(r.p)
    for _, c in ipairs(cands) do
        c.items = ItemsOf(c.v)
        for _, part in ipairs(c.v.parts) do
            if not part.owned then
                local st = r.Get(part.itemID)
                if part.maker then
                    st.made = part.maker.made
                    for _, sub in ipairs(part.maker.parts) do
                        if not sub.owned then r.Get(sub.itemID) end
                    end
                end
            end
        end
    end
    local bought, last = {}, nil
    local pcs, chs = {}, {}
    for s = skill, target - 1 do
        local best, bestCost, bestCh
        wipe(pcs)
        wipe(chs)
        for _, c in ipairs(cands) do
            local ch = (not c.out) and Chance(c, s) or 0
            if ch > 0 then
                local snap = Save(r.state, c.items)
                local cost = TakeOne(c, r.Get)
                Load(r.state, snap)
                if not cost then
                    c.out = true -- its reagents ran out
                else
                    local pc = (cost - (Back(c))) / ch
                    if not c.learned and not bought[c] then
                        pc = pc + c.learnCost / math.max(1, math.min(c.grey, target) - s)
                    end
                    pcs[c], chs[c] = pc, ch
                    if not bestCost or pc < bestCost then best, bestCost, bestCh = c, pc, ch end
                end
            end
        end
        if not best then
            r.stuck = s
            break
        end
        -- stay on the current recipe unless the best is clearly cheaper
        local current = last and last.c
        if current and current ~= best and pcs[current] and pcs[current] - bestCost <= math.abs(bestCost) * STICKY then
            best, bestCh = current, chs[current]
        end
        if not best.learned and not bought[best] then
            bought[best] = true
            r.learnSpend = r.learnSpend + best.learnCost
            r.toLearn[#r.toLearn + 1] = best
        end
        if not (last and last.c == best) then
            last = { from = s, to = s, c = best, crafts = 0, spend = 0, back = 0, vias = {} }
            r.segments[#r.segments + 1] = last
        end
        last.to = s + 1
        best.acc = best.acc + 1 / bestCh
        -- take whole crafts as the expected count reaches them
        while best.done < math.floor(best.acc + 0.5) do
            local cost, cash = TakeOne(best, r.Get)
            if not cost then
                best.out = true
                break
            end
            r.cash = r.cash + cash
            local back, via = Back(best)
            if via == "ah" then best.ahLeft = best.ahLeft - best.v.made end
            best.done = best.done + 1
            last.crafts, last.spend, last.back = last.crafts + 1, last.spend + cost, last.back + back
            last.vias[via] = true
            r.spend, r.back, r.crafts, r.secs = r.spend + cost, r.back + back, r.crafts + 1, r.secs + best.secs
            r.backBy[via] = r.backBy[via] + back
        end
    end
    -- trainer ranks past the current cap, first in the list: without them the skill stops at the cap
    for i, rank in ipairs(RankSteps(profID, cap, target)) do
        r.learnSpend = r.learnSpend + rank.learnCost
        table.insert(r.toLearn, i, rank)
    end
    r.learnedFromMemory = LearnedSet(profID) ~= nil
    r.net = r.spend + r.learnSpend - r.back
    r.pay = r.cash + r.learnSpend - r.back -- out of your pocket: bag reagents cost no money
    r.reach = r.stuck or target
    return r
end

-- a route that gets further wins; as far, the one that costs less out of pocket
local function Beats(a, b)
    if a.reach ~= b.reach then return a.reach > b.reach end
    return a.pay < b.pay - 1
end

function Leveling.Count()
    local profID, skill, cap, profName, known = Profession()
    if not profID then
        result = nil
        return Leveling.Open(true)
    end
    local top = 300
    for _, rk in ipairs(RecipeData()[profID].ranks or {}) do top = math.max(top, rk.cap or 0) end
    local target = tonumber(NPP.Get("levelTarget"))
    if not target or target <= skill then target = cap > skill and cap or math.min(top, cap + 75) end
    target = math.min(target, top)
    if target <= skill then
        result = { profID = profID, profName = profName, skill = skill, target = target, segments = {}, done = true, toLearn = {} }
        return Leveling.Open(true)
    end
    local meta = { known = known, profName = profName }
    local best = Run(profID, skill, cap, target, {}, meta)
    local runs, changed = 1, true
    -- as Naowh's plan does: would the route be cheaper without one of the recipes it buys?
    while changed and runs < MAX_RUNS do
        changed = false
        for _, c in ipairs(best.toLearn) do
            if not c.rank and c.r and runs < MAX_RUNS then
                local without = {}
                for k, v in pairs(best.excluded) do without[k] = v end
                without[c.r.spell] = true
                local r = Run(profID, skill, cap, target, without, meta)
                runs = runs + 1
                if Beats(r, best) then
                    best, changed = r, true
                    break
                end
            end
        end
    end
    best.runs = runs
    result = best
    NPP.Debug("leveling: %d -> %d, %d segments, %d recipes counted, %d routes tried", skill, target, #best.segments,
        #best.cands, runs)
    Leveling.Open(true)
end

---------------------------------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------------------------------

local function BagCount(itemID)
    local ok, n = pcall(NPP.P.Recipes.ItemCount, itemID)
    return ok and tonumber(n) or 0
end

-- To the shopping list: what the route takes from the AH and merchants (the supply's own breakdown, with the
-- dearest unit price it reached as the limit). Recipes to buy are printed.
function Leveling.ToShopping()
    if not (result and result.state and #result.segments > 0) then return end
    local P = I()
    local parts = {}
    for id, s in pairs(result.state) do
        if s.taken > 0 then
            local b = P.Breakdown(s.levels, s.taken)
            b.itemID = id
            parts[#parts + 1] = b
        end
    end
    if NPP.Shop and NPP.Started("shop") then
        if NPP.Shop.AddPlan({ parts = parts }) and NPP.Live and NPP.Live.Open() then NPP.Shop.ShowPanel(true) end
    end
    for _, c in ipairs(result.toLearn) do
        local src = c.sources[1]
        NPP.Print(L("Learn first: %s (%s, %s)."), c.name, Leveling.SourceText(src), NPP.Coins(c.learnCost))
    end
end

function Leveling.ToQueue()
    if not (result and result.cands) then return end
    if OpenProfession() ~= result.profID then
        return NPP.Print(L("Open this profession's window first: the crafting queue crafts there."))
    end
    local Q = NPP.P.CraftQueue
    if not (Q and type(Q.Add) == "function") then return NPP.Print(L("Naowh's crafting queue is not available.")) end
    local mine = type(Q.List) == "function" and Q.List() or nil
    local bits, later = {}, {}
    for _, c in ipairs(result.cands) do
        local want = c.done or 0
        if want > 0 then
            if not c.learned then
                later[#later + 1] = c.name
            else
                -- only what the bags allow now (Naowh's queue would shop for the rest itself)
                local can = want
                for _, part in ipairs(c.v.parts) do
                    if not part.owned and not part.craft then can = math.min(can, math.floor(BagCount(part.itemID) / part.need)) end
                end
                local entry = mine and mine.crafts and mine.crafts[c.r.spell]
                local have = entry and tonumber(entry.count) or 0
                if can > 0 and have == 0 then
                    pcall(Q.Add, C_TradeSkillUI.GetRecipeInfo(c.r.spell), can, nil, false)
                elseif can > 0 and have ~= can and type(Q.Step) == "function" then
                    pcall(Q.Step, c.r.spell, nil, can - have)
                end
                if can > 0 then bits[#bits + 1] = ("%dx %s"):format(can, c.name) end
                if can < want then later[#later + 1] = ("%s %d/%d"):format(c.name, can, want) end
            end
        end
    end
    if #bits > 0 then
        NPP.Print(L("Crafting queue now: %s. In the queue window: Start Queue, then Craft Next for each batch."), table.concat(bits, ", "))
        if NPP.ns and type(NPP.ns.OpenCraftQueue) == "function" then pcall(NPP.ns.OpenCraftQueue) end
    end
    if #later > 0 then
        NPP.Print(L("Not queued yet (not learned or not all in your bags): %s."), table.concat(later, ", "))
    end
end

function Leveling.SourceText(src)
    if not src then return "?" end
    if src.kind == "ah" then return L("auction house") end
    local who = src.kind == "trainer" and L("trainer") or L("merchant")
    if src.name then
        return ("%s %s (%s %.1f, %.1f)"):format(who, src.name, ZoneName(src.map), tonumber(src.x) or 0, tonumber(src.y) or 0)
    end
    return who
end

local function Waypoint(src)
    if not (src and src.map and src.x and src.y) then return end
    local ns = NPP.ns
    if ns and type(ns.PlaceWaypoint) == "function" then
        pcall(ns.PlaceWaypoint, src.name or "", src.map, src.x, src.y)
    end
end

---------------------------------------------------------------------------------------------------
-- Window
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

local function SetEnabled(b, on)
    if b.SetEnabled then b:SetEnabled(on) end
    b:SetAlpha(on and 1 or 0.45)
end

local function SetLabel(b, text)
    if NPP.SetButtonText then NPP.SetButtonText(b, text) else b:SetText(text) end
end

local VIA = { vendor = "merchant", de = "disenchant", ah = "AH", none = "nowhere" }

local function RowTooltip(self)
    local seg = self.seg
    if not seg then return end
    local c = seg.c
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(c.name, 1, 1, 1)
    GameTooltip:AddLine(L("Colours: yellow %d, green %d, grey %d"):format(c.yellow, math.floor((c.yellow + c.grey) / 2), c.grey)
        .. (c.liveGrey and (" " .. L("(grey from the game)")) or ""), 0.8, 0.8, 0.8)
    if seg.crafts > 0 then
        GameTooltip:AddDoubleLine(L("Reagents per craft"), NPP.Coins(math.floor(seg.spend / seg.crafts)), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddDoubleLine(L("Merchant pays per craft"), NPP.Coins(c.vendor), 1, 1, 1, 1, 1, 1)
    if c.de then GameTooltip:AddDoubleLine(L("Disenchanted per craft"), NPP.Coins(c.de), 1, 1, 1, 1, 1, 1) end
    if c.ah then GameTooltip:AddDoubleLine(L("AH per craft (after cut)"), NPP.Coins(c.ah), 1, 1, 1, 1, 1, 1) end
    local vias = {}
    for k in pairs(seg.vias) do vias[#vias + 1] = L(VIA[k] or k) end
    GameTooltip:AddLine(L("Results go: %s"):format(table.concat(vias, ", ")), 0.8, 0.8, 0.8)
    if not c.learned then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L("Where to learn:"), 1, 0.82, 0)
        for i, src in ipairs(c.sources) do
            if i > 4 then break end
            GameTooltip:AddDoubleLine("  " .. Leveling.SourceText(src), NPP.Coins(src.price), 0.8, 0.8, 0.8, 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

local function Toggle(key)
    NPP.Set(key, not NPP.Get(key), true)
    NPP.Safe("leveling", Leveling.Count)
end

local function Build()
    frame = CreateFrame("Frame", "KisMaxLeveling", UIParent)
    frame:SetSize(700, TOP + 22 + ROWS * ROW_H + 70 + LEARN_ROWS * 18 + 50)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    local ns, T = NPP.ns, NPP.ns and NPP.ns.THEME
    if ns and ns.Solid and T then
        ns.Solid(frame, "BACKGROUND", T.bg, 0.96):SetAllPoints()
        if ns.Border then ns.Border(frame, T.line) end
    else
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.9)
    end
    tinsert(UISpecialFrames, "KisMaxLeveling")
    frame.title = Font(frame, 16)
    frame.title:SetPoint("TOPLEFT", PAD, -PAD)
    local close = Button(frame, "X", 24, 22, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", -PAD, -PAD + 2)

    -- the big line: what the whole route costs
    total = Font(frame, 18)
    total:SetPoint("TOPLEFT", PAD, -66)
    total:SetPoint("RIGHT", -PAD, 0)
    total:SetJustifyH("LEFT")

    -- switches: target and where results go
    buttons = {}
    buttons.minus = Button(frame, "-5", 34, 22, function() Leveling.Step(-5) end)
    buttons.minus:SetPoint("TOPLEFT", PAD, -94)
    buttons.target = Button(frame, "", 100, 22, function() Leveling.EditTarget() end)
    buttons.target:SetPoint("LEFT", buttons.minus, "RIGHT", 4, 0)
    buttons.target:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L("Click: type the target skill"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    buttons.target:HookScript("OnLeave", GameTooltip_Hide)
    -- typing the target: a number box over the button, Enter to count, Escape to leave it
    local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    box:SetSize(56, 20)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(3)
    box:SetJustifyH("CENTER")
    box:SetFrameLevel(buttons.target:GetFrameLevel() + 5)
    box:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        self:Hide()
        if v and v > 0 then
            NPP.Set("levelTarget", v, true)
            NPP.Safe("leveling", Leveling.Count)
        end
    end)
    box:SetScript("OnEscapePressed", function(self) self:Hide() end)
    box:SetScript("OnEditFocusLost", function(self) self:Hide() end)
    box:Hide()
    frame.targetBox = box
    buttons.plus = Button(frame, "+5", 34, 22, function() Leveling.Step(5) end)
    buttons.plus:SetPoint("LEFT", buttons.target, "RIGHT", 4, 0)
    buttons.vendor = Button(frame, "", 120, 22, function() Toggle("levelVendor") end)
    buttons.vendor:SetPoint("LEFT", buttons.plus, "RIGHT", 14, 0)
    buttons.ah = Button(frame, "", 120, 22, function()
        NPP.Set("levelAH", NPP.Get("levelAH") == "demand" and "off" or "demand", true)
        NPP.Safe("leveling", Leveling.Count)
    end)
    buttons.ah:SetPoint("LEFT", buttons.vendor, "RIGHT", 4, 0)
    buttons.recipesAH = Button(frame, "", 140, 22, function() Toggle("levelRecipesAH") end)
    buttons.recipesAH:SetPoint("LEFT", buttons.ah, "RIGHT", 4, 0)

    heads = {}
    local x = PAD
    for _, c in ipairs(COLS) do
        local h = Font(frame, 12)
        h:SetPoint("TOPLEFT", x + 3, -TOP)
        h:SetWidth(c.w - 6)
        h:SetJustifyH(c.align)
        h:SetText(GOLD .. L(c.title) .. "|r")
        heads[#heads + 1] = h
        x = x + c.w
    end
    rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, frame)
        row:SetSize(600, ROW_H)
        row:SetPoint("TOPLEFT", PAD, -(TOP + 18) - (i - 1) * ROW_H)
        if i % 2 == 0 then
            local stripe = row:CreateTexture(nil, "BACKGROUND")
            stripe:SetAllPoints()
            stripe:SetColorTexture(1, 1, 1, 0.03)
        end
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        row.cells = {}
        for j, c in ipairs(COLS) do
            local fs = Font(row, 12)
            fs:SetJustifyH(c.align)
            fs:SetWordWrap(false)
            row.cells[j] = fs
        end
        row:SetScript("OnEnter", RowTooltip)
        row:SetScript("OnLeave", GameTooltip_Hide)
        rows[i] = row
    end
    local y = TOP + 18 + ROWS * ROW_H + 6
    info = Font(frame, 12)
    info:SetPoint("TOPLEFT", PAD, -y)
    info:SetPoint("RIGHT", -PAD, 0)
    info:SetJustifyH("LEFT")
    info:SetWordWrap(true)

    -- what to learn, where: click a line for a waypoint
    frame.learnTitle = Font(frame, 12)
    frame.learnTitle:SetJustifyH("LEFT")
    learnLines = {}
    for i = 1, LEARN_ROWS do
        local b = CreateFrame("Button", nil, frame)
        b:SetHeight(18)
        b.text = Font(b, 12)
        b.text:SetPoint("LEFT", 4, 0)
        b.text:SetPoint("RIGHT", -4, 0)
        b.text:SetJustifyH("LEFT")
        b.text:SetWordWrap(false)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 0.82, 0, 0.10)
        b:SetScript("OnClick", function(self) Waypoint(self.src) end)
        b:SetScript("OnEnter", function(self)
            if not (self.src and self.src.map) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L("Click: put a waypoint there"), 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        learnLines[i] = b
    end

    buttons.count = Button(frame, L("Recount"), 100, 24, function() NPP.Safe("leveling", Leveling.Count) end)
    buttons.count:SetPoint("BOTTOMLEFT", PAD, PAD)
    buttons.shop = Button(frame, L("To shopping list"), 140, 24, function() NPP.Safe("leveling shop", Leveling.ToShopping) end)
    buttons.shop:SetPoint("LEFT", buttons.count, "RIGHT", 6, 0)
    buttons.queue = Button(frame, L("To craft queue"), 140, 24, function() NPP.Safe("leveling queue", Leveling.ToQueue) end)
    buttons.queue:SetPoint("LEFT", buttons.shop, "RIGHT", 6, 0)
    frame:Hide()
end

local function Money(c, sign)
    local text = NPP.Coins(math.floor(math.abs(c) + 0.5))
    if not sign then return text end
    return (c <= 0 and GREEN or RED) .. (c <= 0 and "+" or "-") .. text .. "|r"
end

local function OnOff(key, label)
    return L(label) .. ": " .. (NPP.Get(key) and (GREEN .. L("yes") .. "|r") or (GREY .. L("no") .. "|r"))
end

function Leveling.Render()
    if not (frame and frame:IsShown()) then return end
    local r = result
    frame.title:SetText(GOLD .. L("Levelling plan") .. "|r" .. (r and r.profName and (" - " .. r.profName) or ""))
    local segs = r and r.segments or {}
    for i, row in ipairs(rows) do
        local seg = segs[i]
        row.seg = seg
        if seg then
            local c = row.cells
            c[1]:SetText(("%d-%d"):format(seg.from, seg.to))
            c[2]:SetText((seg.c.learned and "" or (GOLD .. "* |r")) .. seg.c.name)
            c[3]:SetText(tostring(seg.crafts))
            c[4]:SetText(NPP.Coins(math.floor(seg.spend + 0.5)))
            c[5]:SetText(NPP.Coins(math.floor(seg.back + 0.5)))
            c[6]:SetText(Money(seg.spend - seg.back, true))
            row:Show()
        else
            row:Hide()
        end
    end
    local text, big = "", ""
    if not r then
        big = GREY .. L("Choose a profession above.") .. "|r"
    elseif r.done then
        big = GREEN .. L("Already at the target skill (%d)."):format(r.skill) .. "|r"
    else
        if r.pay > 0 then
            big = L("Costs about %s"):format(RED .. NPP.Coins(math.floor(r.pay + 0.5)) .. "|r")
        else
            big = L("Pays you about %s"):format(GREEN .. NPP.Coins(math.floor(-r.pay + 0.5)) .. "|r")
        end
        big = big .. GREY .. "   " .. L("skill %d -> %d, %d crafts, %s"):format(r.skill, r.target, r.crafts, NPP.Plan.TimeText(r.secs)) .. "|r"
        text = L("To buy %s, recipes %s, back %s (merchant %s, disenchant %s, AH %s).")
            :format(NPP.Coins(math.floor(r.cash)), NPP.Coins(r.learnSpend), NPP.Coins(math.floor(r.back)),
                NPP.Coins(math.floor(r.backBy.vendor)), NPP.Coins(math.floor(r.backBy.de)), NPP.Coins(math.floor(r.backBy.ah)))
        if r.spend - r.cash >= 1 then
            text = text .. "\n" .. GREY .. L("From your bags: reagents worth %s (counted in the steps, not in the cost above)."):format(
                NPP.Coins(math.floor(r.spend - r.cash))) .. "|r"
        end
        if r.stuck then
            text = text .. "\n" .. RED .. L("No recipe gives points from %d with known prices: open the AH or check the overview.")
                :format(r.stuck) .. "|r"
        end
        if #segs > ROWS then text = text .. "\n" .. GREY .. L("(%d more steps not shown)"):format(#segs - ROWS) .. "|r" end
        if r.p and r.p.noDepth then text = text .. "\n" .. RED .. L("Some reagents have no quantities: their price counts as unlimited.") .. "|r" end
        if r.learnedFromMemory then
            text = text .. "\n" .. GREY .. (r.known and L("Learned recipes as Naowh remembers them (open the profession once to update).")
                or L("You do not have this profession: every recipe counts as not learned.")) .. "|r"
        end
        text = text .. "\n" .. GREY .. L("Expected values: a craft gives a point with its colour's chance. Reagents from your bags first, then the cheapest lots.") .. "|r"
        if (r.runs or 1) > 1 then
            text = text .. "\n" .. GREY .. L("Routes tried: %d (the cheapest is shown)."):format(r.runs) .. "|r"
        end
    end
    total:SetText(big)
    info:SetText(text)

    -- learn lines
    local y = TOP + 18 + ROWS * ROW_H + 6 + info:GetStringHeight() + 8
    local toLearn = r and r.toLearn or {}
    frame.learnTitle:ClearAllPoints()
    frame.learnTitle:SetPoint("TOPLEFT", PAD, -y)
    frame.learnTitle:SetText(#toLearn > 0 and (GOLD .. L("* To learn (click: waypoint):") .. "|r") or "")
    y = y + (#toLearn > 0 and 18 or 0)
    for i, b in ipairs(learnLines) do
        local c = toLearn[i]
        if c then
            local src = c.sources[1]
            b.src = src
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", PAD, -y)
            b:SetPoint("RIGHT", -PAD, 0)
            local how = src and Leveling.SourceText(src) or (c.quest and L("quest") or L("trainer"))
            local need = ""
            if c.rank then
                local bits = {}
                if c.skill then bits[#bits + 1] = L("skill %d"):format(c.skill) end
                if c.level then bits[#bits + 1] = L("level %d"):format(c.level) end
                if #bits > 0 then need = GREY .. " (" .. L("needs") .. " " .. table.concat(bits, ", ") .. ")|r" end
            end
            b.text:SetText(("%s%s - %s, %s%s"):format(c.rank and (GOLD .. L("Rank") .. ": |r") or "", c.name, how,
                c.quest and L("quest") or NPP.Coins(c.learnCost), need))
            b:Show()
            y = y + 18
        else
            b:Hide()
        end
    end
    frame:SetHeight(math.max(y + 50, TOP + 18 + ROWS * ROW_H + 110))

    local tabsRight = RenderTabs()
    local width = NPP.LayoutColumns(COLS, heads, rows, PAD, -TOP)
    SetLabel(buttons.target, L("Target: %d"):format(r and r.target or tonumber(NPP.Get("levelTarget")) or 0))
    SetLabel(buttons.vendor, OnOff("levelVendor", "Merchant / disenchant"))
    SetLabel(buttons.ah, L("AH") .. ": " .. (NPP.Get("levelAH") == "demand" and (GREEN .. L("by demand") .. "|r") or (GREY .. L("no") .. "|r")))
    SetLabel(buttons.recipesAH, OnOff("levelRecipesAH", "Recipes from the AH"))
    for _, b in pairs(buttons) do NPP.FitButton(b, 34) end
    local switches = 0
    for _, k in ipairs({ "minus", "target", "plus", "vendor", "ah", "recipesAH" }) do switches = switches + buttons[k]:GetWidth() + 4 end
    frame:SetWidth(math.max(PAD * 2 + width, PAD * 2 + switches + 10, tabsRight + PAD + 30, 640))
    local has = r and r.segments and #r.segments > 0
    SetEnabled(buttons.shop, has and true or false)
    SetEnabled(buttons.queue, has and true or false)
end

function Leveling.EditTarget()
    local box = frame and frame.targetBox
    if not box then return end
    box:ClearAllPoints()
    box:SetPoint("CENTER", buttons.target, "CENTER", 2, 0)
    box:SetText(tostring((result and result.target) or tonumber(NPP.Get("levelTarget")) or ""))
    box:Show()
    box:SetFocus()
    box:HighlightText()
end

function Leveling.Step(by)
    local profID, skill, cap = Profession()
    if not profID then return end
    local top = 300
    for _, rk in ipairs(RecipeData()[profID].ranks or {}) do top = math.max(top, rk.cap or 0) end
    local current = (result and result.target) or tonumber(NPP.Get("levelTarget")) or cap or 0
    local t = math.max((skill or 0) + 1, math.min(top, current + by))
    NPP.Set("levelTarget", t, true)
    NPP.Safe("leveling", Leveling.Count)
end

-- Tabs: your professions, then "Other" (each click: the next profession you do not have).
function Leveling.Choose(id)
    NPP.Set("levelProf", id, true)
    NPP.Set("levelTarget", false, true)
    NPP.Safe("leveling", Leveling.Count)
end

local function ChooseOther()
    local others = OtherProfessions()
    if #others == 0 then return end
    local current = NPP.Get("levelProf")
    local nextIndex = 1
    for i, p in ipairs(others) do
        if p.id == current then nextIndex = i % #others + 1 end
    end
    Leveling.Choose(others[nextIndex].id)
end

function RenderTabs()
    local mine = MyProfessions()
    local chosen = result and result.profID
    local x = PAD
    local entries = {}
    for _, p in ipairs(mine) do
        entries[#entries + 1] = { text = ("%s %d/%d"):format(p.name, p.skill, p.cap), id = p.id, on = p.id == chosen }
    end
    local otherOn = chosen and result and not result.known
    entries[#entries + 1] = { text = otherOn and (L("Other: %s"):format(result.profName)) or L("Other profession..."),
        other = true, on = otherOn }
    for i, e in ipairs(entries) do
        local b = tabs[i]
        if not b then
            b = Button(frame, "", 100, 22, function() end)
            tabs[i] = b
        end
        b.entry = e
        b:SetScript("OnClick", function(self)
            if self.entry.other then ChooseOther() else Leveling.Choose(self.entry.id) end
        end)
        SetLabel(b, e.on and (GOLD .. e.text .. "|r") or e.text)
        NPP.FitButton(b, 90)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", x, -38)
        b:SetAlpha(e.on and 1 or 0.75)
        b:Show()
        x = x + b:GetWidth() + 4
    end
    for i = #entries + 1, #tabs do tabs[i]:Hide() end
    return x
end

function Leveling.Open(keep)
    if not frame then Build() end
    frame:Show()
    if not keep then return Leveling.Count() end
    Leveling.Render()
end

function Leveling.Toggle()
    if frame and frame:IsShown() then return frame:Hide() end
    Leveling.Open()
end

NPP.Module("leveling", { "core", "ui" }, function() end)
