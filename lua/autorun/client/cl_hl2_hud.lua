-- cl_hl2_hud.lua — GilbUtils built-in HL2 HUD replacement
-- Pixel-accurate port of CHudHealth, CHudBattery, CHudSuitPower using EHUD framework.
-- Animation events ported from hudanimations.txt / ClientScheme.res.
-- Replaces native panels by default. Expose HL2Hud global for live recoloring.
--
-- Global API:
--   HL2Hud.Colors.FgColor       — main number/text color    (default: 255 220 0 255)
--   HL2Hud.Colors.BrightFg      — flash on change           (default: 255 220 0 255)
--   HL2Hud.Colors.DamagedFg     — low-health color          (default: 180 0 0 230)
--   HL2Hud.Colors.BrightDamagedFg — pulse peak color        (default: 255 0 0 255)
--   HL2Hud.Colors.BgColor       — panel background          (default: 0 0 0 76)
--   HL2Hud.Colors.DamagedBg     — pulse background          (default: 180 0 0 200)
--   HL2Hud.Colors.AuxHigh       — aux bar high              (default: 255 220 0 220)
--   HL2Hud.Colors.AuxLow        — aux bar low (<25%)        (default: 255 0 0 220)
--   HL2Hud.Colors.AuxDisabled   — unfilled chunk alpha      (default: 70)

if SERVER then return end
if not EHUD then include("autorun/client/cl_extensible_hud.lua") end

HL2Hud = HL2Hud or {}

-- ============================================================================
-- COLORS — edit these at any time to recolor live
-- ============================================================================
HL2Hud.Colors = HL2Hud.Colors or {
    FgColor          = Color(255, 220,   0, 255),
    BrightFg         = Color(255, 220,   0, 255),
    DamagedFg        = Color(180,   0,   0, 230),
    BrightDamagedFg  = Color(255,   0,   0, 255),
    BgColor          = Color(  0,   0,   0,  76),
    DamagedBg        = Color(180,   0,   0, 200),
    AuxHigh          = Color(255, 220,   0, 220),
    AuxLow           = Color(255,   0,   0, 220),
    AuxDisabled      = 70,
}

-- ============================================================================
-- FONTS
-- ============================================================================
local function makeFonts()
    local s = ScrH() / 480
    surface.CreateFont("HL2Hud_Numbers",     { font="Halflife2", size=math.Round(32*s), antialias=true, additive=true })
    surface.CreateFont("HL2Hud_NumbersGlow", { font="Halflife2", size=math.Round(32*s), blursize=math.Round(4*s), scanlines=math.Round(2*s), antialias=true, additive=true })
    surface.CreateFont("HL2Hud_Text",        { font="Verdana",   size=math.Round(8*s),  weight=900, antialias=true })
    surface.CreateFont("HL2Hud_NumbersSmall",{ font="Halflife2", size=math.Round(20*s), antialias=true, additive=true })
end
hook.Add("OnScreenSizeChanged", "HL2Hud_Fonts", makeFonts)
makeFonts()

-- ============================================================================
-- ANIMATION STATE — per-element, mimics vgui AnimationController
-- Each field: { cur=Color|num, tgt=, endTime=, startTime=, interp="Linear"|"Deaccel" }
-- ============================================================================
local function lerpColor(a, b, t) return Color(Lerp(t,a.r,b.r), Lerp(t,a.g,b.g), Lerp(t,a.b,b.b), Lerp(t,a.a,b.a)) end
local function deaccel(t) return 1-(1-t)^2 end

local function makeAnim(val) return { cur=val, tgt=val, startT=0, endT=0, interp="Linear" } end
local function setAnim(anim, tgt, interp, delay, dur)
    anim.tgt    = tgt
    anim.startT = CurTime() + (delay or 0)
    anim.endT   = CurTime() + (delay or 0) + (dur or 0)
    anim.interp = interp or "Linear"
end
local function stepAnim(anim, dt)
    local now = CurTime()
    if now < anim.startT then return anim.cur end
    if now >= anim.endT then anim.cur = anim.tgt return anim.cur end
    local t = (now - anim.startT) / (anim.endT - anim.startT)
    if anim.interp == "Deaccel" then t = deaccel(t)
    elseif anim.interp == "Accel" then t = t*t end
    if type(anim.tgt) == "number" then
        anim.cur = Lerp(t, anim.cur, anim.tgt)  -- note: cur must be number too
    else
        anim.cur = lerpColor(anim.cur, anim.tgt, t)
    end
    return anim.cur
end

-- ============================================================================
-- NUMERIC DISPLAY — port of CHudNumericDisplay::Paint()
-- blur = glow intensity (0-5 matching source), fgColor/textColor animated separately
-- ============================================================================
local function drawNumericDisplay(x, y, label, value, state)
    -- state: { fgColor, textColor, bgColor, blur, alpha }
    -- all are anim objects whose .cur is the live value
    local s    = ScrH() / 480
    local w, h = 102*s, 36*s
    local C    = HL2Hud.Colors

    -- Background
    local bg = state.bgColor.cur
    if bg.a > 0 then
        draw.RoundedBox(8, x, y, w, h, bg)
    else
        draw.RoundedBox(8, x, y, w, h, C.BgColor)
    end

    -- Label (text_xpos=8, text_ypos=20)
    surface.SetFont("HL2Hud_Text")
    surface.SetTextColor(state.textColor.cur)
    surface.SetTextPos(x + 8*s, y + 20*s)
    surface.DrawText(label)

    -- Number (digit_xpos=50, digit_ypos=2)
    local valStr = tostring(value)
    local numX, numY = x + 50*s, y + 2*s

    -- Glow (blur 0-5 → alpha 0-255 proportionally)
    local blur = state.blur.cur
    if blur > 0 then
        local ga = math.Clamp(blur / 5 * 255, 0, 255)
        local fc = state.fgColor.cur
        surface.SetFont("HL2Hud_NumbersGlow")
        surface.SetTextColor(Color(fc.r, fc.g, fc.b, ga))
        surface.SetTextPos(numX, numY)
        surface.DrawText(valStr)
    end
    surface.SetFont("HL2Hud_Numbers")
    surface.SetTextColor(state.fgColor.cur)
    surface.SetTextPos(numX, numY)
    surface.DrawText(valStr)

    return w, h
end

-- ============================================================================
-- HEALTH (CHudHealth)
-- Events: HealthIncreasedAbove20, HealthIncreasedBelow20, HealthDamageTaken, HealthLow, HealthPulse/Loop
-- ============================================================================
local health = {
    lastVal  = -1,
    looping  = false,
    state = {
        fgColor   = makeAnim(Color(255,220,0,255)),
        textColor = makeAnim(Color(255,220,0,255)),
        bgColor   = makeAnim(Color(0,0,0,0)),
        blur      = makeAnim(0),
        alpha     = makeAnim(255),
    }
}
HL2Hud.health = health

local function healthEvent(name)
    local s = health.state
    local C = HL2Hud.Colors
    if name == "HealthIncreasedAbove20" then
        health.looping = false
        setAnim(s.bgColor,    C.BgColor,  "Linear",  0,    0)
        setAnim(s.textColor,  C.FgColor,  "Linear",  0,    0.04)
        setAnim(s.fgColor,    C.FgColor,  "Linear",  0,    0.03)
        setAnim(s.blur,       3,          "Linear",  0,    0.1)
        setAnim(s.blur,       0,          "Deaccel", 0.1,  2.0)
    elseif name == "HealthIncreasedBelow20" then
        setAnim(s.fgColor,    C.BrightFg, "Linear",  0,    0.25)
        setAnim(s.fgColor,    C.FgColor,  "Linear",  0.3,  0.75)
        setAnim(s.blur,       3,          "Linear",  0,    0.1)
        setAnim(s.blur,       0,          "Deaccel", 0.1,  2.0)
    elseif name == "HealthDamageTaken" then
        setAnim(s.fgColor,    C.BrightFg,    "Linear",  0,    0.25)
        setAnim(s.fgColor,    C.FgColor,     "Linear",  0.3,  0.75)
        setAnim(s.blur,       3,             "Linear",  0,    0.1)
        setAnim(s.blur,       0,             "Deaccel", 0.1,  2.0)
        setAnim(s.textColor,  C.BrightFg,    "Linear",  0,    0.1)
        setAnim(s.textColor,  C.FgColor,     "Deaccel", 0.1,  1.2)
    elseif name == "HealthLow" then
        health.looping = false
        setAnim(s.bgColor,   C.DamagedBg,       "Linear",  0,    0.1)
        setAnim(s.bgColor,   C.BgColor,          "Deaccel", 0.1,  1.75)
        setAnim(s.fgColor,   C.BrightFg,         "Linear",  0,    0.2)
        setAnim(s.fgColor,   C.DamagedFg,        "Linear",  0.2,  1.2)
        setAnim(s.textColor, C.BrightFg,         "Linear",  0,    0.1)
        setAnim(s.textColor, C.DamagedFg,        "Linear",  0.1,  1.2)
        setAnim(s.blur,      5,                  "Linear",  0,    0.1)
        setAnim(s.blur,      3,                  "Deaccel", 0.1,  0.9)
        -- schedule pulse loop
        health._nextPulse = CurTime() + 1.0
        health.looping    = true
    elseif name == "HealthPulse" then
        setAnim(s.blur,      5,                  "Linear",  0,    0.1)
        setAnim(s.blur,      2,                  "Deaccel", 0.1,  0.8)
        setAnim(s.textColor, C.BrightDamagedFg,  "Linear",  0,    0.1)
        setAnim(s.textColor, C.DamagedFg,        "Deaccel", 0.1,  0.8)
        setAnim(s.bgColor,   Color(100,0,0,80),  "Linear",  0,    0.1)
        setAnim(s.bgColor,   C.BgColor,          "Deaccel", 0.1,  0.8)
        health._nextPulse = CurTime() + 0.8
    end
end
HL2Hud.healthEvent = healthEvent

local healthElem = {}
function healthElem:GetSize() local s=ScrH()/480 return 102*s, 36*s end
function healthElem:Draw(x, y, clip_h)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local hp = math.max(0, ply:Health())
    local s  = health.state

    -- Tick animations
    stepAnim(s.fgColor, FrameTime())
    stepAnim(s.textColor, FrameTime())
    stepAnim(s.bgColor, FrameTime())
    stepAnim(s.blur, FrameTime())

    -- Detect change → fire event
    if hp ~= health.lastVal then
        local old = health.lastVal
        health.lastVal = hp
        if old >= 0 then  -- not init
            if hp > old then
                healthEvent(hp >= 20 and "HealthIncreasedAbove20" or "HealthIncreasedBelow20")
            else
                if hp > 0 and hp < 20 then healthEvent("HealthLow")
                else healthEvent("HealthDamageTaken") end
            end
        else
            -- Init: set state immediately
            if hp < 20 and hp > 0 then healthEvent("HealthLow")
            else
                s.fgColor.cur   = HL2Hud.Colors.FgColor
                s.textColor.cur = HL2Hud.Colors.FgColor
                s.bgColor.cur   = HL2Hud.Colors.BgColor
            end
        end
    end

    -- Pulse loop
    if health.looping and health._nextPulse and CurTime() >= health._nextPulse then
        healthEvent("HealthPulse")
    end

    return drawNumericDisplay(x, y, "HEALTH", hp, s)
end
HL2Hud.healthElem = healthElem

-- ============================================================================
-- BATTERY / SUIT (CHudBattery)
-- Events: SuitPowerIncreasedAbove20, SuitPowerIncreasedBelow20, SuitDamageTaken, SuitPowerZero
-- ============================================================================
local suit = {
    lastVal = -1,
    state = {
        fgColor   = makeAnim(Color(255,220,0,255)),
        textColor = makeAnim(Color(255,220,0,255)),
        bgColor   = makeAnim(Color(0,0,0,76)),
        blur      = makeAnim(0),
        alpha     = makeAnim(255),
    }
}
HL2Hud.suit = suit

local function suitEvent(name)
    local s = suit.state
    local C = HL2Hud.Colors
    if name == "SuitPowerIncreasedAbove20" then
        setAnim(s.alpha,     255,        "Linear",  0,    0)
        setAnim(s.bgColor,   C.BgColor,  "Linear",  0,    0)
        setAnim(s.textColor, C.FgColor,  "Linear",  0,    0.05)
        setAnim(s.fgColor,   C.FgColor,  "Linear",  0,    0.05)
        setAnim(s.blur,      3,          "Linear",  0,    0.1)
        setAnim(s.blur,      0,          "Deaccel", 0.1,  2.0)
    elseif name == "SuitPowerIncreasedBelow20" then
        setAnim(s.alpha,     255,        "Linear",  0,    0)
        setAnim(s.fgColor,   C.BrightFg, "Linear",  0,    0.25)
        setAnim(s.fgColor,   C.FgColor,  "Linear",  0.3,  0.75)
        setAnim(s.blur,      3,          "Linear",  0,    0.1)
        setAnim(s.blur,      0,          "Deaccel", 0.1,  2.0)
    elseif name == "SuitDamageTaken" then
        setAnim(s.fgColor,   C.BrightFg, "Linear",  0,    0.25)
        setAnim(s.fgColor,   C.FgColor,  "Linear",  0.3,  0.75)
        setAnim(s.blur,      3,          "Linear",  0,    0.1)
        setAnim(s.blur,      0,          "Deaccel", 0.1,  2.0)
        setAnim(s.textColor, C.BrightFg, "Linear",  0,    0.1)
        setAnim(s.textColor, C.FgColor,  "Deaccel", 0.1,  1.2)
    elseif name == "SuitPowerZero" then
        setAnim(s.alpha,     0,          "Linear",  0,    0.4)
    end
end
HL2Hud.suitEvent = suitEvent

local suitElem = {}
function suitElem:GetSize()
    local ply = LocalPlayer()
    local s = ScrH()/480
    if not IsValid(ply) or ply:Armor() <= 0 then return 108*s, 0 end
    return 108*s, 36*s
end
function suitElem:Draw(x, y, clip_h)
    local ply = LocalPlayer()
    if not IsValid(ply) or ply:Armor() <= 0 then return end
    local armor = ply:Armor()
    local s = suit.state

    stepAnim(s.fgColor, FrameTime())
    stepAnim(s.textColor, FrameTime())
    stepAnim(s.bgColor, FrameTime())
    stepAnim(s.blur, FrameTime())
    stepAnim(s.alpha, FrameTime())

    if armor ~= suit.lastVal then
        local old = suit.lastVal
        suit.lastVal = armor
        if old >= 0 then
            if armor == 0 then suitEvent("SuitPowerZero")
            elseif armor > old then
                suitEvent(armor >= 20 and "SuitPowerIncreasedAbove20" or "SuitPowerIncreasedBelow20")
            else suitEvent("SuitDamageTaken") end
        end
    end

    -- Apply overall alpha
    local a = s.alpha.cur
    local function withAlpha(c) return Color(c.r,c.g,c.b, math.Round(c.a * a/255)) end
    local fs = {
        fgColor   = { cur = withAlpha(s.fgColor.cur) },
        textColor = { cur = withAlpha(s.textColor.cur) },
        bgColor   = { cur = withAlpha(s.bgColor.cur) },
        blur      = s.blur,
    }
    return drawNumericDisplay(x, y, "SUIT", armor, fs)
end
HL2Hud.suitElem = suitElem

-- ============================================================================
-- AUX POWER (CHudSuitPower) — hudlayout.res exact geometry
--   xpos=16 ypos=396 wide=102 tall=26 (base, grows with items)
--   BarInsetX=8 BarInsetY=15 BarWidth=92 BarHeight=4 BarChunkWidth=6 BarChunkGap=3
--   text_xpos=8 text_ypos=4  text2_xpos=8 text2_ypos=22 text2_gap=10
-- Events: SuitAuxPowerMax, SuitAuxPowerNotMax, SuitAuxPowerDecreasedBelow25,
--         SuitAuxPowerIncreasedAbove25, SuitAuxPowerNoItemsActive, OneItem, TwoItems, ThreeItems
-- ============================================================================
local aux = {
    lastPower    = -1,
    lastDevices  = -1,
    lastLow      = -1,  -- 0 or 1
    auxColor     = makeAnim(Color(255,220,0,0)),  -- starts hidden
    bgColor      = makeAnim(Color(0,0,0,0)),
}
HL2Hud.aux = aux

local function auxEvent(name)
    local C = HL2Hud.Colors
    if name == "SuitAuxPowerMax" then
        setAnim(aux.bgColor,   Color(0,0,0,0),      "Linear", 0, 0.4)
        setAnim(aux.auxColor,  Color(0,0,0,0),      "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerNotMax" then
        setAnim(aux.bgColor,   C.BgColor,            "Linear", 0, 0.4)
        setAnim(aux.auxColor,  C.AuxHigh,            "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerDecreasedBelow25" then
        setAnim(aux.auxColor,  C.AuxLow,             "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerIncreasedAbove25" then
        setAnim(aux.auxColor,  C.AuxHigh,            "Linear", 0, 0.4)
    end
    -- Size/position handled by GetSize() returning correct h based on item count
end
HL2Hud.auxEvent = auxEvent

local function getAuxItems()
    local ply = LocalPlayer()
    if not IsValid(ply) then return {} end
    local items = {}
    if ply:WaterLevel() == 3                                    then table.insert(items,"OXYGEN")     end
    if ply:FlashlightIsOn()                                     then table.insert(items,"FLASHLIGHT") end
    if ply:IsSprinting() and ply:GetVelocity():Length2D() > 1   then table.insert(items,"SPRINT")    end
    return items
end

local auxElem = {}
function auxElem:GetSize()
    local ply = LocalPlayer()
    if not IsValid(ply) then return 102*(ScrH()/480), 0 end
    local power = ply:GetSuitPower()
    local items = getAuxItems()
    if power >= 100 and #items == 0 then return 102*(ScrH()/480), 0 end
    local s = ScrH()/480
    -- hudlayout: base tall=26, grows by text2_gap(10) per item starting at text2_ypos=22
    -- 0 items: 26. 1 item: max(26, 22+8+4)=34→36. 2: 46. 3: 56
    local baseH = 26*s
    local h = baseH
    if #items > 0 then
        h = math.max(baseH, (22 + (#items-1)*10 + 12 + 4)*s)
    end
    return 102*s, h
end

function auxElem:Draw(x, y, clip_h)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local power = ply:GetSuitPower()
    local items = getAuxItems()

    stepAnim(aux.auxColor, FrameTime())
    stepAnim(aux.bgColor, FrameTime())

    -- Detect state changes → fire events
    local isMax = power >= 100 and #items == 0
    if isMax and aux.lastPower ~= 100 then
        auxEvent("SuitAuxPowerMax")
    elseif not isMax and (aux.lastPower == 100 or aux.lastPower == -1) then
        auxEvent("SuitAuxPowerNotMax")
    end

    local lowNow = (power < 25) and 1 or 0
    if not isMax then
        if lowNow ~= aux.lastLow and aux.lastLow >= 0 then
            auxEvent(lowNow == 1 and "SuitAuxPowerDecreasedBelow25" or "SuitAuxPowerIncreasedAbove25")
        end
    end

    aux.lastPower   = power
    aux.lastLow     = lowNow
    aux.lastDevices = #items

    local s   = ScrH() / 480
    local w   = 102 * s
    local h   = clip_h
    local col = aux.auxColor.cur
    local bg  = aux.bgColor.cur

    draw.RoundedBox(6, x, y, w, h, bg.a > 0 and bg or HL2Hud.Colors.BgColor)

    -- "AUX POWER" label (text_xpos=8, text_ypos=4)
    surface.SetFont("HL2Hud_Text")
    surface.SetTextColor(col)
    surface.SetTextPos(x + 8*s, y + 4*s)
    surface.DrawText("AUX POWER")

    -- Chunked bar (BarInsetX=8, BarInsetY=15, BarWidth=92, BarHeight=4, Chunk=6, Gap=3)
    local barX,barY = x+8*s, y+15*s
    local barW,barH = 92*s, 4*s
    local cW,cG    = 6*s, 3*s
    local count    = math.floor(barW / (cW+cG))
    local filled   = math.floor(count * (power/100) + 0.5)
    local cx = barX
    surface.SetDrawColor(col)
    for i=1,filled       do surface.DrawRect(cx,barY,cW,barH) cx=cx+cW+cG end
    surface.SetDrawColor(Color(col.r,col.g,col.b, HL2Hud.Colors.AuxDisabled))
    for i=filled+1,count do surface.DrawRect(cx,barY,cW,barH) cx=cx+cW+cG end

    -- Active item labels (text2_xpos=8, text2_ypos=22, text2_gap=10)
    if #items > 0 then
        surface.SetFont("HL2Hud_Text")
        surface.SetTextColor(col)
        local iy = y + 22*s
        for _, name in ipairs(items) do
            surface.SetTextPos(x + 8*s, iy)
            surface.DrawText(name)
            iy = iy + 10*s
        end
    end

    return w, h
end
HL2Hud.auxElem = auxElem

-- ============================================================================
-- SUPPRESS NATIVE + REGISTER INTO EHUD
-- ============================================================================
hook.Add("HUDShouldDraw", "HL2Hud_HideNative", function(name)
    if name == "CHudHealth"  then return false end
    if name == "CHudBattery" then return false end
    if name == "CHudSuit"    then return false end
end)
EHUD.OwnsAuxBar = true

local hCol = EHUD.GetColumn("health")
local sCol = EHUD.GetColumn("suit")
if hCol then hCol.base_element = healthElem end
if sCol then sCol.base_element = suitElem   end
EHUD.AddToColumn("health", "hl2_aux_power", auxElem, 5)

print("[GilbUtils] HL2 HUD replacement loaded (HL2Hud global available)")
