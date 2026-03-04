-- hud_secondary_ammo.lua — Port of CHudSecondaryAmmo (hud_ammo.cpp)
-- hudlayout: xpos=r82 ypos=432 wide=72 tall=36
--            text_xpos=8 text_ypos=22 digit_xpos=26 digit_ypos=2
-- Shown only when weapon uses secondary ammo.

local make = HL2Hud.Anim.make
local set  = HL2Hud.Anim.set
local step = HL2Hud.Anim.step
local snap = HL2Hud.Anim.snap

local state = {
    fgColor = make(Color(255,220,0,255)),
    bgColor = make(Color(0,0,0,76)),
    blur    = make(0),
}
local lastVal = -1

local function event(name)
    local C = HL2Hud.Colors
    if name == "AmmoSecondaryEmpty" then
        set(state.fgColor, Color(0,0,0,0),      "Linear", 0, 0.4)
    elseif name == "AmmoSecondaryIncreased" then
        set(state.blur,    7,                    "Linear",  0,    0)
        set(state.blur,    0,                    "Deaccel", 0.1,  1.5)
        set(state.bgColor, Color(250,220,0,60),  "Linear",  0,    0.1)
        set(state.bgColor, C.BgColor,            "Deaccel", 0.1,  1.5)
    end
end
HL2Hud.ammoSecondaryEvent = event

local elem = {}
function elem:GetSize()
    local s = ScrH()/480
    return 72*s, 36*s
end

function elem:Draw(x, y, clip_h)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local wpn = ply:GetActiveWeapon()
    step(state.fgColor) step(state.bgColor) step(state.blur)

    if not IsValid(wpn) or wpn:GetSecondaryAmmoType() == -1 then return end
    local ammo = ply:GetAmmoCount(wpn:GetSecondaryAmmoType())

    if ammo ~= lastVal then
        if lastVal < 0 then
            snap(state.fgColor, HL2Hud.Colors.FgColor)
            snap(state.bgColor, HL2Hud.Colors.BgColor)
        else
            if ammo == 0 then event("AmmoSecondaryEmpty")
            elseif ammo > lastVal then event("AmmoSecondaryIncreased") end
        end
        lastVal = ammo
    end

    local s  = ScrH()/480
    local w  = 72*s
    local h  = 36*s
    local bg = state.bgColor.cur
    HL2Hud.DrawPanel(x, y, w, h, bg.a > 0 and bg or nil)

    -- Label "ALT" (text_xpos=8, text_ypos=22) — fgColor
    surface.SetFont("HL2Hud_Text")
    surface.SetTextColor(state.fgColor.cur)
    surface.SetTextPos(x + 8*s, y + 22*s)
    surface.DrawText("ALT")

    -- Number (digit_xpos=26, digit_ypos=2)
    local valStr = tostring(ammo)
    local blur   = state.blur.cur
    if blur > 0 then
        local ga = math.Clamp(blur/7*255, 0, 255)
        local fc = state.fgColor.cur
        surface.SetFont("HL2Hud_NumbersGlow")
        surface.SetTextColor(Color(fc.r,fc.g,fc.b,ga))
        surface.SetTextPos(x + 26*s, y + 2*s)
        surface.DrawText(valStr)
    end
    surface.SetFont("HL2Hud_Numbers")
    surface.SetTextColor(state.fgColor.cur)
    surface.SetTextPos(x + 26*s, y + 2*s)
    surface.DrawText(valStr)

    return w, h
end
HL2Hud.ammoSecondaryElem = elem
