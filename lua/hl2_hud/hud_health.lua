-- hud_health.lua — Port of CHudHealth (hud_health.cpp)
-- hudlayout: xpos=16 ypos=432 wide=102 tall=36
--            text_xpos=8 text_ypos=20 digit_xpos=50 digit_ypos=2
-- Animation events: HealthIncreasedAbove20, HealthIncreasedBelow20,
--                   HealthDamageTaken, HealthLow, HealthPulse/Loop

local make = HL2Hud.Anim.make
local set  = HL2Hud.Anim.set
local step = HL2Hud.Anim.step

local state = {
    fgColor   = make(Color(255,220,0,255)),
    textColor = make(Color(255,220,0,255)),
    bgColor   = make(Color(0,0,0,0)),
    blur      = make(0),
}
local lastVal    = -1
local looping    = false
local nextPulse  = 0

local function event(name)
    local C = HL2Hud.Colors
    if name == "HealthIncreasedAbove20" then
        looping = false
        set(state.bgColor,    C.BgColor,         "Linear",  0,    0)
        set(state.textColor,  C.FgColor,          "Linear",  0,    0.04)
        set(state.fgColor,    C.FgColor,          "Linear",  0,    0.03)
        set(state.blur,       3,                  "Linear",  0,    0.1)
        set(state.blur,       0,                  "Deaccel", 0.1,  2.0)
    elseif name == "HealthIncreasedBelow20" then
        set(state.fgColor,    C.BrightFg,         "Linear",  0,    0.25)
        set(state.fgColor,    C.FgColor,          "Linear",  0.3,  0.75)
        set(state.blur,       3,                  "Linear",  0,    0.1)
        set(state.blur,       0,                  "Deaccel", 0.1,  2.0)
    elseif name == "HealthDamageTaken" then
        set(state.fgColor,    C.BrightFg,         "Linear",  0,    0.25)
        set(state.fgColor,    C.FgColor,          "Linear",  0.3,  0.75)
        set(state.blur,       3,                  "Linear",  0,    0.1)
        set(state.blur,       0,                  "Deaccel", 0.1,  2.0)
        set(state.textColor,  C.BrightFg,         "Linear",  0,    0.1)
        set(state.textColor,  C.FgColor,          "Deaccel", 0.1,  1.2)
    elseif name == "HealthLow" then
        looping = false
        set(state.bgColor,    C.DamagedBg,        "Linear",  0,    0.1)
        set(state.bgColor,    C.BgColor,          "Deaccel", 0.1,  1.75)
        set(state.fgColor,    C.BrightFg,         "Linear",  0,    0.2)
        set(state.fgColor,    C.DamagedFg,        "Linear",  0.2,  1.2)
        set(state.textColor,  C.BrightFg,         "Linear",  0,    0.1)
        set(state.textColor,  C.DamagedFg,        "Linear",  0.1,  1.2)
        set(state.blur,       5,                  "Linear",  0,    0.1)
        set(state.blur,       3,                  "Deaccel", 0.1,  0.9)
        nextPulse = CurTime() + 1.0
        looping   = true
    elseif name == "HealthPulse" then
        set(state.blur,       5,                  "Linear",  0,    0.1)
        set(state.blur,       2,                  "Deaccel", 0.1,  0.8)
        set(state.textColor,  C.BrightDamagedFg,  "Linear",  0,    0.1)
        set(state.textColor,  C.DamagedFg,        "Deaccel", 0.1,  0.8)
        set(state.bgColor,    Color(100,0,0,80),  "Linear",  0,    0.1)
        set(state.bgColor,    C.BgColor,          "Deaccel", 0.1,  0.8)
        nextPulse = CurTime() + 0.8
    end
end
HL2Hud.healthEvent = event

local elem = {}
function elem:GetSize() local s=ScrH()/480 return 102*s, 36*s end
function elem:Draw(x, y, clip_h)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local hp = math.max(0, ply:Health())

    step(state.fgColor) step(state.textColor) step(state.bgColor) step(state.blur)

    if hp ~= lastVal then
        local old = lastVal
        lastVal = hp
        if old >= 0 then
            if hp > old then
                event(hp >= 20 and "HealthIncreasedAbove20" or "HealthIncreasedBelow20")
            elseif hp > 0 and hp < 20 then event("HealthLow")
            else event("HealthDamageTaken") end
        else
            if hp < 20 and hp > 0 then event("HealthLow")
            else
                state.fgColor.cur   = HL2Hud.Colors.FgColor
                state.textColor.cur = HL2Hud.Colors.FgColor
                state.bgColor.cur   = HL2Hud.Colors.BgColor
            end
        end
    end

    if looping and CurTime() >= nextPulse then event("HealthPulse") end

    return HL2Hud.DrawNumericDisplay(x, y, "HEALTH", hp, state)
end
HL2Hud.healthElem = elem
