-- hud_suit_power.lua — Port of CHudSuitPower (hud_suitpower.cpp)
-- hudlayout: xpos=16 ypos=396 wide=102 tall=26 (grows with active items)
--   BarInsetX=8  BarInsetY=15  BarWidth=92  BarHeight=4
--   BarChunkWidth=6  BarChunkGap=3
--   text_xpos=8  text_ypos=4  text2_xpos=8  text2_ypos=22  text2_gap=10
-- Animation events: SuitAuxPowerMax, SuitAuxPowerNotMax,
--                   SuitAuxPowerDecreasedBelow25, SuitAuxPowerIncreasedAbove25

local make = HL2Hud.Anim.make
local set  = HL2Hud.Anim.set
local step = HL2Hud.Anim.step

local auxColor  = make(Color(255,220,0,0))  -- starts transparent (hidden at full power)
local bgColor   = make(Color(0,0,0,0))
local lastPower = -1
local lastLow   = -1

local function event(name)
    local C = HL2Hud.Colors
    if name == "SuitAuxPowerMax" then
        set(bgColor,  Color(0,0,0,0), "Linear", 0, 0.4)
        set(auxColor, Color(0,0,0,0), "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerNotMax" then
        set(bgColor,  C.BgColor,      "Linear", 0, 0.4)
        set(auxColor, C.AuxHigh,      "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerDecreasedBelow25" then
        set(auxColor, C.AuxLow,       "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerIncreasedAbove25" then
        set(auxColor, C.AuxHigh,      "Linear", 0, 0.4)
    end
end
HL2Hud.auxEvent = event

local function getItems()
    local ply = LocalPlayer()
    if not IsValid(ply) then return {} end
    local t = {}
    if ply:WaterLevel() == 3                                   then table.insert(t,"OXYGEN")     end
    if ply:FlashlightIsOn()                                    then table.insert(t,"FLASHLIGHT") end
    if ply:IsSprinting() and ply:GetVelocity():Length2D() > 1  then table.insert(t,"SPRINT")    end
    return t
end

local elem = {}
function elem:GetSize()
    local ply = LocalPlayer()
    if not IsValid(ply) then return 102*(ScrH()/480), 0 end
    local power = ply:GetSuitPower()
    local items = getItems()
    if power >= 100 and #items == 0 then return 102*(ScrH()/480), 0 end
    local s = ScrH()/480
    -- base tall=26; with items: max(26, text2_ypos + (n-1)*text2_gap + font_h + padding)
    local h = 26*s
    if #items > 0 then h = math.max(h, (22 + (#items-1)*10 + 12 + 4)*s) end
    return 102*s, h
end

function elem:Draw(x, y, clip_h)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local power = ply:GetSuitPower()
    local items = getItems()

    step(auxColor) step(bgColor)

    -- State change detection → events
    local isMax = power >= 100 and #items == 0
    if isMax and lastPower ~= 100 then
        event("SuitAuxPowerMax")
    elseif not isMax and (lastPower == 100 or lastPower == -1) then
        event("SuitAuxPowerNotMax")
    end
    local lowNow = (power < 25) and 1 or 0
    if not isMax and lowNow ~= lastLow and lastLow >= 0 then
        event(lowNow == 1 and "SuitAuxPowerDecreasedBelow25" or "SuitAuxPowerIncreasedAbove25")
    end
    lastPower = power
    lastLow   = lowNow

    local s   = ScrH()/480
    local w   = 102*s
    local h   = clip_h
    local col = auxColor.cur
    local bg  = bgColor.cur

    draw.RoundedBox(6, x, y, w, h, bg.a > 0 and bg or HL2Hud.Colors.BgColor)

    -- Label (text_xpos=8, text_ypos=4)
    surface.SetFont("HL2Hud_Text")
    surface.SetTextColor(col)
    surface.SetTextPos(x + 8*s, y + 4*s)
    surface.DrawText("AUX POWER")

    -- Chunked bar (exact hudlayout.res values)
    local bx,by   = x+8*s, y+15*s
    local bw,bh   = 92*s,  4*s
    local cw,cg   = 6*s,   3*s
    local count   = math.floor(bw/(cw+cg))
    local filled  = math.floor(count*(power/100)+0.5)
    local cx      = bx
    surface.SetDrawColor(col)
    for i=1,filled        do surface.DrawRect(cx,by,cw,bh) cx=cx+cw+cg end
    surface.SetDrawColor(Color(col.r,col.g,col.b, HL2Hud.Colors.AuxDisabled))
    for i=filled+1,count  do surface.DrawRect(cx,by,cw,bh) cx=cx+cw+cg end

    -- Active item labels (text2_xpos=8, text2_ypos=22, text2_gap=10)
    surface.SetFont("HL2Hud_Text")
    surface.SetTextColor(col)
    local iy = y + 22*s
    for _, name in ipairs(items) do
        surface.SetTextPos(x + 8*s, iy)
        surface.DrawText(name)
        iy = iy + 10*s
    end

    return w, h
end
HL2Hud.auxElem = elem
