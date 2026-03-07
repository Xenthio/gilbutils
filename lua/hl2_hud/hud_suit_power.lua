-- hud_suit_power.lua — Port of CHudSuitPower (hud_suitpower.cpp + hudanimations.txt)

local make = HL2Hud.Anim.make
local set  = HL2Hud.Anim.set
local step = HL2Hud.Anim.step
local snap = HL2Hud.Anim.snap

local auxColor = make(Color(0,0,0,0))
local bgColor  = make(Color(0,0,0,0))
local panelH   = make(26)

local lastPower = -1
local lastLow   = -1
local lastItems = -1
local initialized = false

local ITEM_EVENTS = {
    "SuitAuxPowerNoItemsActive",
    "SuitAuxPowerOneItemActive",
    "SuitAuxPowerTwoItemsActive",
    "SuitAuxPowerThreeItemsActive",
}
local ITEM_HEIGHTS = { 26, 36, 46, 56 }

local function event(name)
    local C = HL2Hud.Colors
    if name == "SuitAuxPowerMax" then
        set(bgColor,  Color(0,0,0,0), "Linear", 0, 0.4)
        set(auxColor, Color(0,0,0,0), "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerNotMax" then
        set(bgColor,  C.BgColor,     "Linear", 0, 0.4)
        set(auxColor, C.AuxHigh,     "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerDecreasedBelow25" then
        set(auxColor, C.AuxLow,      "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerIncreasedAbove25" then
        set(auxColor, C.AuxHigh,     "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerNoItemsActive" then
        set(panelH, 26, "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerOneItemActive" then
        set(panelH, 36, "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerTwoItemsActive" then
        set(panelH, 46, "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerThreeItemsActive" then
        set(panelH, 56, "Linear", 0, 0.4)
    elseif name == "ColorsChanged" then
        -- Only update color if not fully hidden (max power)
        if auxColor.cur.a > 0 then
            local C = HL2Hud.Colors
            local power = IsValid(LocalPlayer()) and LocalPlayer():GetSuitPower() or 100
            snap(auxColor, power < 25 and C.AuxLow or C.AuxHigh)
            snap(bgColor,  C.BgColor)
        end
    end
end
HL2Hud.auxEvent = event

local function getItems()
    local ply = LocalPlayer()
    if not IsValid(ply) then return {} end
    local suit = GetConVarNumber("gmod_suit") ~= 0
    local t = {}
    if suit and ply:WaterLevel() == 3                                   then table.insert(t, "OXYGEN")     end
    if ply:FlashlightIsOn()                                             then table.insert(t, "FLASHLIGHT") end
    if suit and ply:IsSprinting() and ply:GetVelocity():Length2D() > 1 then table.insert(t, "SPRINT")     end
    return t
end

local elem = {}

function elem:GetSize()
    local s = ScrH() / 480
    local h = panelH.cur * s
    -- Still report height even when transparent so Draw() runs and can initialize
    -- Use alpha to gate EHUD space reservation (h=0 hides, but we need Draw to run once)
    if bgColor.cur.a < 1 and auxColor.cur.a < 1 then
        return 102*s, initialized and 0 or h
    end
    return 102*s, h
end

function elem:Draw(x, y, clip_h)
    if HL2Hud.Themes and HL2Hud.ActiveTheme then
        local t = HL2Hud.Themes[HL2Hud.ActiveTheme]
        if t and t.weaponSelection == "css" then return end
    end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    step(auxColor) step(bgColor) step(panelH)

    local power = ply:GetSuitPower()
    local items = getItems()
    local n     = #items
    local isMax = power >= 100 and n == 0

    -- Snap to correct state on first frame (no animation)
    if not initialized then
        initialized = true
        if isMax then
            snap(bgColor,  Color(0,0,0,0))
            snap(auxColor, Color(0,0,0,0))
        else
            snap(bgColor,  HL2Hud.Colors.BgColor)
            snap(auxColor, power < 25 and HL2Hud.Colors.AuxLow or HL2Hud.Colors.AuxHigh)
        end
        snap(panelH, ITEM_HEIGHTS[math.Clamp(n+1, 1, 4)])
        lastPower = isMax and -2 or power
        lastLow   = power < 25 and 1 or 0
        lastItems = n
        return
    end

    -- Visibility
    if isMax and lastPower ~= -2 then
        event("SuitAuxPowerMax")
        lastPower = -2
    elseif not isMax and lastPower == -2 then
        event("SuitAuxPowerNotMax")
        lastPower = power
    elseif not isMax then
        lastPower = power
    end

    -- Low power
    local lowNow = power < 25 and 1 or 0
    if lowNow ~= lastLow then
        event(lowNow == 1 and "SuitAuxPowerDecreasedBelow25" or "SuitAuxPowerIncreasedAbove25")
        lastLow = lowNow
    end

    -- Item count → size
    if n ~= lastItems then
        event(ITEM_EVENTS[math.Clamp(n+1, 1, 4)])
        lastItems = n
    end

    -- Skip draw if fully transparent
    local col = auxColor.cur
    local bg  = bgColor.cur
    if col.a < 1 and bg.a < 1 then return end

    local s = ScrH() / 480
    local h = clip_h

    draw.RoundedBox(6, x, y, 102*s, h, bg)

    -- Chunked bar (BarInsetX=8 BarInsetY=15 BarWidth=92 BarHeight=4 chunk=6 gap=3)
    local bx, by = x + 8*s, y + 15*s
    local cw, cg = 6*s, 3*s
    local count  = math.floor(92*s / (cw + cg))
    local filled = math.floor(count * (power / 100) + 0.5)
    local cx = bx
    surface.SetDrawColor(col)
    for i = 1, filled       do surface.DrawRect(cx, by, cw, 4*s) cx = cx + cw + cg end
    surface.SetDrawColor(Color(col.r, col.g, col.b, HL2Hud.Colors.AuxDisabled))
    for i = filled+1, count do surface.DrawRect(cx, by, cw, 4*s) cx = cx + cw + cg end

    -- Labels
    surface.SetFont("HL2Hud_Text")
    surface.SetTextColor(col)
    surface.SetTextPos(x + 8*s, y + 4*s)
    surface.DrawText("AUX POWER")

    local iy = y + 22*s
    for _, name in ipairs(items) do
        surface.SetTextPos(x + 8*s, iy)
        surface.DrawText(name)
        iy = iy + 10*s
    end
end

HL2Hud.auxElem = elem
