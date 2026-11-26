-- Sell.lua: "Sell crafts" button under the merchant window. Sells, with one click, every stack in your bags
-- of the items on our sell list (the results you craft to sell to merchants). The list is filled from the
-- "Buy plan" panel ("Sell to merchants" button) or with /km sell add. Nothing else in the bags is touched.
-- Selling is C_Container.UseContainerItem at an open merchant, a few stacks per step, as Naowh's own junk
-- seller does it; never in combat. A merchant drops sales that come too fast, so after each pass over the bags
-- the bags are looked at again and another pass sells what is left, until nothing is left (or the merchant
-- took nothing three passes in a row). What was sold is what left the bags. A merchant buys back only the
-- last 12 stacks sold.
local _, NPP = ...
local L = NPP.L

local Sell = {}
NPP.Sell = Sell

local STEP_STACKS, STEP_DELAY = 4, 0.3   -- stacks per step, seconds between steps
local ROUND_DELAY, MAX_IDLE = 1.0, 3      -- pause before looking at the bags again; passes without progress
local BUYBACK = 12
local MIN_W, BTN_H = 140, 24
local button
local selling = false
local before            -- { stacks, units, value } when the selling started
local sent = {}         -- bag*1000+slot -> sent in this pass
local lastLeft, idle = nil, 0

function Sell.List()
    local db = NPP.db
    if not db then return {} end
    if type(db.sellList) ~= "table" then db.sellList = {} end
    return db.sellList
end

function Sell.Has(itemID) return itemID ~= nil and Sell.List()[itemID] == true end

function Sell.Set(itemID, on)
    if not itemID then return end
    Sell.List()[itemID] = on and true or nil
    NPP.Print(on and L("Sell list: added %s.") or L("Sell list: removed %s."), NPP.Profit.ItemName(itemID))
    Sell.Update()
    if NPP.PlanPanel then NPP.Safe("plan panel", NPP.PlanPanel.Render) end
end

function Sell.Toggle(itemID) Sell.Set(itemID, not Sell.Has(itemID)) end

function Sell.Button() return button end

local function LastBag()
    return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
end

local function AtMerchant()
    local frame = _G.MerchantFrame
    return frame ~= nil and frame:IsShown() and not InCombatLockdown()
end

local function Price(itemID)
    return NPP.PriceSource.VendorSell(itemID)
end

-- What the button would sell now: { [itemID] = units }, stacks, units, value.
function Sell.Scan()
    local items, stacks, units, value = {}, 0, 0, 0
    local list = Sell.List()
    if not next(list) then return items, 0, 0, 0 end
    for bag = 0, LastBag() do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and list[id] and not info.hasNoValue then
                local n = info.stackCount or 1
                items[id] = (items[id] or 0) + n
                stacks, units = stacks + 1, units + n
                value = value + (Price(id) or 0) * n
            end
        end
    end
    return items, stacks, units, value
end

local function Finish(why)
    selling = false
    if before then
        local _, stacks, units, value = Sell.Scan()
        local soldUnits, soldStacks = before.units - units, before.stacks - stacks
        if soldUnits > 0 then
            NPP.Print(L("Sold %d items (%d stacks) for %s."), soldUnits, soldStacks, NPP.Coins(before.value - value))
        end
        if stacks > 0 and not why then why = L("Not sold: %d stacks (the merchant did not take them)."):format(stacks) end
    end
    if why then NPP.Print(why) end
    before = nil
    Sell.Update()
end

local Step, Round

-- One pass over the bags, a few stacks per step.
Step = function()
    if not selling then return end
    if not AtMerchant() then return Finish(L("Selling stopped: the merchant window closed or combat started.")) end
    local list, done = Sell.List(), 0
    for bag = 0, LastBag() do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            local key = bag * 1000 + slot
            if id and list[id] and not info.hasNoValue and not info.isLocked and not sent[key] then
                sent[key] = true
                C_Container.UseContainerItem(bag, slot)
                done = done + 1
                if done >= STEP_STACKS then
                    C_Timer.After(STEP_DELAY, function() NPP.Safe("sell", Step) end)
                    return
                end
            end
        end
    end
    -- pass over: let the merchant answer, then look at what is left
    C_Timer.After(ROUND_DELAY, function() NPP.Safe("sell", Round) end)
end

Round = function()
    if not selling then return end
    if not AtMerchant() then return Finish(L("Selling stopped: the merchant window closed or combat started.")) end
    local _, stacks = Sell.Scan()
    if stacks == 0 then return Finish() end
    if lastLeft and stacks >= lastLeft then idle = idle + 1 else idle = 0 end
    lastLeft = stacks
    if idle >= MAX_IDLE then return Finish() end
    NPP.Debug("sell: %d stacks left, another pass", stacks)
    wipe(sent)
    Step()
end

function Sell.Run()
    if selling then return end
    if not AtMerchant() then return NPP.Print(L("Talk to a merchant first (and not in combat).")) end
    local _, stacks = Sell.Scan()
    if stacks == 0 then
        if not next(Sell.List()) then return NPP.Print(L("The sell list is empty: add items on the Buy plan panel.")) end
        return NPP.Print(L("Nothing from the sell list is in your bags."))
    end
    local _, s, u, v = Sell.Scan()
    before = { stacks = s, units = u, value = v }
    selling, lastLeft, idle = true, nil, 0
    wipe(sent)
    Sell.Update()
    NPP.Safe("sell", Step)
end

function Sell.Update()
    if not (button and button:IsShown()) then return end
    local _, stacks, units, value = Sell.Scan()
    local text
    if selling then
        text = L("Selling...")
    elseif stacks > 0 then
        text = L("Sell crafts: %d (%s)"):format(units, NPP.Coins(value))
    else
        text = L("Sell crafts: none")
    end
    NPP.SetButtonText(button, text)
    local label = button.label or button:GetFontString()
    local width = label and label.GetStringWidth and label:GetStringWidth()
    if width and width > 0 then button:SetWidth(math.max(MIN_W, width + 24)) end
    local on = stacks > 0 and not selling
    if button.SetEnabled then button:SetEnabled(on) end
    button:SetAlpha(on and 1 or 0.6)
end

local function Tooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L("Sell crafts"), 1, 1, 1)
    local items, stacks, _, value = Sell.Scan()
    local any = false
    for id, n in pairs(items) do
        any = true
        GameTooltip:AddDoubleLine(("%s x%d"):format(NPP.Profit.ItemName(id), n), NPP.Coins((Price(id) or 0) * n),
            1, 1, 1, 1, 1, 1)
    end
    if any then
        GameTooltip:AddDoubleLine(L("Total"), NPP.Coins(value), 1, 0.82, 0, 1, 0.82, 0)
    else
        GameTooltip:AddLine(L("Nothing from the sell list is in your bags."), 0.8, 0.8, 0.8, true)
    end
    GameTooltip:AddLine(L("Only items on the sell list are sold. Add or remove one with the button on the Buy plan panel or /km sell list."), 0.6, 0.6, 0.6, true)
    if stacks > BUYBACK then
        GameTooltip:AddLine(L("The merchant can buy back only the last %d stacks."):format(BUYBACK), 1, 0.4, 0.4, true)
    end
    GameTooltip:Show()
end

local function Build()
    local frame = _G.MerchantFrame
    local ns = NPP.ns
    local w, h = MIN_W, BTN_H
    if ns and type(ns.Button) == "function" then
        button = ns.Button(frame, L("Sell crafts"), w, h, function() NPP.Safe("sell", Sell.Run) end)
    else
        button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(w, h)
        button:SetText(L("Sell crafts"))
        button:SetScript("OnClick", function() NPP.Safe("sell", Sell.Run) end)
    end
    -- right of the Merchant / Buyback tabs under the window; without them, under the window's right edge
    local tab = _G.MerchantFrameTab2
    if tab and tab.GetRight and tab:GetRight() then
        button:SetPoint("LEFT", tab, "RIGHT", 8, 0)
    else
        button:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -4)
    end
    button:SetFrameStrata(frame:GetFrameStrata())
    button:SetFrameLevel(frame:GetFrameLevel() + 10)
    button:HookScript("OnEnter", Tooltip)
    button:HookScript("OnLeave", GameTooltip_Hide)
    button:HookScript("OnShow", function() NPP.Safe("sell", Sell.Update) end)
end

NPP.Module("sell", { "core", "sell" }, function()
    Sell.List()
    local events = CreateFrame("Frame")
    events:RegisterEvent("MERCHANT_SHOW")
    events:RegisterEvent("MERCHANT_CLOSED")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_SHOW" then
            if not button then NPP.Safe("sell button", Build) end
            NPP.Safe("sell", Sell.Update)
        elseif event == "MERCHANT_CLOSED" then
            if selling then NPP.Safe("sell", Finish) end
        else
            NPP.Safe("sell", Sell.Update)
        end
    end)
end)
