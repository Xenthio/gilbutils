-- hud_ammo.lua — Port of CHudAmmo + CHudAmmoSecondary (hud_ammo.cpp)
-- Both panels sit at ypos=432, side by side (secondary is at xpos=r76, primary at r150).
-- This single element draws both, sized to cover the full combined width.
--
-- hudlayout (WIN32):
--   Primary:   xpos=r150 wide=136 tall=36  digit_xpos=44 digit_ypos=2  text_xpos=8 text_ypos=20
--              digit2_xpos=98 digit2_ypos=16  (reserve count, HudNumbersSmall)
--   Secondary: xpos=r76  wide=60  tall=36  digit_xpos=36 digit_ypos=2  text_xpos=8 text_ypos=22

local make = HL2Hud.Anim.make
local set  = HL2Hud.Anim.set
local step = HL2Hud.Anim.step
local snap = HL2Hud.Anim.snap

-- Primary ammo state
local pri = {
    fgColor = make(Color(255,220,0,255)),
    bgColor = make(Color(0,0,0,76)),
    blur    = make(0),
}
local lastClip    = -1
local lastReserve = -1

-- Secondary ammo state
local sec = {
    fgColor = make(Color(255,220,0,255)),
    bgColor = make(Color(0,0,0,76)),
    blur    = make(0),
}
local lastSecAmmo = -1

local function priEvent(name)
    local C = HL2Hud.Colors
    if name == "AmmoIncreased" then
        set(pri.bgColor, Color(250,220,0,80), "Linear",  0,    0.1)
        set(pri.bgColor, C.BgColor,           "Deaccel", 0.1,  1.5)
        set(pri.blur,    5,                   "Linear",  0,    0)
        set(pri.blur,    0,                   "Deaccel", 0.01, 1.5)
    elseif name == "AmmoDepleted" then
        set(pri.fgColor, C.BrightFg,          "Linear",  0,    0.1)
        set(pri.fgColor, C.FgColor,           "Deaccel", 0.1,  1.5)
    end
end
HL2Hud.ammoEvent = priEvent

local function secEvent(name)
    local C = HL2Hud.Colors
    if name == "AmmoSecondaryEmpty" then
        set(sec.fgColor, Color(0,0,0,0),     "Linear",  0,    0.4)
    elseif name == "AmmoSecondaryIncreased" then
        set(sec.blur,    7,                  "Linear",  0,    0)
        set(sec.blur,    0,                  "Deaccel", 0.1,  1.5)
        set(sec.bgColor, Color(250,220,0,60),"Linear",  0,    0.1)
        set(sec.bgColor, C.BgColor,          "Deaccel", 0.1,  1.5)
    end
end
HL2Hud.ammoSecondaryEvent = secEvent

-- Total width = primary (136) + gap (2) + secondary (60) when secondary exists,
-- otherwise just primary (136). Right-aligned, so we extend leftward from rx.
local function hasSec(wpn)
    return IsValid(wpn) and wpn:GetSecondaryAmmoType() ~= -1
end

local elem = {}
function elem:GetSize()
    local s   = ScrH()/480
    local ply = LocalPlayer()
    if not IsValid(ply) then return 136*s, 36*s end
    local wpn = ply:GetActiveWeapon()
    if hasSec(wpn) then
        return (136+2+60)*s, 36*s
    end
    return 136*s, 36*s
end

function elem:Draw(x, y, clip_h)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local wpn = ply:GetActiveWeapon()

    step(pri.fgColor) step(pri.bgColor) step(pri.blur)
    step(sec.fgColor) step(sec.bgColor) step(sec.blur)

    local s  = ScrH()/480
    local C  = HL2Hud.Colors
    local totalW, h = self:GetSize()

    -- Secondary ammo panel (drawn first, leftmost)
    local showSec = hasSec(wpn)
    if showSec then
        local secAmmo = ply:GetAmmoCount(wpn:GetSecondaryAmmoType())
        if secAmmo ~= lastSecAmmo then
            if lastSecAmmo < 0 then
                snap(sec.fgColor, C.FgColor)
                snap(sec.bgColor, C.BgColor)
            else
                if secAmmo == 0 then secEvent("AmmoSecondaryEmpty")
                elseif secAmmo > lastSecAmmo then secEvent("AmmoSecondaryIncreased") end
            end
            lastSecAmmo = secAmmo
        end

        -- secondary panel: leftmost 60px
        local sx = x
        local sbg = sec.bgColor.cur
        draw.RoundedBox(8, sx, y, 60*s, h, sbg.a > 0 and sbg or C.BgColor)

        surface.SetFont("HL2Hud_Text")
        surface.SetTextColor(sec.fgColor.cur)
        surface.SetTextPos(sx + 8*s, y + 22*s)
        surface.DrawText("ALT")

        local secStr = tostring(secAmmo)
        local sblur  = sec.blur.cur
        if sblur > 0 then
            local ga = math.Clamp(sblur/7*255, 0, 255)
            local fc = sec.fgColor.cur
            surface.SetFont("HL2Hud_NumbersGlow")
            surface.SetTextColor(Color(fc.r,fc.g,fc.b,ga))
            surface.SetTextPos(sx + 36*s, y + 2*s)
            surface.DrawText(secStr)
        end
        surface.SetFont("HL2Hud_Numbers")
        surface.SetTextColor(sec.fgColor.cur)
        surface.SetTextPos(sx + 36*s, y + 2*s)
        surface.DrawText(secStr)
    end

    -- Primary ammo panel (rightmost 136px, or full width if no secondary)
    if not IsValid(wpn) or wpn:GetPrimaryAmmoType() == -1 then return end

    local clip = wpn:Clip1()
    local reserve
    if clip < 0 then
        clip    = ply:GetAmmoCount(wpn:GetPrimaryAmmoType())
        reserve = -1
    else
        reserve = ply:GetAmmoCount(wpn:GetPrimaryAmmoType())
    end

    if clip ~= lastClip or reserve ~= lastReserve then
        if lastClip < 0 then
            snap(pri.fgColor, C.FgColor)
            snap(pri.bgColor, C.BgColor)
        else
            if clip > lastClip or (reserve > lastReserve and lastReserve >= 0) then
                priEvent("AmmoIncreased")
            elseif clip == 0 then priEvent("AmmoDepleted") end
        end
        lastClip    = clip
        lastReserve = reserve
    end

    local px  = showSec and (x + (60+2)*s) or x
    local pbg = pri.bgColor.cur
    draw.RoundedBox(8, px, y, 136*s, h, pbg.a > 0 and pbg or C.BgColor)

    surface.SetFont("HL2Hud_Text")
    surface.SetTextColor(pri.fgColor.cur)
    surface.SetTextPos(px + 8*s, y + 20*s)
    surface.DrawText("AMMO")

    -- Clip (large)
    local clipStr = tostring(clip)
    local pblur   = pri.blur.cur
    if pblur > 0 then
        local ga = math.Clamp(pblur/5*255, 0, 255)
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

    -- Reserve (small)
    if reserve and reserve >= 0 then
        surface.SetFont("HL2Hud_NumbersSmall")
        surface.SetTextColor(pri.fgColor.cur)
        surface.SetTextPos(px + 98*s, y + 16*s)
        surface.DrawText(tostring(reserve))
    end

    return totalW, h
end
HL2Hud.ammoElem = elem

-- Secondary is now part of the primary element; expose a no-op stub so
-- cl_hl2_hud.lua's AddToColumn call doesn't error
HL2Hud.ammoSecondaryElem = { GetSize=function() return 0,0 end, Draw=function() end }
