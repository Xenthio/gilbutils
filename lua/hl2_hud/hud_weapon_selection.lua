-- hud_weapon_selection.lua
-- 1:1 port of CHudWeaponSelection (hud_weaponselection.cpp) — HUDTYPE_BUCKETS mode
-- Layout: hudlayout.res (garrysmod.vpk)
-- Colors: ClientScheme.res
-- Animations: hudanimations.txt
-- Icon chars: hl2/scripts/weapon_*.txt ("bucket"/"bucket_position"/"character")

if not CLIENT then return end

local make = HL2Hud.Anim.make
local aset = HL2Hud.Anim.set
local step = HL2Hud.Anim.step
local snap = HL2Hud.Anim.snap

------------------------------------------------------------------------
-- Layout — hudlayout.res HudWeaponSelection (proportional 480p baseline)
------------------------------------------------------------------------
local SMALL     = 32   -- SmallBoxSize
local LWIDE     = 112  -- LargeBoxWide
local LTALL     = 80   -- LargeBoxTall
local GAP       = 8    -- BoxGap
local NUM_XPOS  = 4    -- SelectionNumberXPos
local NUM_YPOS  = 4    -- SelectionNumberYPos
local TEXT_YPOS = 64   -- TextYPos
local PANEL_Y   = 16   -- ypos

-- Corner radius to match vgui/hud/800corner textures (8px at 800px wide ≈ 6px at 480p baseline)
-- Corner radius 8 (unscaled) matches vgui/hud/800corner texture proportions
local CORNER_R  = 8

local SELECTION_TIMEOUT  = 0.5
local SELECTION_FADEOUT  = 0.75
local MAX_WEAPON_SLOTS   = 6

------------------------------------------------------------------------
-- Colors — ClientScheme.res
------------------------------------------------------------------------
local C_NumberFg   = Color(255, 220, 0, 255)  -- SelectionNumberFg
local C_TextFg     = Color(255, 220, 0, 255)  -- SelectionTextFg / BrightFg
local C_BoxBg      = Color(0, 0, 0, 80)       -- SelectionBoxBg
local C_EmptyBg    = Color(0, 0, 0, 80)       -- SelectionEmptyBoxBg
local C_SelectedBg = Color(0, 0, 0, 80)       -- SelectionSelectedBoxBg
local C_FgColor    = Color(255, 220, 0, 255)  -- FgColor
local C_BgColor    = Color(0, 0, 0, 76)       -- BgColor

------------------------------------------------------------------------
-- Animated panel vars  (CPanelAnimationVar equivalents)
-- Alpha "0", SelectionAlpha "0", FgColor, TextColor(BrightFg), TextScan "1", Blur "0"
------------------------------------------------------------------------
local animAlpha    = make(0)
local animSelAlpha = make(0)
local animFgColor  = make(Color(0, 0, 0, 0))
local animTextColor= make(Color(0, 0, 0, 0))
local animTextScan = make(1)
local animBlur     = make(0)

-- Non-animated colors (from scheme, constant)
local m_BoxColor      = C_BoxBg
local m_EmptyBoxColor = C_EmptyBg
local m_SelBoxColor   = C_SelectedBg
local m_SelFgColor    = C_FgColor
local m_NumberColor   = C_NumberFg
local m_TextColor     = C_TextFg

------------------------------------------------------------------------
-- HL2 weapon icon characters
-- Source: Half-Life 2/hl2/scripts/weapon_*.txt — "weapon" → "character"
-- bucket → GetSlot(), bucket_position → GetSlotPos()
-- slot 0: crowbar(c), physcannon(m), stunstick(n)
-- slot 1: pistol(d), 357(e), alyxgun(?)
-- slot 2: smg1(a), ar2(l), shotgun(b)/annabelle(b)
-- slot 3: crossbow(g)
-- slot 4: rpg(i), frag(k)
-- slot 5: bugbait(j)
------------------------------------------------------------------------
local ICON_CHARS = {
    weapon_crowbar        = "c",
    weapon_physcannon     = "m",
    weapon_physgun        = "m",  -- GMod gravity gun SWEP (same glyph as physcannon)
    weapon_stunstick      = "n",
    weapon_pistol         = "d",
    weapon_357            = "e",
    weapon_alyxgun        = "c",  -- alyxgun script missing, approximate
    weapon_annabelle      = "b",
    weapon_smg1           = "a",
    weapon_ar2            = "l",
    weapon_shotgun        = "b",
    weapon_crossbow       = "g",
    weapon_rpg            = "i",
    weapon_frag           = "k",
    weapon_slam           = "h",
    weapon_bugbait        = "j",
    weapon_striderbuster  = "f",
    weapon_manhack        = "o",
}

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------
local isOpen          = false
local fadingOut       = false
local selectionTime   = -999
local selectedWep     = nil
local justClosedTime  = -999

------------------------------------------------------------------------
-- Scale helper
------------------------------------------------------------------------
local function Scale(v) return v * ScrH() / 480 end

------------------------------------------------------------------------
-- Weapon queries (mirror CBaseHudWeaponSelection helpers)
------------------------------------------------------------------------
local function GetWeaponInSlot(ply, iSlot, iSlotPos)
    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) and wep:GetSlot() == iSlot and wep:GetSlotPos() == iSlotPos then
            return wep
        end
    end
end

local function GetFirstPos(ply, iSlot)
    local lowest, lowestWep = math.huge, nil
    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) and wep:GetSlot() == iSlot then
            local p = wep:GetSlotPos()
            if p < lowest then lowest = p; lowestWep = wep end
        end
    end
    return lowestWep
end

local function GetLastPosInSlot(ply, iSlot)
    local highest = -1
    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) and wep:GetSlot() == iSlot then
            local p = wep:GetSlotPos()
            if p > highest then highest = p end
        end
    end
    return highest
end

local function FindNextWeapon(ply, curSlot, curPos)
    local bestSlot, bestPos, bestWep = MAX_WEAPON_SLOTS, math.huge, nil
    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) then
            local s, p = wep:GetSlot(), wep:GetSlotPos()
            if s > curSlot or (s == curSlot and p > curPos) then
                if s < bestSlot or (s == bestSlot and p < bestPos) then
                    bestSlot, bestPos, bestWep = s, p, wep
                end
            end
        end
    end
    return bestWep
end

local function FindPrevWeapon(ply, curSlot, curPos)
    local bestSlot, bestPos, bestWep = -1, -1, nil
    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) then
            local s, p = wep:GetSlot(), wep:GetSlotPos()
            if s < curSlot or (s == curSlot and p < curPos) then
                if s > bestSlot or (s == bestSlot and p > bestPos) then
                    bestSlot, bestPos, bestWep = s, p, wep
                end
            end
        end
    end
    return bestWep
end

-- GetNextActivePos: finds weapon in iSlot with lowest SlotPos >= iSlotPos
local function GetNextActivePos(ply, iSlot, iSlotPos)
    local lowest, lowestWep = math.huge, nil
    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) and wep:GetSlot() == iSlot then
            local p = wep:GetSlotPos()
            if p >= iSlotPos and p < lowest then
                lowest = p; lowestWep = wep
            end
        end
    end
    return lowestWep
end

------------------------------------------------------------------------
-- Animation events
------------------------------------------------------------------------
local function DoOpenSelection()
    -- OpenWeaponSelectionMenu (hudanimations.txt exact match)
    aset(animAlpha,     128,       "Linear", 0, 0.1)
    aset(animSelAlpha,  255,       "Linear", 0, 0.1)
    aset(animFgColor,   C_FgColor, "Linear", 0, 0.1)
    aset(animTextColor, C_TextFg,  "Linear", 0, 0.1)
    snap(animTextScan,  1)   -- TextScan "1" Linear 0.0 0.1 = instant set in practice

    -- This sound doesn't actually play in HL2
    --LocalPlayer():EmitSound("common/wpn_hudon.wav", 75, 100, 0.32)
    isOpen    = true
    fadingOut = false
end

local function DoFadeOut()
    -- FadeOutWeaponSelectionMenu (delay 0.5, dur 1.0 → fades over 1s after 0.5s)
    aset(animFgColor,   Color(0,0,0,0), "Linear", 0.5, 1.0)
    aset(animTextColor, Color(0,0,0,0), "Linear", 0.5, 1.0)
    aset(animAlpha,     0,              "Linear", 0.5, 1.0)
    aset(animSelAlpha,  0,              "Linear", 0.5, 1.0)
    fadingOut = true
end

local function DoHideSelection()
    -- CloseWeaponSelectionMenu (hudanimations.txt)
    aset(animFgColor,   Color(0,0,0,0), "Linear", 0, 0.1)
    aset(animTextColor, Color(0,0,0,0), "Linear", 0, 0.1)
    aset(animAlpha,     0,              "Linear", 0, 0.1)
    aset(animSelAlpha,  0,              "Linear", 0, 0.1)
    if isOpen then
        LocalPlayer():EmitSound("common/wpn_hudoff.wav", 75, 100, 0.32)
    end
    isOpen      = false
    fadingOut   = false
    selectedWep = nil
end

local function DoSelectWeapon(wep)
    selectedWep   = wep
    selectionTime = CurTime()
    -- Blur = 7 → 0 over 0.75s Deaccel (from ActivateFastswitchWeaponDisplay, used in all modes)
    snap(animBlur, 7)
    aset(animBlur, 0, "Deaccel", 0, 0.75)
end

------------------------------------------------------------------------
-- Input handling
------------------------------------------------------------------------
hook.Add("PlayerBindPress", "HL2Hud_WeaponSelection", function(ply, bind, pressed)
    if not pressed then return end
    local lply = LocalPlayer()
    if not IsValid(lply) then return end

    -- slot1..slot6
    local slot = tonumber(bind:match("^slot(%d)$"))
    if slot then
        slot = slot - 1  -- convert to 0-based bucket index
        if slot >= MAX_WEAPON_SLOTS then return end

        -- HUDTYPE_BUCKETS: SelectWeaponSlot logic (from SelectWeaponSlot source)
        local slotPos = 0
        if isOpen and IsValid(selectedWep) and selectedWep:GetSlot() == slot then
            slotPos = selectedWep:GetSlotPos() + 1
        end
        local newWep = GetNextActivePos(lply, slot, slotPos)
        if not IsValid(newWep) then
            newWep = GetNextActivePos(lply, slot, 0)
        end
        if IsValid(newWep) then
            if not isOpen and (CurTime() - justClosedTime) > 0.05 then DoOpenSelection() end
            DoSelectWeapon(newWep)
            LocalPlayer():EmitSound("common/wpn_moveselect.wav", 75, 100, 0.32)
        end
        return true
    end

    if bind == "invnext" then
        local cur = isOpen and selectedWep or lply:GetActiveWeapon()
        local next = IsValid(cur) and FindNextWeapon(lply, cur:GetSlot(), cur:GetSlotPos()) or nil
        if not IsValid(next) then next = FindNextWeapon(lply, -1, -1) end
        if IsValid(next) then
            if not isOpen then DoOpenSelection() end
            DoSelectWeapon(next)
            LocalPlayer():EmitSound("common/wpn_moveselect.wav", 75, 100, 0.32)
        end
        return true
    end

    if bind == "invprev" then
        local cur = isOpen and selectedWep or lply:GetActiveWeapon()
        local prev = IsValid(cur) and FindPrevWeapon(lply, cur:GetSlot(), cur:GetSlotPos()) or nil
        if not IsValid(prev) then prev = FindPrevWeapon(lply, MAX_WEAPON_SLOTS, math.huge) end
        if IsValid(prev) then
            if not isOpen then DoOpenSelection() end
            DoSelectWeapon(prev)
            LocalPlayer():EmitSound("common/wpn_moveselect.wav", 75, 100, 0.32)
        end
        return true
    end

    -- +attack / +use confirms weapon selection
    if (bind == "+attack" or bind == "+use") and isOpen and IsValid(selectedWep) then
        local cls = selectedWep:GetClass()
        DoHideSelection()  -- hide first so next draw pass is clean
        RunConsoleCommand("use", cls)
        LocalPlayer():EmitSound("common/wpn_select.wav", 75, 100, 0.32)
        return true
    end
end)

------------------------------------------------------------------------
-- OnThink: timeout → FadeOut → Hide
------------------------------------------------------------------------
hook.Add("Think", "HL2Hud_WeaponSelection_Think", function()
    if not isOpen then return end
    local elapsed = CurTime() - selectionTime
    if elapsed > SELECTION_TIMEOUT then
        if not fadingOut then
            DoFadeOut()
        elseif elapsed > SELECTION_TIMEOUT + SELECTION_FADEOUT then
            DoHideSelection()
            justClosedTime = CurTime()
        end
    elseif fadingOut then
        -- re-opened during fade
        DoOpenSelection()
    end
end)

------------------------------------------------------------------------
-- DrawBox — CHudWeaponSelection::DrawBox + BaseClass::DrawBox
-- BaseClass::DrawBox uses vgui/hud/800corner textures (rounded corners)
-- Corner size ≈ 6px at 480p baseline
------------------------------------------------------------------------
local function DrawBox(x, y, wide, tall, color, normalizedAlpha, number)
    surface.SetAlphaMultiplier(normalizedAlpha / 255)
    draw.RoundedBox(CORNER_R, x, y, wide, tall, color)
    if number >= 0 then
        surface.SetFont("HL2Hud_SelectionNumbers")
        surface.SetTextColor(m_NumberColor)
        surface.SetTextPos(x + Scale(NUM_XPOS), y + Scale(NUM_YPOS))
        surface.DrawText(tostring(number))
    end
    surface.SetAlphaMultiplier(1)
end

------------------------------------------------------------------------
-- DrawWeaponIcon — draws inactive icon; for selected: blur glow passes
-- Source BUCKETS case: always uses inactive sprite, then active w/ blur
-- In GMod HL2 weapons use HalfLife2 font chars; SWEPs use DrawWeaponSelection
------------------------------------------------------------------------
local function DrawWeaponIcon(wep, bSelected, x, y, boxWide, boxTall, fgAlpha)
    local cls  = wep:GetClass()
    local char = ICON_CHARS[cls]

    -- Clip icon drawing to box bounds (prevents overdraw on adjacent slots)
    render.SetScissorRect(x, y, x + boxWide, y + boxTall, true)

    if char then
        -- BUCKETS mode: draw inactive icon first, then active (glow/scanlines) on top if selected
        -- Source: GetSpriteInactive()->DrawSelf() always; if bSelected: GetSpriteActive()->DrawSelf()
        local fgCol = bSelected and m_SelFgColor or animFgColor.cur
        surface.SetAlphaMultiplier(fgAlpha / 255)

        -- Inactive pass
        surface.SetFont("HL2Hud_WeaponIcons")
        local iw, ih = surface.GetTextSize(char)
        local xo = math.floor((boxWide - iw) / 2)
        local yo = math.floor((boxTall - ih) / 2)
        surface.SetTextColor(fgCol)
        surface.SetTextPos(x + xo, y + yo)
        surface.DrawText(char)

        if bSelected then
            -- Active pass: WeaponIconsSelected font (blur=2, scanlines=2 baked in)
            -- animBlur drives alpha of this pass (7=full glow → 0=gone on close)
            local glowA = math.Clamp(animSelAlpha.cur / 7, 0, 1)
            surface.SetAlphaMultiplier(glowA)
            surface.SetFont("HL2Hud_WeaponIconsSelected")
            local sw, sh = surface.GetTextSize(char)
            local sxo = math.floor((boxWide - sw) / 2)
            local syo = math.floor((boxTall - sh) / 2)
            surface.SetTextColor(fgCol)
            surface.SetTextPos(x + sxo, y + syo)
            surface.DrawText(char)
        end

        surface.SetAlphaMultiplier(1)
    else
        -- SWEP fallback — mirror DyaMetR: disable bounce/infobox for unselected weapons
        render.SetScissorRect(0, 0, 0, 0, false)
        if wep.DrawWeaponSelection then
            local bounce = wep.BounceWeaponIcon
            local info   = wep.DrawWeaponInfoBox
            if not bSelected then
                wep.BounceWeaponIcon  = false
                wep.DrawWeaponInfoBox = false
            end
            wep:DrawWeaponSelection(x, y, boxWide, boxTall, fgAlpha)
            wep.BounceWeaponIcon  = bounce
            wep.DrawWeaponInfoBox = info
        end
        render.SetScissorRect(x, y, x + boxWide, y + boxTall, true)
    end

    render.SetScissorRect(0, 0, 0, 0, false)
end

------------------------------------------------------------------------
-- DrawLargeWeaponBox — CHudWeaponSelection::DrawLargeWeaponBox BUCKETS case
------------------------------------------------------------------------
local function DrawLargeWeaponBox(wep, bSelected, x, y, boxWide, boxTall, selColor, alpha, number)
    DrawBox(x, y, boxWide, boxTall, selColor, alpha, number)
    if not IsValid(wep) then return end

    DrawWeaponIcon(wep, bSelected, x, y, boxWide, boxTall, alpha)

    -- Weapon name text (selected only)
    if bSelected then
        local tc = animTextColor.cur
        local ta = math.Clamp(tc.a * (alpha / 255), 0, 255)
        surface.SetFont("HL2Hud_WeaponText")
        surface.SetTextColor(tc.r, tc.g, tc.b, ta)

        -- PrintName lookup: SWEPs have stored.PrintName; HL2 C++ weapons use localized string
        -- language.GetPhrase resolves "#HL2_Shotgun" etc. via loaded language files
        -- weapon:GetPrintName() handles both SWEPs and C++ weapons, returns localized name
        local rawName = wep:GetPrintName()
        -- TextScan: reveal name char by char (charCount *= m_flTextScan)
        local ts    = animTextScan.cur
        local name  = rawName:sub(1, math.max(1, math.floor(#rawName * ts)))
        local tw, _ = surface.GetTextSize(name)
        local tx    = x + math.floor((boxWide - tw) / 2)
        local ty    = y + Scale(TEXT_YPOS)
        surface.SetTextPos(tx, ty)
        surface.DrawText(name)
    end
end

------------------------------------------------------------------------
-- Paint — CHudWeaponSelection::Paint() HUDTYPE_BUCKETS
------------------------------------------------------------------------
hook.Add("HUDPaint", "HL2Hud_WeaponSelection", function()
    -- Advance animations
    step(animAlpha)
    step(animSelAlpha)
    step(animFgColor)
    step(animTextColor)
    step(animBlur)
    step(animTextScan)

    local alpha = animAlpha.cur
    if alpha < 1 then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- BUCKETS mode: pSelectedWeapon = GetSelectedWeapon() (our selectedWep)
    local pSel = selectedWep
    if not IsValid(pSel) then
        pSel = ply:GetActiveWeapon()
        if not IsValid(pSel) then return end
    end

    local smallSize = Scale(SMALL)
    local largeWide = Scale(LWIDE)
    local largeTall = Scale(LTALL)
    local boxGap    = Scale(GAP)
    local panelY    = Scale(PANEL_Y)

    -- percentageDone = 1.0 (pickup grow removed in source)
    -- selectedColor = lerp(BoxColor, SelectedBoxColor, 1.0) = SelectedBoxColor
    local selectedColor = m_SelBoxColor

    -- width = (MAX_WEAPON_SLOTS-1)*(smallSize+boxGap) + largeWide
    -- xpos  = (ScrW() - width) / 2
    local totalWidth = (MAX_WEAPON_SLOTS - 1) * (smallSize + boxGap) + largeWide
    local xpos = math.floor((ScrW() - totalWidth) / 2)
    local ypos = panelY

    local selAlpha = animSelAlpha.cur
    local iActiveSlot = pSel:GetSlot()

    -- hud_showemptyweaponslots: only affects empty POSITIONS within the active expanded slot
    -- Defaulting to false avoids the gmod_camera pos=0 gap (camera lives at slot5/pos1)
    local showEmptyCv = GetConVar("hud_showemptyweaponslots")
    local showEmpty = showEmptyCv and showEmptyCv:GetBool() or false

    -- GetWeaponBoxAlpha mirrors source: selected=selAlpha, unselected=selAlpha*(alpha/255)
    local function BoxAlpha(bSelected)
        if bSelected then return selAlpha end
        return selAlpha * (alpha / 255)
    end

    for i = 0, MAX_WEAPON_SLOTS - 1 do
        if i == iActiveSlot then
            -- Expanded active slot — draw all weapons in this slot vertically
            local iLastPos = GetLastPosInSlot(ply, i)

            -- If active slot is somehow empty, draw small box (fallback) and continue
            if iLastPos < 0 then
                xpos = xpos + smallSize
                xpos = xpos + boxGap
                ypos = panelY
                continue
            end

            local bDrawNumber = true
            for slotpos = 0, iLastPos do
                local wep = GetWeaponInSlot(ply, i, slotpos)
                if not IsValid(wep) then
                    if showEmpty then
                        DrawBox(xpos, ypos, largeWide, largeTall, m_EmptyBoxColor, alpha,
                                bDrawNumber and (i + 1) or -1)
                    else
                        continue  -- source: if !hud_showemptyweaponslots, skip this slotpos entirely
                    end
                else
                    local bSel = (wep == pSel)
                    DrawLargeWeaponBox(wep, bSel,
                        xpos, ypos, largeWide, largeTall,
                        bSel and selectedColor or m_BoxColor,
                        BoxAlpha(bSel),
                        bDrawNumber and (i + 1) or -1)
                end
                ypos = ypos + largeTall + boxGap
                bDrawNumber = false
            end

            xpos = xpos + largeWide
        else
            -- Inactive slot — source always draws box regardless of showEmpty (only active slot inner positions obey it)
            local firstWep = GetFirstPos(ply, i)
            if IsValid(firstWep) then
                DrawBox(xpos, ypos, smallSize, smallSize, m_BoxColor, alpha, i + 1)
            else
                DrawBox(xpos, ypos, smallSize, smallSize, m_EmptyBoxColor, alpha, -1)
            end
            xpos = xpos + smallSize
        end

        ypos = panelY  -- reset Y for next slot
        xpos = xpos + boxGap
    end
end)

------------------------------------------------------------------------
-- Suppress native CHudWeaponSelection
------------------------------------------------------------------------
hook.Add("HUDShouldDraw", "HL2Hud_WeaponSelection_Hide", function(name)
    if name == "CHudWeaponSelection" then return false end
end)

-- Live color sync: update local color vars from HL2Hud.Colors each frame
hook.Add("HUDPaint", "HL2Hud_WeaponSelection_ColorSync", function()
    local C = HL2Hud.Colors
    C_NumberFg = C.FgColor
    C_TextFg   = C.BrightFg
    C_FgColor  = C.FgColor
    m_SelFgColor  = C.FgColor
    m_NumberColor = C.FgColor
    m_TextColor   = C.BrightFg
end)

-- Export for external use
HL2Hud.weaponSel = {
    open  = DoOpenSelection,
    hide  = DoHideSelection,
    fade  = DoFadeOut,
}
