-- hud_health.lua — Port of CHudHealth (hl2/hud_health.cpp + cs_hud_health.cpp)
-- Animation state + event dispatch only.
-- Visual rendering is fully layout-driven via HL2Hud.DrawElement().
-- Layout declared in hud_themes.lua (DefaultLayouts.health / theme.layouts.health).
--
-- CSS animations sourced from cstrike/scripts/hudanimations.txt:
--   HealthRestored:   FgColor→BrightFg, Blur 7→1 (no BgColor flash)
--   HealthTookDamage: FgColor→DamagedFg, Accel back, Blur 7→1
--   HealthLow:        FgColor→DamagedFg, blur, infinite pulse (no DamagedBg)
-- HL2 animations (default): BgColor flash + BrightFg, glow blur, looping pulse

local make = HL2Hud.Anim.make
local set  = HL2Hud.Anim.set
local step = HL2Hud.Anim.step
local snap = HL2Hud.Anim.snap

local state = {
    fgColor = make(Color(255,220,0,255)),
    bgColor = make(Color(0,0,0,76)),
    blur    = make(0),
}
local lastVal   = -1
local looping   = false
local nextPulse = 0

local function isCSSLayout()
    return HL2Hud.GetLayout("health").glow_font == false
end

local function event(name)
    local C = HL2Hud.Colors
    if isCSSLayout() then
        if name == "HealthIncreasedAbove20" or name == "HealthIncreasedBelow20" then
            looping = false
            set(state.fgColor, C.BrightFg,  "Linear",  0,    0.01)
            set(state.fgColor, C.FgColor,   "Deaccel", 0.2,  1.0)
            set(state.blur,    7,            "Deaccel", 0,    0.2)
            set(state.blur,    1,            "Deaccel", 0.2,  1.0)
        elseif name == "HealthDamageTaken" then
            looping = false
            set(state.fgColor, C.DamagedFg, "Linear",  0,    0.1)
            set(state.fgColor, C.FgColor,   "Accel",   0.1,  1.0)
            set(state.blur,    7,            "Deaccel", 0,    0.2)
            set(state.blur,    1,            "Deaccel", 0.2,  0.3)
        elseif name == "HealthLow" then
            looping = false
            set(state.fgColor, C.DamagedFg, "Linear",  0,    0.1)
            set(state.blur,    7,            "Deaccel", 0,    0.2)
            set(state.blur,    1,            "Deaccel", 0.2,  1.0)
            nextPulse = CurTime() + 1.0
            looping   = true
        elseif name == "HealthPulse" then
            set(state.fgColor, C.BrightFg,  "Linear",  0,    0.1)
            set(state.fgColor, C.DamagedFg, "Accel",   0.1,  0.9)
            nextPulse = CurTime() + 1.0
        elseif name == "ColorsChanged" then
            local ply = LocalPlayer()
            local hp  = IsValid(ply) and ply:Health() or 100
            snap(state.fgColor, (hp > 0 and hp < 20) and C.DamagedFg or C.FgColor)
            snap(state.bgColor, C.BgColor)
            snap(state.blur, 0)
        end
    else
        if name == "HealthIncreasedAbove20" then
            looping = false
            set(state.bgColor, C.BgColor,          "Linear",  0,    0)
            set(state.fgColor, C.FgColor,          "Linear",  0,    0.03)
            set(state.blur,    3,                  "Linear",  0,    0.1)
            set(state.blur,    0,                  "Deaccel", 0.1,  2.0)
        elseif name == "HealthIncreasedBelow20" then
            set(state.fgColor, C.BrightFg,         "Linear",  0,    0.25)
            set(state.fgColor, C.FgColor,          "Linear",  0.3,  0.75)
            set(state.blur,    3,                  "Linear",  0,    0.1)
            set(state.blur,    0,                  "Deaccel", 0.1,  2.0)
        elseif name == "HealthDamageTaken" then
            set(state.fgColor, C.BrightFg,         "Linear",  0,    0.25)
            set(state.fgColor, C.FgColor,          "Linear",  0.3,  0.75)
            set(state.blur,    3,                  "Linear",  0,    0.1)
            set(state.blur,    0,                  "Deaccel", 0.1,  2.0)
        elseif name == "HealthLow" then
            looping = false
            set(state.bgColor, C.DamagedBg,        "Linear",  0,    0.1)
            set(state.bgColor, C.BgColor,          "Deaccel", 0.1,  1.75)
            set(state.fgColor, C.BrightFg,         "Linear",  0,    0.2)
            set(state.fgColor, C.DamagedFg,        "Linear",  0.2,  1.2)
            set(state.blur,    5,                  "Linear",  0,    0.1)
            set(state.blur,    3,                  "Deaccel", 0.1,  0.9)
            nextPulse = CurTime() + 1.0
            looping   = true
        elseif name == "HealthPulse" then
            set(state.blur,    5,                  "Linear",  0,    0.1)
            set(state.blur,    2,                  "Deaccel", 0.1,  0.8)
            set(state.fgColor, C.BrightDamagedFg,  "Linear",  0,    0.1)
            set(state.fgColor, C.DamagedFg,        "Deaccel", 0.1,  0.8)
            set(state.bgColor, Color(100,0,0,80),  "Linear",  0,    0.1)
            set(state.bgColor, C.BgColor,          "Deaccel", 0.1,  0.8)
            nextPulse = CurTime() + 0.8
        elseif name == "ColorsChanged" then
            local ply = LocalPlayer()
            local hp  = IsValid(ply) and ply:Health() or 100
            snap(state.fgColor, (hp > 0 and hp < 20) and C.DamagedFg or C.FgColor)
            snap(state.bgColor, C.BgColor)
        end
    end
end
HL2Hud.healthEvent = event

local elem = {}

function elem:GetSize()
    local layout = HL2Hud.GetLayout("health")
    local s = ScrH() / 480
    return (layout.wide or 102) * s, (layout.tall or 36) * s
end

function elem:Draw(x, y)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local hp     = math.max(0, ply:Health())
    local layout = HL2Hud.GetLayout("health")

    step(state.fgColor) step(state.bgColor) step(state.blur)

    if hp ~= lastVal then
        local old = lastVal
        lastVal = hp
        if old < 0 then
            if hp > 0 and hp < 20 then
                snap(state.fgColor, HL2Hud.Colors.DamagedFg)
                nextPulse = CurTime() + 1.0
                looping   = true
            else
                snap(state.fgColor, HL2Hud.Colors.FgColor)
            end
            snap(state.bgColor, HL2Hud.Colors.BgColor)
            snap(state.blur, isCSSLayout() and 1 or 0)
        else
            if hp >= 20 then
                if old < 20 then looping = false end
                event(hp > old and "HealthIncreasedAbove20" or "HealthDamageTaken")
            elseif hp > 0 then
                event(hp > old and "HealthIncreasedBelow20" or "HealthDamageTaken")
                if old >= 20 then event("HealthLow") end
            end
        end
    end

    if looping and CurTime() >= nextPulse then event("HealthPulse") end

    HL2Hud.DrawElement(x, y, hp, state, layout)
end

HL2Hud.healthElem = elem
