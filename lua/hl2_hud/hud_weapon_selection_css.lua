-- hud_weapon_selection_css.lua
-- CS:S weapon selection — cs_hud_weaponselection.cpp / hudlayout.res
-- Dispatched via hook "HL2Hud_WeaponSelectionPaint"; returns true to suppress HL2 paint.
--
-- Key differences from HL2:
--   - SmallBoxSize=60 (large), LargeBoxTall=80, BoxGap=8, MaxSlots=5
--   - TextYPos=68 (near bottom of 80-tall large box), IconXPos=8, IconYPos=0
--   - 3 distinct box BG colors: empty(0,0,0,80), filled(0,0,0,80), selected(0,0,0,190)
--   - SelectionNumberFg/TextFg = 255 220 0 200 (semi-transparent orange)
--   - NO fade-out: Close event = same as Open (stays at 128/255 until weapon equipped)
--   - CSS health/ammo panels drawn here too (separate from HL2 elements)

if not CLIENT then return end

------------------------------------------------------------------------
-- Layout — from hudlayout.res (NOT the C++ source defaults which differ)
------------------------------------------------------------------------
local SMALL    = 60    -- SmallBoxSize
local LWIDE    = 108   -- LargeBoxWide
local LTALL    = 80    -- LargeBoxTall
local GAP      = 8     -- BoxGap
local NUM_XPOS = 4     -- SelectionNumberXPos
local NUM_YPOS = 4     -- SelectionNumberYPos
local ICON_X   = 8     -- IconXPos
local ICON_Y   = 0     -- IconYPos
local TEXT_Y   = 68    -- TextYPos (from top of LTALL box)
local PANEL_Y  = 16    -- ypos in hudlayout
local MAX_SLOTS = 5

------------------------------------------------------------------------
-- CSS colors
------------------------------------------------------------------------
local C_NumberFg = Color(255, 220, 0, 200)
local C_TextFg   = Color(255, 220, 0, 200)
local C_EmptyBg  = Color(  0,   0, 0,  80)
local C_BoxBg    = Color(  0,   0, 0,  80)
local C_SelBg    = Color(  0,   0, 0, 190)

local function Scale(v) return v * ScrH() / 480 end

------------------------------------------------------------------------
-- Shared DrawPanel reference
------------------------------------------------------------------------
local function DrawBox(x, y, w, h, col, alpha, number)
    local a = math.Round(col.a * (alpha / 255))
    HL2Hud.DrawPanel(x, y, w, h, Color(col.r, col.g, col.b, a))

    if number and number >= 0 then
        surface.SetFont("HL2Hud_SelectionNumbers")
        surface.SetTextColor(C_NumberFg.r, C_NumberFg.g, C_NumberFg.b,
            math.Round(C_NumberFg.a * (alpha / 255)))
        surface.SetTextPos(x + Scale(NUM_XPOS), y + Scale(NUM_YPOS))
        surface.DrawText(tostring(number))
    end
end

------------------------------------------------------------------------
-- CSS weapon selection Paint
-- alpha      = panel alpha (0-255); selAlpha = selected weapon alpha
-- selWep     = currently selected weapon entity
-- textAlpha  = animTextColor.a (for weapon name fade)
-- textScan   = animTextScan (character reveal, 0-1)
------------------------------------------------------------------------
hook.Add("HL2Hud_WeaponSelectionPaint", "CSS_WeaponSelection", function(
        alpha, selAlpha, selWep, ply, animFgColor, animTextColor, textScan)

    if not (HL2Hud.Themes and HL2Hud.ActiveTheme) then return end
    local theme = HL2Hud.Themes[HL2Hud.ActiveTheme]
    if not theme or theme.weaponSelection ~= "css" then return end

    local smallSize = Scale(SMALL)
    local largeWide = Scale(LWIDE)
    local largeTall = Scale(LTALL)
    local gap       = Scale(GAP)
    local panelY    = Scale(PANEL_Y)

    local iActiveSlot = IsValid(selWep) and selWep:GetSlot() or -1

    -- Total width: 4 small + 1 large + 4 gaps
    local totalWidth = (MAX_SLOTS - 1) * (smallSize + gap) + largeWide
    local xpos = math.floor((ScrW() - totalWidth) / 2)

    for i = 0, MAX_SLOTS - 1 do
        local isActive = (i == iActiveSlot)
        local bw = isActive and largeWide or smallSize
        local bh = isActive and largeTall or smallSize

        -- Find first weapon in slot
        local slotWep = nil
        for _, w in ipairs(ply:GetWeapons()) do
            if IsValid(w) and w:GetSlot() == i then
                if slotWep == nil or w:GetSlotPos() < slotWep:GetSlotPos() then
                    slotWep = w
                end
            end
        end

        local hasWep = IsValid(slotWep)
        local boxCol = isActive and C_SelBg or (hasWep and C_BoxBg or C_EmptyBg)
        local boxA   = isActive and selAlpha or alpha

        DrawBox(xpos, panelY, bw, bh, boxCol, boxA, i + 1)

        if isActive and IsValid(selWep) then
            -- Draw weapon icon
            local cls  = selWep:GetClass()
            local icons = HL2Hud.weaponSel and HL2Hud.weaponSel.iconChars
            local char  = icons and icons[cls]

            render.SetScissorRect(xpos, panelY, xpos + bw, panelY + bh, true)
            if char then
                surface.SetFont("HL2Hud_WeaponIcons")
                local ix = xpos + Scale(ICON_X)
                local iy = panelY + Scale(ICON_Y)
                surface.SetAlphaMultiplier(selAlpha / 255)
                -- CSS weapon icon uses GetFgColor() = panel FgColor = OrangeDim (255,176,0)
                -- SelectionTextFg (255,220,0) only applies to text/numbers
                local ic = HL2Hud.Colors.FgColor
                surface.SetTextColor(ic.r, ic.g, ic.b, ic.a)
                surface.SetTextPos(ix, iy)
                surface.DrawText(char)
            elseif HL2Hud.DrawWeaponSprite then
                HL2Hud.DrawWeaponSprite(cls, true,
                    xpos + Scale(ICON_X), panelY + Scale(ICON_Y),
                    bw - Scale(ICON_X) * 2, bh - (bh - Scale(TEXT_Y)),
                    selAlpha, selAlpha / 255)
            end
            surface.SetAlphaMultiplier(1)
            render.SetScissorRect(0, 0, 0, 0, false)

            -- Weapon name at TextYPos from top
            local ta = animTextColor and math.Round(animTextColor.a * (selAlpha / 255)) or selAlpha
            if ta > 0 then
                surface.SetFont("HL2Hud_WeaponText")
                surface.SetTextColor(C_TextFg.r, C_TextFg.g, C_TextFg.b, ta)
                local rawName = selWep:GetPrintName()
                local ts   = textScan or 1
                local name = rawName:sub(1, math.max(1, math.floor(#rawName * ts)))
                local tw   = surface.GetTextSize(name)
                local tx   = xpos + math.floor((bw - tw) / 2)
                local ty   = panelY + Scale(TEXT_Y)
                surface.SetTextPos(tx, ty)
                surface.DrawText(name)
            end
        end

        xpos = xpos + bw + gap
    end

    return true  -- handled: suppress HL2 paint
end)

------------------------------------------------------------------------
-- CSS-specific: no fade-out — CloseWeaponSelection just keeps it visible
-- We hook into the HL2Hud.weaponSel.fade override for CSS mode
------------------------------------------------------------------------
hook.Add("HL2Hud_WeaponSelectionFade", "CSS_WeaponSelection", function()
    if not (HL2Hud.Themes and HL2Hud.ActiveTheme) then return end
    local theme = HL2Hud.Themes[HL2Hud.ActiveTheme]
    if not theme or theme.weaponSelection ~= "css" then return end
    -- CSS: CloseWeaponSelectionMenu = same as OpenWeaponSelectionMenu (no fade)
    -- Just leave alpha at 128/selAlpha 255, let game hide via HideSelection
    return true  -- suppress HL2 fade
end)
