-- hud_battery.lua — Port of CHudBattery (hud_battery.cpp) / CHudArmor (cs_hud_health.cpp)
-- Animation state + event dispatch only.
-- Visual rendering is fully layout-driven via HL2Hud.DrawElement().
-- Layout declared in hud_themes.lua (DefaultLayouts.battery / theme.layouts.battery).
--
-- CSS: always visible (shows "0" when no armor); no animation events.
-- HL2: hidden when Armor() <= 0; SuitPowerIncreasedAbove/Below20, SuitDamageTaken, SuitPowerZero.

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

local function isCSSLayout()
    return HL2Hud.GetLayout("battery").glow_font == false
end

local function event(name)
    local C = HL2Hud.Colors
    if isCSSLayout() then
        -- CSS has no armor animations
        if name == "ColorsChanged" then
            snap(state.fgColor, C.FgColor)
            snap(state.bgColor, C.BgColor)
            snap(state.blur, 0)
            snap(state.alpha, 255)  -- CSS always fully visible; reset if HL2 faded it out
            lastVal = -1            -- force re-init on next Draw so CSS shows at 0 armor
        end
        return
    end
    -- HL2 suit animations
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
    local layout = HL2Hud.GetLayout("battery")
    local s = ScrH() / 480
    local w = (layout.wide or 108) * s
    local h = (layout.tall or 36) * s
    -- CSS always shows (even at 0 armor); HL2 hides when no armor
    if isCSSLayout() then return w, h end
    local ply = LocalPlayer()
    if not IsValid(ply) or ply:Armor() <= 0 then return w, 0 end
    return w, h
end

function elem:Draw(x, y)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    -- HL2: hide at 0 armor; CSS: always show
    if not isCSSLayout() and ply:Armor() <= 0 then return end

    local armor  = ply:Armor()
    local layout = HL2Hud.GetLayout("battery")

    step(state.fgColor) step(state.bgColor) step(state.blur) step(state.alpha)

    if armor ~= lastVal then
        local old = lastVal
        lastVal = armor
        if old < 0 then
            snap(state.fgColor, HL2Hud.Colors.FgColor)
            snap(state.bgColor, HL2Hud.Colors.BgColor)
            snap(state.alpha, 255)
        else
            if armor == 0 then
                if not isCSSLayout() then event("SuitPowerZero") end
            elseif armor > old then
                event(armor >= 20 and "SuitPowerIncreasedAbove20" or "SuitPowerIncreasedBelow20")
            else
                event("SuitDamageTaken")
            end
        end
    end

    local a = state.alpha.cur / 255
    local drawState = {
        fgColor = { cur = Color(state.fgColor.cur.r, state.fgColor.cur.g,
                                state.fgColor.cur.b, math.Round(state.fgColor.cur.a * a)) },
        bgColor = { cur = Color(state.bgColor.cur.r, state.bgColor.cur.g,
                                state.bgColor.cur.b, math.Round(state.bgColor.cur.a * a)) },
        blur    = state.blur,
    }

    HL2Hud.DrawElement(x, y, armor, drawState, HL2Hud.GetLayout("battery"))
end

HL2Hud.suitElem = elem
