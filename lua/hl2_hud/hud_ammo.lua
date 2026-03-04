-- hud_ammo.lua — Port of CHudAmmo + CHudAmmoSecondary (hud_ammo.cpp + hudanimations.txt)
--
-- Geometry (WIN32, 480p baseline):
--   HudAmmo default:          xpos=r150 wide=136
--   WeaponUsesClips:          animate wide→132  (Deaccel 0.4s)
--   WeaponDoesNotUseClips:    animate wide→100  (Deaccel 0.4s)
--   WeaponUsesSecondaryAmmo:  animate wide→132, HudAmmo shifts to r222 to make room
--                             HudAmmoSecondary at r76 wide=60 (gap ~14 units from primary right)
--
-- EHUD right-aligns base_element at rx. x = rx - GetSize().w = left edge.
-- When secondary is visible, GetSize() returns (priW + gap + secW) so the full
-- block is right-aligned and secondary sits at the far right end.
--
-- digit_xpos=44 digit_ypos=2  text_xpos=8  text_ypos=20
-- digit2_xpos=98 digit2_ypos=16 (reserve, HudNumbersSmall, ammo2color animated)
-- Secondary: digit_xpos=36 digit_ypos=2  text_xpos=8  text_ypos=22

local make = HL2Hud.Anim.make
local set  = HL2Hud.Anim.set
local step = HL2Hud.Anim.step
local snap = HL2Hud.Anim.snap

local pri = {
    fgColor    = make(Color(255,220,0,255)),
    bgColor    = make(Color(0,0,0,76)),
    blur       = make(0),
    ammo2color = make(Color(255,220,0,255)),
    width      = make(136),  -- hudlayout default wide=136; anims slide to 132 or 100
}

local sec = {
    fgColor = make(Color(0,0,0,0)),
    bgColor = make(Color(0,0,0,0)),
    blur    = make(0),
    alpha   = make(0),
}

-- gap between primary right edge and secondary left edge (r222+132=scrW-90, r76=scrW-76 → 14)
local SEC_GAP = 14

local lastClip    = -1
local lastReserve = -1
local lastSecAmmo = -1
local lastWpn     = nil
local lastHasSec  = nil   -- nil = never initialized (force fire on first weapon)
local lastHasClip = nil

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
    elseif name == "WeaponDoesNotUseClips" then
        set(pri.width,      100,                  "Deaccel", 0,    0.4)
    elseif name == "WeaponUsesSecondaryAmmo" then
        -- Primary width stays 132; room for secondary is via GetSize() expanding total block
        set(pri.width,      132,                  "Deaccel", 0,    0.4)
    end
    -- WeaponDoesNotUseSecondaryAmmo has no primary position change in hudanimations.txt
end
HL2Hud.ammoEvent = priEvent

local function secEvent(name)
    local C = HL2Hud.Colors
    if name == "WeaponUsesSecondaryAmmo" then
        set(sec.bgColor,  Color(250,220,0,60),  "Linear",  0,    0.1)
        set(sec.bgColor,  C.BgColor,            "Deaccel", 0.1,  1.0)
        set(sec.fgColor,  C.BrightFg,           "Linear",  0,    0.1)
        set(sec.fgColor,  C.FgColor,            "Linear",  0.2,  1.5)
        -- Alpha slides in over 0.5s (matches HudAmmo Position Deaccel 0.5s from hudanimations.txt)
        set(sec.alpha,    255,                  "Deaccel", 0,    0.5)
    elseif name == "WeaponDoesNotUseSecondaryAmmo" then
        set(sec.fgColor,  Color(0,0,0,0),       "Linear",  0,    0.4)
        set(sec.bgColor,  Color(0,0,0,0),       "Linear",  0,    0.4)
        -- Fade out over 0.4s so the slide-away is visible
        set(sec.alpha,    0,                    "Deaccel", 0,    0.4)
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

local function weaponUsesSec(wpn)
    return IsValid(wpn) and wpn:GetSecondaryAmmoType() ~= -1
end
local function weaponUsesClips(wpn)
    return IsValid(wpn) and wpn:GetMaxClip1() ~= -1
end

local ammoElem = {}

function ammoElem:GetSize()
    local s    = ScrH() / 480
    local priW = pri.width.cur * s
    local secA = sec.alpha.cur
    if secA > 0 then
        -- Full width immediately; secondary just fades in (matches native HL2/GMod behaviour)
        return priW + (SEC_GAP * s) + (60 * s), 36 * s
    end
    return priW, 36 * s
end

function ammoElem:Draw(x, y, clip_h)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local wpn = ply:GetActiveWeapon()

    step(pri.fgColor) step(pri.bgColor) step(pri.blur)
    step(pri.ammo2color) step(pri.width)
    step(sec.fgColor) step(sec.bgColor) step(sec.blur) step(sec.alpha)

    local s = ScrH() / 480
    local C = HL2Hud.Colors

    -- ── Weapon switch ───────────────────────────────────────────────────────
    if wpn ~= lastWpn then
        lastWpn     = wpn
        lastClip    = -1
        lastReserve = -1
        lastSecAmmo = -1

        if IsValid(wpn) then
            priEvent("WeaponChanged")
            snap(pri.ammo2color, C.FgColor)

            -- These fire on EVERY weapon switch (matches source: always calls StartAnimationSequence)
            local nowHasClip = weaponUsesClips(wpn)
            priEvent(nowHasClip and "WeaponUsesClips" or "WeaponDoesNotUseClips")
            lastHasClip = nowHasClip

            local nowHasSec = weaponUsesSec(wpn)
            if nowHasSec then
                secEvent("WeaponUsesSecondaryAmmo")
                priEvent("WeaponUsesSecondaryAmmo")
            else
                -- Only suppress if we've seen a weapon before (avoid hiding on load)
                if lastHasSec ~= nil then
                    secEvent("WeaponDoesNotUseSecondaryAmmo")
                end
            end
            lastHasSec = nowHasSec
        end
    end

    -- ── Geometry ────────────────────────────────────────────────────────────
    local priW = pri.width.cur * s
    local secA = sec.alpha.cur
    local secW = 60 * s
    local gapW = SEC_GAP * s
    local px   = x               -- primary: always left edge
    local sx   = x + priW + gapW -- secondary: fixed position, just fades in

    -- ── Secondary panel ─────────────────────────────────────────────────────
    if secA > 0 and IsValid(wpn) and wpn:GetSecondaryAmmoType() ~= -1 then
        local a    = secA / 255
        local sbg  = sec.bgColor.cur
        draw.RoundedBox(8, sx, y, secW, 36*s, Color(sbg.r, sbg.g, sbg.b, math.Round(sbg.a * a)))

        local secAmmo = ply:GetAmmoCount(wpn:GetSecondaryAmmoType())

        -- Secondary ammo change events
        if lastSecAmmo >= 0 then
            if secAmmo ~= lastSecAmmo then
                if secAmmo == 0 then secEvent("AmmoSecondaryEmpty")
                elseif secAmmo > lastSecAmmo then secEvent("AmmoSecondaryIncreased")
                else secEvent("AmmoSecondaryDecreased") end
            end
        end
        lastSecAmmo = secAmmo

        local sfgR = sec.fgColor.cur
        local sfg  = Color(sfgR.r, sfgR.g, sfgR.b, math.Round(sfgR.a * a))

        surface.SetFont("HL2Hud_Text")
        surface.SetTextColor(sfg)
        surface.SetTextPos(sx + 8*s, y + 22*s)
        surface.DrawText("ALT")

        local secStr = tostring(secAmmo)
        local sblur  = sec.blur.cur
        if sblur > 0 then
            local ga = math.Clamp(sblur / 7 * 255 * a, 0, 255)
            surface.SetFont("HL2Hud_NumbersGlow")
            surface.SetTextColor(Color(sfgR.r, sfgR.g, sfgR.b, ga))
            surface.SetTextPos(sx + 36*s, y + 2*s)
            surface.DrawText(secStr)
        end
        surface.SetFont("HL2Hud_Numbers")
        surface.SetTextColor(sfg)
        surface.SetTextPos(sx + 36*s, y + 2*s)
        surface.DrawText(secStr)
    end

    -- ── Primary panel ───────────────────────────────────────────────────────
    if not IsValid(wpn) or wpn:GetPrimaryAmmoType() == -1 then return end

    local clip = wpn:Clip1()
    local reserve
    if clip < 0 then
        clip    = ply:GetAmmoCount(wpn:GetPrimaryAmmoType())
        reserve = -1
    else
        reserve = ply:GetAmmoCount(wpn:GetPrimaryAmmoType())
    end

    if lastClip >= 0 then
        if clip ~= lastClip then
            if clip == 0 then      priEvent("AmmoEmpty")
            elseif clip > lastClip then priEvent("AmmoIncreased")
            else                   priEvent("AmmoDecreased") end
        end
        if reserve >= 0 and reserve ~= lastReserve then
            if reserve == 0 then       priEvent("Ammo2Empty")
            elseif reserve > lastReserve then priEvent("Ammo2Increased")
            else                       priEvent("Ammo2Decreased") end
        end
    else
        -- First frame: snap to base colors (weapon switch already fired WeaponChanged flash)
        snap(pri.fgColor, C.FgColor)
        snap(pri.bgColor, C.BgColor)
    end
    lastClip    = clip
    lastReserve = reserve or -1

    local pbg = pri.bgColor.cur
    draw.RoundedBox(8, px, y, priW, 36*s, Color(pbg.r, pbg.g, pbg.b, pbg.a))

    surface.SetFont("HL2Hud_Text")
    surface.SetTextColor(pri.fgColor.cur)
    surface.SetTextPos(px + 8*s, y + 20*s)
    surface.DrawText("AMMO")

    local clipStr = tostring(clip)
    local pblur   = pri.blur.cur
    if pblur > 0 then
        local ga = math.Clamp(pblur / 7 * 255, 0, 255)
        local fc = pri.fgColor.cur
        surface.SetFont("HL2Hud_NumbersGlow")
        surface.SetTextColor(Color(fc.r, fc.g, fc.b, ga))
        surface.SetTextPos(px + 44*s, y + 2*s)
        surface.DrawText(clipStr)
    end
    surface.SetFont("HL2Hud_Numbers")
    surface.SetTextColor(pri.fgColor.cur)
    surface.SetTextPos(px + 44*s, y + 2*s)
    surface.DrawText(clipStr)

    -- Reserve: no glow (hudanimations.txt only animates ammo2color, not Blur)
    if reserve and reserve >= 0 then
        surface.SetFont("HL2Hud_NumbersSmall")
        surface.SetTextColor(pri.ammo2color.cur)
        surface.SetTextPos(px + 98*s, y + 16*s)
        surface.DrawText(tostring(reserve))
    end
end

HL2Hud.ammoElem = ammoElem
HL2Hud.ammoSecondaryElem = { GetSize = function() return 0, 0 end, Draw = function() end }
