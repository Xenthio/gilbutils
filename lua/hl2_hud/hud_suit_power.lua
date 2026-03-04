-- hud_suit_power.lua — Port of CHudSuitPower (hud_suitpower.cpp + hudanimations.txt)
--
-- hudanimations.txt events:
--   SuitAuxPowerMax          → hide (BgColor→0, AuxPowerColor→0, Linear 0.4s)
--   SuitAuxPowerNotMax       → show (BgColor→BgColor, AuxPowerColor→255 220 0 220, Linear 0.4s)
--   SuitAuxPowerDecreasedBelow25 → AuxPowerColor→255 0 0 220, Linear 0.4s
--   SuitAuxPowerIncreasedAbove25 → AuxPowerColor→255 220 0 220, Linear 0.4s
--   SuitAuxPowerNoItemsActive    → Size 102×26 at y=400, Linear 0.4s
--   SuitAuxPowerOneItemActive    → Size 102×36 at y=390, Linear 0.4s
--   SuitAuxPowerTwoItemsActive   → Size 102×46 at y=380, Linear 0.4s
--   SuitAuxPowerThreeItemsActive → Size 102×56 at y=370, Linear 0.4s

local make = HL2Hud.Anim.make
local set  = HL2Hud.Anim.set
local step = HL2Hud.Anim.step
local snap = HL2Hud.Anim.snap

local auxColor = make(Color(0,0,0,0))
local bgColor  = make(Color(0,0,0,0))
local panelH   = make(26)  -- animated panel height in hudlayout units

local lastPower   = -1
local lastLow     = -1
local lastItems   = -1  -- item count last frame
local initialized = false

local function event(name)
    local C = HL2Hud.Colors
    if name == "SuitAuxPowerMax" then
        set(bgColor,  Color(0,0,0,0),          "Linear", 0, 0.4)
        set(auxColor, Color(0,0,0,0),          "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerNotMax" then
        set(bgColor,  C.BgColor,               "Linear", 0, 0.4)
        set(auxColor, C.AuxHigh,               "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerDecreasedBelow25" then
        set(auxColor, C.AuxLow,                "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerIncreasedAbove25" then
        set(auxColor, C.AuxHigh,               "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerNoItemsActive" then
        set(panelH, 26, "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerOneItemActive" then
        set(panelH, 36, "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerTwoItemsActive" then
        set(panelH, 46, "Linear", 0, 0.4)
    elseif name == "SuitAuxPowerThreeItemsActive" then
        set(panelH, 56, "Linear", 0, 0.4)
    end
end
HL2Hud.auxEvent = event

local function getItems()
    local ply  = LocalPlayer()
    if not IsValid(ply) then return {} end
    local suit = GetConVarNumber("gmod_suit") ~= 0
    local t    = {}
    if suit and ply:WaterLevel() == 3                                    then table.insert(t, "OXYGEN")     end
    if ply:FlashlightIsOn()                                              then table.insert(t, "FLASHLIGHT") end
    if suit and ply:IsSprinting() and ply:GetVelocity():Length2D() > 1  then table.insert(t, "SPRINT")     end
    return t
end

local elem = {}

function elem:GetSize()
    local s = ScrH() / 480
    -- If fully transparent, report zero height so EHUD doesn't reserve space
    if bgColor.cur.a < 1 and auxColor.cur.a < 1 and not initialized then
        return 102*s, 0
    end
    return 102*s, math.max(1, panelH.cur) * s
end

function elem:Draw(x, y, clip_h)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    step(auxColor) step(bgColor) step(panelH)

    local power = ply:GetSuitPower()
    local items = getItems()
    local n     = #items

    -- Initialize on first draw
    if not initialized then
        initialized = true
        local isMax = power >= 100 and n == 0
        if isMax then
            snap(bgColor,  Color(0,0,0,0))
            snap(auxColor, Color(0,0,0,0))
        else
            snap(bgColor,  HL2Hud.Colors.BgColor)
            snap(auxColor, power < 25 and HL2Hud.Colors.AuxLow or HL2Hud.Colors.AuxHigh)
        end
        local sizeEvt = ("SuitAuxPowerNoItemsActive SuitAuxPowerOneItemActive SuitAuxPowerTwoItemsActive SuitAuxPowerThreeItemsActive"):match("(%S+)%s*" .. ("()" ):rep(n))
        local evts = {"SuitAuxPowerNoItemsActive","SuitAuxPowerOneItemActive","SuitAuxPowerTwoItemsActive","SuitAuxPowerThreeItemsActive"}
        snap(panelH, ({26,36,46,56})[math.clamp(n+1,1,4)])
        lastPower = power
        lastLow   = power < 25 and 1 or 0
        lastItems = n
    end

    -- Visibility events
    local isMax = power >= 100 and n == 0
    if isMax and lastPower ~= -2 and not (lastPower >= 100 and lastItems == 0) then
        event("SuitAuxPowerMax")
        lastPower = -2  -- sentinel for "max"
    elseif not isMax and (lastPower == -2 or lastPower == -1) then
        event("SuitAuxPowerNotMax")
    end
    if not isMax then lastPower = power end

    -- Low power events
    local lowNow = power < 25 and 1 or 0
    if lastLow >= 0 and lowNow ~= lastLow then
        event(lowNow == 1 and "SuitAuxPowerDecreasedBelow25" or "SuitAuxPowerIncreasedAbove25")
    end
    lastLow = lowNow

    -- Item count size events
    if n ~= lastItems then
        local evts = {"SuitAuxPowerNoItemsActive","SuitAuxPowerOneItemActive","SuitAuxPowerTwoItemsActive","SuitAuxPowerThreeItemsActive"}
        event(evts[math.Clamp(n+1,1,4)])
        lastItems = n
    end

    -- Skip drawing if fully transparent
    local col = auxColor.cur
    local bg  = bgColor.cur
    if col.a < 1 and bg.a < 1 then return end

    local s = ScrH() / 480
    local h = clip_h

    draw.RoundedBox(6, x, y, 102*s, h, bg)

    -- Bar (BarInsetX=8 BarInsetY=15 BarWidth=92 BarHeight=4 BarChunkWidth=6 BarChunkGap=3)
    local bx, by = x + 8*s, y + 15*s
    local bw, bh = 92*s, 4*s
    local cw, cg = 6*s, 3*s
    local count  = math.floor(bw / (cw + cg))
    local filled = math.floor(count * (power / 100) + 0.5)
    local cx     = bx
    surface.SetDrawColor(col)
    for i = 1, filled       do surface.DrawRect(cx, by, cw, bh) cx = cx + cw + cg end
    surface.SetDrawColor(Color(col.r, col.g, col.b, HL2Hud.Colors.AuxDisabled))
    for i = filled+1, count do surface.DrawRect(cx, by, cw, bh) cx = cx + cw + cg end

    -- Label (text_xpos=8 text_ypos=4)
    surface.SetFont("HL2Hud_Text")
    surface.SetTextColor(col)
    surface.SetTextPos(x + 8*s, y + 4*s)
    surface.DrawText("AUX POWER")

    -- Item labels (text2_xpos=8 text2_ypos=22 text2_gap=10)
    local iy = y + 22*s
    for _, name in ipairs(items) do
        surface.SetTextPos(x + 8*s, iy)
        surface.DrawText(name)
        iy = iy + 10*s
    end
end

HL2Hud.auxElem = elem
