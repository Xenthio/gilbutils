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

-- hl2hud_ammo_icon 1: draw weapon inactive sprite instead of "AMMO" text label.
-- Matches Source SDK CHudAmmo::Paint() behaviour. Default off (GMod style), HL2 themes enable it.
CreateClientConVar("hl2hud_ammo_icon", "0", true, false, "Show weapon sprite in ammo panel (HL2 style)")

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
    local C   = HL2Hud.Colors
    local css = HL2Hud.GetLayout("ammo").glow_font == false  -- CSS marker

    if css then
        -- ── CSS ammo animations (hudanimations.txt) ─────────────────────────
        -- PrimaryAmmoIncrement: FgColor→Orange(full), Accel 3s back to OrangeDim
        -- PrimaryAmmoDecrement: FgColor→HudIcon_Red,  Accel 3s back to OrangeDim
        -- PrimaryAmmoEmpty: no event in CSS hudanimations
        if name == "AmmoIncreased" then
            set(pri.fgColor,    C.BrightFg,  "Linear",  0,    0.01)
            set(pri.fgColor,    C.FgColor,   "Accel",   0.01, 3.0)
        elseif name == "AmmoDecreased" then
            set(pri.fgColor,    C.DamagedFg, "Linear",  0,    0.0001)
            set(pri.fgColor,    C.FgColor,   "Accel",   0.0001, 3.0)
        elseif name == "WeaponChanged" then
            snap(pri.fgColor,    C.FgColor)
            snap(pri.bgColor,    C.BgColor)
            snap(pri.ammo2color, C.FgColor)
        elseif name == "ColorsChanged" then
            snap(pri.fgColor,    C.FgColor)
            snap(pri.bgColor,    C.BgColor)
            snap(pri.ammo2color, C.FgColor)
            snap(sec.fgColor,    C.FgColor)
            snap(sec.bgColor,    C.BgColor)
        end
        -- width/secondary events: CSS is right-anchored so width doesn't matter
        return
    end

    -- ── HL2 ammo animations ──────────────────────────────────────────────────
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
        set(pri.width,      132,                  "Deaccel", 0,    0.4)
    elseif name == "ColorsChanged" then
        snap(pri.fgColor,    C.FgColor)
        snap(pri.bgColor,    C.BgColor)
        snap(pri.ammo2color, C.FgColor)
        snap(sec.fgColor,    C.FgColor)
        snap(sec.bgColor,    C.BgColor)
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
    local s      = ScrH() / 480
    local layout = HL2Hud.GetLayout("ammo")
    -- CSS: fixed width from layout.wide (right-anchored, not EHUD-positioned)
    -- HL2: animated pri.width.cur
    local priW = layout.right and (layout.wide or 136) * s or pri.width.cur * s
    local h    = (layout.tall or 36) * s
    -- Secondary only for HL2-style (CSS has no secondary panel)
    local secLayout = HL2Hud.GetLayout("ammo_secondary")
    if secLayout and lastHasSec then
        return priW + (SEC_GAP * s) + ((secLayout.wide or 60) * s), h
    end
    return priW, h
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


    -- ── Draw ─────────────────────────────────────────────────────────────────
    -- All positional values come from the active theme's ammo layout.
    -- Handles HL2 (flat panel, glow, label) and CSS (rounded, indent, bar, icon)
    -- without any theme-name checks in the draw code.
    local layout    = HL2Hud.GetLayout("ammo")
    local secLayout = HL2Hud.GetLayout("ammo_secondary")

    -- x: layout.right = right-anchored absolute from screen right; otherwise EHUD-provided x
    local px = layout.right and (ScrW() - layout.right * s) or x

    -- ── Clip / reserve values ────────────────────────────────────────────────
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
            if clip == 0 then           priEvent("AmmoEmpty")
            elseif clip > lastClip then priEvent("AmmoIncreased")
            else                        priEvent("AmmoDecreased") end
        end
        if reserve >= 0 and reserve ~= lastReserve then
            if reserve == 0 then            priEvent("Ammo2Empty")
            elseif reserve > lastReserve then priEvent("Ammo2Increased")
            else                            priEvent("Ammo2Decreased") end
        end
    end
    lastClip    = clip
    lastReserve = reserve or -1

    -- ── Secondary panel ──────────────────────────────────────────────────────
    local secA = sec.alpha.cur
    if secLayout and secA > 0 and IsValid(wpn) and wpn:GetSecondaryAmmoType() ~= -1 then
        local a    = secA / 255
        local sbg  = sec.bgColor.cur
        local sw   = (secLayout.wide or 60) * s
        local sh   = (secLayout.tall or 36) * s
        local sx   = ScrW() - EHUD.MARGIN * s - sw
        HL2Hud.DrawPanel(sx, y, sw, sh, Color(sbg.r, sbg.g, sbg.b, math.Round(sbg.a * a)))

        local secAmmo = ply:GetAmmoCount(wpn:GetSecondaryAmmoType())
        if lastSecAmmo >= 0 and secAmmo ~= lastSecAmmo then
            if secAmmo == 0 then              secEvent("AmmoSecondaryEmpty")
            elseif secAmmo > lastSecAmmo then secEvent("AmmoSecondaryIncreased")
            else                              secEvent("AmmoSecondaryDecreased") end
        end
        lastSecAmmo = secAmmo

        local sfgR = sec.fgColor.cur
        local sfg  = Color(sfgR.r, sfgR.g, sfgR.b, math.Round(sfgR.a * a))
        local secState = {
            fgColor = { cur = sfg },
            bgColor = { cur = Color(0,0,0,0) },
            blur    = sec.blur,
        }
        HL2Hud.DrawElement(sx, y, secAmmo, secState, secLayout)

        -- Ammo-type icon above label (HL2 style, if theme enables icons)
        if GetConVar("hl2hud_ammo_icon"):GetBool() and IsValid(wpn) then
            surface.SetFont("HL2Hud_WeaponIconsSmall")
            local _, iconH = surface.GetTextSize("A")
            local lx = sx + (secLayout.text_xpos or 8) * s
            local ly = y  + (secLayout.text_ypos or 22) * s
            HL2Hud.DrawAmmoIcon(wpn:GetClass(), false, lx, ly - iconH, sfg)
        end
    end

    -- ── Primary panel ────────────────────────────────────────────────────────
    local priW = layout.right and layout.wide * s or pri.width.cur * s
    local ph   = (layout.tall or 36) * s
    local fc   = pri.fgColor.cur
    local pbg  = pri.bgColor.cur

    -- Background
    if pbg.a > 0 then
        if layout.panel == "rounded" then
            local r = math.Round((layout.corner_radius or 4) * s)
            draw.RoundedBox(r, px, y, priW, ph, pbg)
        else
            HL2Hud.DrawPanel(px, y, priW, ph, pbg)
        end
    end

    -- Label text (HL2: "AMMO") or weapon sprite icon above label
    if layout.label then
        local tx = px + (layout.text_xpos or 8) * s
        local ty = y  + (layout.text_ypos or 20) * s
        if GetConVar("hl2hud_ammo_icon"):GetBool() and IsValid(wpn) then
            surface.SetFont("HL2Hud_WeaponIconsSmall")
            local _, iconH = surface.GetTextSize("A")
            HL2Hud.DrawAmmoIcon(wpn:GetClass(), true, tx, ty - iconH, fc)
        end
        surface.SetFont(layout.text_font or "HL2Hud_Text")
        surface.SetTextColor(fc.r, fc.g, fc.b, fc.a)
        surface.SetTextPos(tx, ty)
        surface.DrawText(layout.label)
    end

    -- Primary number + glow (CHudNumericDisplay::Paint loop)
    local dx    = px + (layout.digit_xpos or 44) * s
    local dy    = y  + (layout.digit_ypos or 2) * s
    local font  = layout.font or "HL2Hud_Numbers"
    local pblur = pri.blur.cur

    local function drawNumber(f, nx, ny, val)
        surface.SetFont(f)
        if layout.indent then
            local cw = surface.GetTextSize("0")
            if val < 100 then nx = nx + cw end
            if val < 10  then nx = nx + cw end
        end
        surface.SetTextPos(nx, ny)
        surface.DrawText(tostring(val))
    end

    if pblur > 0 and layout.glow_font ~= false then
        local gf = layout.glow_font or "HL2Hud_NumbersGlow"
        for fl = pblur, 0, -1 do
            local a = fl >= 1 and fc.a or (fc.a * fl)
            surface.SetTextColor(Color(fc.r, fc.g, fc.b, math.Clamp(a, 0, 255)))
            drawNumber(gf, dx, dy, clip)
            if fl < 1 then break end
        end
    end
    surface.SetTextColor(fc.r, fc.g, fc.b, fc.a)
    drawNumber(font, dx, dy, clip)

    -- Separator bar (CSS: bar_xpos/bar_ypos/bar_width/bar_height)
    if layout.bar_xpos and reserve >= 0 then
        surface.SetDrawColor(fc.r, fc.g, fc.b, fc.a)
        surface.DrawRect(
            px + layout.bar_xpos   * s,
            y  + layout.bar_ypos   * s,
            layout.bar_width       * s,
            layout.bar_height      * s
        )
    end

    -- Reserve / secondary count (digit2)
    -- CSS source: PaintNumbers(m_hNumberFont, x, digit2_ypos, m_iAmmo2)
    -- Same font and indent logic as clip — small_font only used for HL2 reserve display
    if layout.digit2_xpos and reserve >= 0 then
        local d2x   = px + layout.digit2_xpos * s
        local d2y   = y  + layout.digit2_ypos * s
        -- CSS uses same font as primary; HL2 uses small_font for reserve
        local sfnt  = layout.small_font or layout.font or "HL2Hud_NumbersSmall"
        local rc    = (layout.glow_font == false) and fc or pri.ammo2color.cur
        surface.SetFont(sfnt)
        surface.SetTextColor(rc.r, rc.g, rc.b, rc.a)
        if layout.indent then
            local cw = surface.GetTextSize("0")
            if reserve < 100 then d2x = d2x + cw end
            if reserve < 10  then d2x = d2x + cw end
        end
        surface.SetTextPos(d2x, d2y)
        surface.DrawText(tostring(reserve))
    end

    -- Ammo-type icon (CSS: ammo_icon_xpos/ammo_icon_ypos)
    if layout.ammo_icon_xpos and IsValid(wpn) then
        HL2Hud.DrawCSSAmmoIcon(
            wpn:GetClass(),
            px + layout.ammo_icon_xpos * s,
            y  + layout.ammo_icon_ypos * s,
            fc
        )
    end
end

HL2Hud.ammoElem = ammoElem
HL2Hud.ammoSecondaryElem = { GetSize = function() return 0, 0 end, Draw = function() end }
