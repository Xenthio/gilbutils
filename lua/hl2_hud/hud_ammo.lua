-- hud_ammo.lua — Port of CHudAmmo (hud_ammo.cpp)
-- hudlayout: xpos=r150 ypos=432 wide=136 tall=36
--            text_xpos=8 text_ypos=20 digit_xpos=40 digit_ypos=2
--            digit2_xpos=98 digit2_ypos=16  (reserve/secondary count)
-- Shows clip ammo (large) + reserve ammo (small, right-aligned).
-- Hides when no weapon or weapon has no primary ammo.
-- Animation events: AmmoIncreased, AmmoDepleted (Blur 5→0 Deaccel 0.1 1.5)

local make = HL2Hud.Anim.make
local set  = HL2Hud.Anim.set
local step = HL2Hud.Anim.step

local state = {
    fgColor   = make(Color(255,220,0,255)),
    textColor = make(Color(255,220,0,255)),
    bgColor   = make(Color(0,0,0,76)),
    blur      = make(0),
}
local lastClip    = -1
local lastReserve = -1
local function event(name)
    local C = HL2Hud.Colors
    if name == "WeaponChanged" or name == "AmmoIncreased" then
        set(state.bgColor,   Color(250,220,0,80), "Linear",  0,    0.1)
        set(state.bgColor,   C.BgColor,           "Deaccel", 0.1,  1.5)
        set(state.blur,      5,                   "Linear",  0,    0)
        set(state.blur,      0,                   "Deaccel", 0.01, 1.5)
    elseif name == "AmmoDepleted" then
        set(state.fgColor,   C.BrightFg,          "Linear",  0,    0.1)
        set(state.fgColor,   C.FgColor,           "Deaccel", 0.1,  1.5)
    end
end
HL2Hud.ammoEvent = event

local elem = {}
function elem:GetSize()
    local s = ScrH()/480
    return 136*s, 36*s
end

function elem:Draw(x, y, clip_h)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local wpn = ply:GetActiveWeapon()

    step(state.fgColor) step(state.textColor) step(state.bgColor) step(state.blur)

    if not IsValid(wpn) or not wpn:UsesPrimaryAmmo() then return end

    local clip    = wpn:Clip1()
    local reserve
    if clip < 0 then
        clip    = ply:GetAmmoCount(wpn:GetPrimaryAmmoType())
        reserve = 0
    else
        reserve = ply:GetAmmoCount(wpn:GetPrimaryAmmoType())
    end

    if clip ~= lastClip or reserve ~= lastReserve then
        if lastClip >= 0 then
            if clip > lastClip or reserve > lastReserve then event("AmmoIncreased")
            elseif clip == 0 then event("AmmoDepleted") end
        else
            -- init: snap colors
            HL2Hud.Anim.snap(state.fgColor,   HL2Hud.Colors.FgColor)
            HL2Hud.Anim.snap(state.textColor, HL2Hud.Colors.FgColor)
            HL2Hud.Anim.snap(state.bgColor,   HL2Hud.Colors.BgColor)
        end
        lastClip    = clip
        lastReserve = reserve
    end

    local s  = ScrH()/480
    local w  = 136*s
    local h  = 36*s
    local C  = HL2Hud.Colors

    -- Background
    local bg = state.bgColor.cur
    draw.RoundedBox(8, x, y, w, h, bg.a > 0 and bg or C.BgColor)

    -- Label "AMMO" (text_xpos=8, text_ypos=20)
    surface.SetFont("HL2Hud_Text")
    surface.SetTextColor(state.textColor.cur)
    surface.SetTextPos(x + 8*s, y + 20*s)
    surface.DrawText("AMMO")

    -- Clip (large, digit_xpos=40, digit_ypos=2)
    local clipStr = tostring(clip)
    local blur = state.blur.cur
    if blur > 0 then
        local ga = math.Clamp(blur/5*255, 0, 255)
        local fc = state.fgColor.cur
        surface.SetFont("HL2Hud_NumbersGlow")
        surface.SetTextColor(Color(fc.r,fc.g,fc.b,ga))
        surface.SetTextPos(x + 40*s, y + 2*s)
        surface.DrawText(clipStr)
    end
    surface.SetFont("HL2Hud_Numbers")
    surface.SetTextColor(state.fgColor.cur)
    surface.SetTextPos(x + 40*s, y + 2*s)
    surface.DrawText(clipStr)

    -- Reserve (small, digit2_xpos=98, digit2_ypos=16)
    if reserve > 0 then
        surface.SetFont("HL2Hud_NumbersSmall")
        surface.SetTextColor(state.fgColor.cur)
        surface.SetTextPos(x + 98*s, y + 16*s)
        surface.DrawText(tostring(reserve))
    end

    return w, h
end
HL2Hud.ammoElem = elem
