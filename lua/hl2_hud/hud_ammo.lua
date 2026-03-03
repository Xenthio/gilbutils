-- hud_ammo.lua — Port of CHudAmmo + CHudAmmoSecondary (hud_ammo.cpp + hudanimations.txt)
-- Implements position/size slide-in on weapon change, per WeaponUsesClips etc.
--
-- hudlayout baseline (WIN32, no secondary):
--   Primary:   wide=132 tall=36  digit_xpos=44 digit_ypos=2  text_xpos=8 text_ypos=20
--              digit2_xpos=98 digit2_ypos=16 (reserve, HudNumbersSmall, ammo2color anim)
-- With clips:       xpos=r150  wide=132
-- Without clips:    xpos=r118  wide=100
-- With secondary:   xpos=r222  wide=132
--   Secondary: wide=60 tall=36  digit_xpos=36 digit_ypos=2  text_xpos=8 text_ypos=22

local make = HL2Hud.Anim.make
local set  = HL2Hud.Anim.set
local step = HL2Hud.Anim.step
local snap = HL2Hud.Anim.snap

-- Primary ammo animated properties
local pri = {
    fgColor    = make(Color(255,220,0,255)),
    bgColor    = make(Color(0,0,0,76)),
    blur       = make(0),
    ammo2color = make(Color(255,220,0,255)),  -- reserve count color
    width      = make(132),   -- panel width in hudlayout units (animated)
    slideX     = make(0),     -- extra left-padding offset for slide-in (units)
}

-- Secondary ammo animated properties
local sec = {
    fgColor = make(Color(255,220,0,0)),   -- starts invisible
    bgColor = make(Color(0,0,0,0)),
    blur    = make(0),
    alpha   = make(0),
}

local lastClip    = -1
local lastReserve = -1
local lastWpn     = nil
local lastHasSec  = false
local lastHasClip = false

local function priEvent(name)
    local C = HL2Hud.Colors
    if name == "AmmoIncreased" then
        set(pri.fgColor,    C.BrightFg,           "Linear",  0,    0.15)
        set(pri.fgColor,    C.FgColor,            "Deaccel", 0.15, 1.5)
        set(pri.blur,       5,                    "Linear",  0,    0)
        set(pri.blur,       0,                    "Accel",   0.01, 1.5)
    elseif name == "AmmoDecreased" then
        set(pri.blur,       7,                    "Linear",  0,    0)
        set(pri.blur,       0,                    "Deaccel", 0.1,  1.5)
        set(pri.fgColor,    C.BrightFg,           "Linear",  0,    0.1)
        set(pri.fgColor,    C.FgColor,            "Deaccel", 0.1,  0.75)
    elseif name == "AmmoEmpty" then
        set(pri.fgColor,    C.BrightDamagedFg,    "Linear",  0,    0.2)
        set(pri.fgColor,    C.DamagedFg,          "Accel",   0.2,  1.2)
    elseif name == "Ammo2Increased" then
        set(pri.ammo2color, C.BrightFg,           "Linear",  0,    0.2)
        set(pri.ammo2color, C.FgColor,            "Accel",   0.2,  1.2)
    elseif name == "Ammo2Decreased" then
        set(pri.ammo2color, C.BrightFg,           "Linear",  0,    0.2)
        set(pri.ammo2color, C.FgColor,            "Accel",   0.2,  1.2)
    elseif name == "Ammo2Empty" then
        set(pri.ammo2color, C.BrightDamagedFg,    "Linear",  0,    0.2)
        set(pri.ammo2color, C.DamagedFg,          "Accel",   0.2,  1.2)
    elseif name == "WeaponChanged" then
        set(pri.bgColor,    Color(250,220,0,80),  "Linear",  0,    0.1)
        set(pri.bgColor,    C.BgColor,            "Deaccel", 0.1,  1.0)
        set(pri.fgColor,    C.BrightFg,           "Linear",  0,    0.1)
        set(pri.fgColor,    C.FgColor,            "Linear",  0.2,  1.5)
    elseif name == "WeaponUsesClips" then
        set(pri.width,      132,                  "Deaccel", 0,    0.4)
        set(pri.slideX,     0,                    "Deaccel", 0,    0.4)
    elseif name == "WeaponDoesNotUseClips" then
        -- narrower panel at r118 (32 units narrower than r150, slides in)
        set(pri.width,      100,                  "Deaccel", 0,    0.4)
        set(pri.slideX,     0,                    "Deaccel", 0,    0.4)
    elseif name == "WeaponUsesSecondaryAmmo" then
        -- primary shifts left (r222 = r150 - 72)
        set(pri.width,      132,                  "Deaccel", 0,    0.4)
    elseif name == "WeaponDoesNotUseSecondaryAmmo" then
        set(pri.width,      132,                  "Deaccel", 0,    0.4)
    end
end
HL2Hud.ammoEvent = priEvent

local function secEvent(name)
    local C = HL2Hud.Colors
    if name == "WeaponUsesSecondaryAmmo" then
        set(sec.bgColor,  Color(250,220,0,60),  "Linear",  0,    0.1)
        set(sec.bgColor,  C.BgColor,            "Deaccel", 0.1,  1.0)
        set(sec.fgColor,  C.BrightFg,           "Linear",  0,    0.1)
        set(sec.fgColor,  C.FgColor,            "Linear",  0.2,  1.5)
        set(sec.alpha,    255,                  "Linear",  0,    0.1)
    elseif name == "WeaponDoesNotUseSecondaryAmmo" then
        set(sec.fgColor,  Color(0,0,0,0),       "Linear",  0,    0.4)
        set(sec.bgColor,  Color(0,0,0,0),       "Linear",  0,    0.4)
        set(sec.alpha,    0,                    "Linear",  0,    0.1)
    elseif name == "AmmoSecondaryIncreased" then
        set(sec.fgColor,  C.BrightFg,           "Linear",  0,    0.15)
        set(sec.fgColor,  C.FgColor,            "Deaccel", 0.15, 1.5)
        set(sec.blur,     5,                    "Linear",  0,    0)
        set(sec.blur,     0,                    "Accel",   0.01, 1.5)
    elseif name == "AmmoSecondaryDecreased" then
        set(sec.blur,     7,                    "Linear",  0,    0)
        set(sec.blur,     0,                    "Deaccel", 0.1,  1.5)
        set(sec.fgColor,  C.BrightFg,           "Linear",  0,    0.1)
        set(sec.fgColor,  C.FgColor,            "Deaccel", 0.1,  0.75)
    elseif name == "AmmoSecondaryEmpty" then
        set(sec.fgColor,  Color(0,0,0,0),       "Linear",  0,    0.4)
    end
end
HL2Hud.ammoSecondaryEvent = secEvent

local function hasSec(wpn)
    return IsValid(wpn) and wpn:GetSecondaryAmmoType() ~= -1
end
local function hasClip(wpn)
    return IsValid(wpn) and wpn:GetMaxClip1() ~= -1
end

local ammoElem = {}
function ammoElem:GetSize()
    local s = ScrH()/480
    -- Width animates; base is the animated pri.width value
    local w = pri.width.cur
    -- If secondary visible, add its width (60) + gap (2)
    if sec.alpha.cur > 1 then
        w = w + 62
    end
    return w * s, 36 * s
end

function ammoElem:Draw(x, y, clip_h)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local wpn = ply:GetActiveWeapon()

    step(pri.fgColor) step(pri.bgColor) step(pri.blur)
    step(pri.ammo2color) step(pri.width) step(pri.slideX)
    step(sec.fgColor) step(sec.bgColor) step(sec.blur) step(sec.alpha)

    local s = ScrH()/480
    local C = HL2Hud.Colors

    -- Weapon changed?
    if wpn ~= lastWpn then
        local oldWpn    = lastWpn
        lastWpn         = wpn
        lastClip        = -1
        lastReserve     = -1

        if IsValid(wpn) then
            priEvent("WeaponChanged")
            local nowHasSec  = hasSec(wpn)
            local nowHasClip = hasClip(wpn)

            if nowHasSec ~= lastHasSec then
                if nowHasSec then
                    secEvent("WeaponUsesSecondaryAmmo")
                    priEvent("WeaponUsesSecondaryAmmo")
                else
                    secEvent("WeaponDoesNotUseSecondaryAmmo")
                    priEvent("WeaponDoesNotUseSecondaryAmmo")
                end
                lastHasSec = nowHasSec
            end

            if nowHasClip ~= lastHasClip then
                priEvent(nowHasClip and "WeaponUsesClips" or "WeaponDoesNotUseClips")
                lastHasClip = nowHasClip
            end

            snap(pri.ammo2color, C.FgColor)
        end
    end

    -- Draw secondary (left panel, alpha-composited)
    local showSec = sec.alpha.cur > 1
    local priW    = pri.width.cur * s
    local secW    = 60 * s

    if showSec then
        local sx  = x
        local a   = sec.alpha.cur / 255
        local function fa(c) return Color(c.r, c.g, c.b, math.Round(c.a * a)) end
        local sbg = fa(sec.bgColor.cur)
        draw.RoundedBox(8, sx, y, secW, 36*s, sbg.a > 0 and sbg or Color(C.BgColor.r,C.BgColor.g,C.BgColor.b,math.Round(C.BgColor.a*a)))

        if IsValid(wpn) and wpn:GetSecondaryAmmoType() ~= -1 then
            local secAmmo = ply:GetAmmoCount(wpn:GetSecondaryAmmoType())
            -- detect change
            local sfg = fa(sec.fgColor.cur)
            surface.SetFont("HL2Hud_Text")
            surface.SetTextColor(sfg)
            surface.SetTextPos(sx + 8*s, y + 22*s)
            surface.DrawText("ALT")

            local secStr = tostring(secAmmo)
            local sblur  = sec.blur.cur
            if sblur > 0 then
                local ga = math.Clamp(sblur/7*255*a, 0, 255)
                local fc = sec.fgColor.cur
                surface.SetFont("HL2Hud_NumbersGlow")
                surface.SetTextColor(Color(fc.r,fc.g,fc.b,ga))
                surface.SetTextPos(sx + 36*s, y + 2*s)
                surface.DrawText(secStr)
            end
            surface.SetFont("HL2Hud_Numbers")
            surface.SetTextColor(sfg)
            surface.SetTextPos(sx + 36*s, y + 2*s)
            surface.DrawText(secStr)
        end
    end

    -- Draw primary
    if not IsValid(wpn) or wpn:GetPrimaryAmmoType() == -1 then return end

    local clip = wpn:Clip1()
    local reserve
    if clip < 0 then
        clip    = ply:GetAmmoCount(wpn:GetPrimaryAmmoType())
        reserve = -1
    else
        reserve = ply:GetAmmoCount(wpn:GetPrimaryAmmoType())
    end

    -- Detect ammo change → fire events
    if clip ~= lastClip and lastClip >= 0 then
        if clip == 0 then priEvent("AmmoEmpty")
        elseif clip > lastClip then priEvent("AmmoIncreased")
        else priEvent("AmmoDecreased") end
    elseif lastClip < 0 then
        -- first frame for this weapon, snap colors
        snap(pri.fgColor, C.FgColor)
        snap(pri.bgColor, C.BgColor)
    end

    if reserve ~= lastReserve and lastReserve >= 0 then
        if reserve == 0 then priEvent("Ammo2Empty")
        elseif reserve > lastReserve then priEvent("Ammo2Increased")
        else priEvent("Ammo2Decreased") end
    end

    lastClip    = clip
    lastReserve = reserve

    local px  = showSec and (x + secW + 2*s) or x
    local pbg = pri.bgColor.cur
    draw.RoundedBox(8, px, y, priW, 36*s, pbg.a > 0 and pbg or C.BgColor)

    -- Label
    surface.SetFont("HL2Hud_Text")
    surface.SetTextColor(pri.fgColor.cur)
    surface.SetTextPos(px + 8*s, y + 20*s)
    surface.DrawText("AMMO")

    -- Clip (large number, digit_xpos=44)
    local clipStr = tostring(clip)
    local pblur   = pri.blur.cur
    if pblur > 0 then
        local ga = math.Clamp(pblur/7*255, 0, 255)
        local fc = pri.fgColor.cur
        surface.SetFont("HL2Hud_NumbersGlow")
        surface.SetTextColor(Color(fc.r,fc.g,fc.b,ga))
        surface.SetTextPos(px + 44*s, y + 2*s)
        surface.DrawText(clipStr)
    end
    surface.SetFont("HL2Hud_Numbers")
    surface.SetTextColor(pri.fgColor.cur)
    surface.SetTextPos(px + 44*s, y + 2*s)
    surface.DrawText(clipStr)

    -- Reserve (small, digit2_xpos=98, uses ammo2color)
    if reserve and reserve >= 0 then
        local sblur = pri.blur.cur  -- reserve uses same blur as primary
        if sblur > 0 then
            local ga = math.Clamp(sblur/7*255, 0, 255)
            local fc = pri.ammo2color.cur
            surface.SetFont("HL2Hud_NumbersGlow")
            surface.SetTextColor(Color(fc.r,fc.g,fc.b,ga))
            surface.SetTextPos(px + 98*s, y + 16*s)
            surface.DrawText(tostring(reserve))
        end
        surface.SetFont("HL2Hud_NumbersSmall")
        surface.SetTextColor(pri.ammo2color.cur)
        surface.SetTextPos(px + 98*s, y + 16*s)
        surface.DrawText(tostring(reserve))
    end
end

HL2Hud.ammoElem = ammoElem
-- Stub — secondary is drawn inside ammoElem
HL2Hud.ammoSecondaryElem = { GetSize=function() return 0,0 end, Draw=function() end }
