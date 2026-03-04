-- hud_battery.lua — Port of CHudBattery (hud_battery.cpp)
-- hudlayout: xpos=140 ypos=432 wide=108 tall=36
--            digit_xpos=50 digit_ypos=2  text_xpos=8 text_ypos=20
-- Visible only when Armor() > 0.

local make = HL2Hud.Anim.make
local set  = HL2Hud.Anim.set
local step = HL2Hud.Anim.step
local snap = HL2Hud.Anim.snap

local state = {
    fgColor = make(Color(255,220,0,255)),
    bgColor = make(Color(0,0,0,76)),
    blur    = make(0),
    alpha   = make(255),
}
local lastVal = -1

local function event(name)
    local C = HL2Hud.Colors
    if name == "SuitPowerIncreasedAbove20" then
        set(state.alpha,   255,        "Linear",  0,    0)
        set(state.bgColor, C.BgColor,  "Linear",  0,    0)
        set(state.fgColor, C.FgColor,  "Linear",  0,    0.05)
        set(state.blur,    3,          "Linear",  0,    0.1)
        set(state.blur,    0,          "Deaccel", 0.1,  2.0)
    elseif name == "SuitPowerIncreasedBelow20" then
        set(state.alpha,   255,        "Linear",  0,    0)
        set(state.fgColor, C.BrightFg, "Linear",  0,    0.25)
        set(state.fgColor, C.FgColor,  "Linear",  0.3,  0.75)
        set(state.blur,    3,          "Linear",  0,    0.1)
        set(state.blur,    0,          "Deaccel", 0.1,  2.0)
    elseif name == "SuitDamageTaken" then
        set(state.fgColor, C.BrightFg, "Linear",  0,    0.25)
        set(state.fgColor, C.FgColor,  "Linear",  0.3,  0.75)
        set(state.blur,    3,          "Linear",  0,    0.1)
        set(state.blur,    0,          "Deaccel", 0.1,  2.0)
    elseif name == "SuitPowerZero" then
        set(state.alpha,   0,          "Linear",  0,    0.4)
    elseif name == "ColorsChanged" then
        snap(state.fgColor, C.FgColor)
        snap(state.bgColor, C.BgColor)
    end
end
HL2Hud.suitEvent = event

local elem = {}
function elem:GetSize()
    local ply = LocalPlayer()
    local s = ScrH()/480
    if not IsValid(ply) or ply:Armor() <= 0 then return 108*s, 0 end
    return 108*s, 36*s
end
function elem:Draw(x, y, clip_h)
    local ply = LocalPlayer()
    if not IsValid(ply) or ply:Armor() <= 0 then return end
    local armor = ply:Armor()

    step(state.fgColor) step(state.bgColor) step(state.blur) step(state.alpha)

    if armor ~= lastVal then
        local old = lastVal
        lastVal = armor
        if old < 0 then
            snap(state.fgColor, HL2Hud.Colors.FgColor)
            snap(state.bgColor, HL2Hud.Colors.BgColor)
        else
            if armor == 0 then event("SuitPowerZero")
            elseif armor > old then
                event(armor >= 20 and "SuitPowerIncreasedAbove20" or "SuitPowerIncreasedBelow20")
            else event("SuitDamageTaken") end
        end
    end

    local a = state.alpha.cur / 255
    local function fa(c) return Color(c.r, c.g, c.b, math.Round(c.a * a)) end
    local fs = {
        fgColor = { cur = fa(state.fgColor.cur) },
        bgColor = { cur = fa(state.bgColor.cur) },
        blur    = state.blur,
    }
    return HL2Hud.DrawNumericDisplay(x, y, "SUIT", armor, fs, { wide=108 })
end
HL2Hud.suitElem = elem
