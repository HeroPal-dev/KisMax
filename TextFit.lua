-- TextFit.lua: labels that do not fit their button get a smaller font (Naowh's buttons and tabs are sized for
-- English; Russian words are longer and stick out over the edges and the next button).
-- Every Naowh font string is made by ns.Font (ns.Button makes its label with it too) and looked up at call time,
-- so we wrap ns.Font: a label centred on a button (one anchor) shrinks, down to MIN_SCALE of its size, until it
-- fits the button's width; it is fitted again when its text or the button's size changes. Labels anchored on both
-- sides (list rows) are left alone: Naowh already cuts those with "...". Nothing in Naowh's files is changed.
-- Frames Naowh built before this addon loaded are not covered (almost all windows are built when first opened).
local _, NPP = ...

local TextFit = {}
NPP.TextFit = TextFit

local MIN_SCALE = 0.7
local SIDE_PAD = 8

local function IsButton(frame)
    if not (frame and frame.GetObjectType) then return false end
    local t = frame:GetObjectType()
    return t == "Button" or t == "CheckButton"
end

local function Unbounded(fs)
    if fs.GetUnboundedStringWidth then return fs:GetUnboundedStringWidth() or 0 end
    return fs:GetStringWidth() or 0
end

local fitting = false
local function Fit(fs)
    if fitting or not fs then return end
    local font, size, flags = fs:GetFont()
    if not font or not size then return end
    fs.nppBaseSize = fs.nppBaseSize or size
    local base = fs.nppBaseSize
    fitting = true
    if size ~= base then fs:SetFont(font, base, flags) end
    local parent = fs:GetParent()
    -- only a label centred on its own button: a checkbox's text beside its box is meant to be wider than the box
    local point, relativeTo = fs:GetPoint(1)
    local centred = fs:GetNumPoints() == 1 and point == "CENTER" and (relativeTo == nil or relativeTo == parent)
    if NPP.Get("fitText") and centred and IsButton(parent) then
        local room = (parent:GetWidth() or 0) - SIDE_PAD
        local need = Unbounded(fs)
        if room > 10 and need > room then
            local scale = math.max(MIN_SCALE, room / need)
            fs:SetFont(font, math.floor(base * scale * 10) / 10, flags)
        end
    end
    fitting = false
end
TextFit.Fit = Fit

local function Attach(fs, parent)
    if not (fs and fs.SetText and IsButton(parent)) or fs.nppFit then return end
    fs.nppFit = true
    hooksecurefunc(fs, "SetText", Fit)
    -- a font set by Naowh (theme, skin) becomes the size to shrink from
    hooksecurefunc(fs, "SetFont", function(self, _, size)
        if not fitting and size then
            self.nppBaseSize = size
            Fit(self)
        end
    end)
    if parent.HookScript then parent:HookScript("OnSizeChanged", function() Fit(fs) end) end
end

-- Wrap Naowh's font maker at load time, before Naowh builds most of its windows.
local ns = _G.NaowhForever
if type(ns) == "table" and type(ns.Font) == "function" and not ns.nppFontWrapped then
    local original = ns.Font
    ns.Font = function(parent, ...)
        local fs = original(parent, ...)
        local ok, err = pcall(Attach, fs, parent)
        if not ok and NPP.Debug then NPP.Debug("text fit: %s", err) end
        return fs
    end
    ns.nppFontWrapped = true
end
