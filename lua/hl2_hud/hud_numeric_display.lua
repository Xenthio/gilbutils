-- hud_numeric_display.lua
-- Port of CHudNumericDisplay + layout-driven draw system.
--
-- Layouts are declared in hud_themes.lua under theme.layouts[name].
-- HL2Hud.GetLayout(name) returns the active theme's layout (or the default).
-- HL2Hud.DrawElement(x, y, value, state, layout) renders it — no element file
-- needs to know which theme is active.
--
-- Layout fields (all positional values in 480p hudlayout units):
--   wide, tall          — panel size
--   panel               — "flat" (HL2 DrawPanel) | "rounded" (CSS RoundedBox)
--   font                — font name for primary number
--   glow_font           — font name for glow pass (nil = no glow)
--   small_font          — font name for secondary/reserve number
--   indent              — bool: PaintNumbers SetIndent mode (pads to 3 chars)
--   digit_xpos/ypos     — primary number offset from panel top-left
--   digit2_xpos/ypos    — secondary (reserve) number offset
--   text_xpos/ypos      — label text offset (nil = no label)
--   label               — label string (nil = no label)
--   icon_char           — font glyph character for icon (nil = no icon)
--   icon_font           — font name for icon
--   icon_xpos/ypos      — icon offset from panel top-left

------------------------------------------------------------------------
-- Scale helper (exported so element files can use it)
------------------------------------------------------------------------
local function S(v) return v * ScrH() / 480 end
HL2Hud.Scale = S

-- Returns the active theme's layout for the named element, or the default.
------------------------------------------------------------------------
function HL2Hud.GetLayout(name)
    local theme = HL2Hud.Themes and HL2Hud.Themes[HL2Hud.ActiveTheme]
    local themeLayout = theme and theme.layouts and theme.layouts[name]
    -- false = explicitly disabled by theme (e.g. CSS ammo_secondary)
    if themeLayout == false then return nil end
    return themeLayout or (HL2Hud.DefaultLayouts and HL2Hud.DefaultLayouts[name]) or {}
end

------------------------------------------------------------------------
-- Internal: draw panel background according to layout.panel
------------------------------------------------------------------------
local function drawPanelBg(x, y, w, h, bg, layout)
    if layout.panel == "rounded" then
        local r = math.Round(S(layout.corner_radius or 4))
        draw.RoundedBox(r, x, y, w, h, bg)
    else
        HL2Hud.DrawPanel(x, y, w, h, bg)
    end
end

------------------------------------------------------------------------
-- Internal: PaintNumbers — direct port of CHudNumericDisplay::PaintNumbers
-- indent = SetIndent(true): pads to 3 chars from left by one charWidth each
------------------------------------------------------------------------
local function paintNumbers(font, x, y, value, indent)
    surface.SetFont(font)
    local n = tonumber(value)
    if indent and n then
        local cw = surface.GetTextSize("0")
        if n < 100 then x = x + cw end
        if n < 10  then x = x + cw end
    end
    surface.SetTextPos(x, y)
    surface.DrawText(tostring(value))
end

------------------------------------------------------------------------
-- HL2Hud.DrawElement(x, y, value, state, layout)
-- Unified draw — handles both HL2 and CSS panel styles from layout data.
--
-- x, y     = screen position (top-left of panel)
-- value    = primary integer value to display
-- state    = { fgColor={cur=Color}, bgColor={cur=Color}, blur={cur=n} }
-- layout   = from HL2Hud.GetLayout()
--
-- Returns: panel width, panel height (scaled pixels)
------------------------------------------------------------------------
function HL2Hud.DrawElement(x, y, value, state, layout)
    local w = S(layout.wide or 102)
    local h = S(layout.tall or 36)
    local fc = state.fgColor.cur
    local bg = state.bgColor.cur

    -- Background
    if bg.a > 0 then
        drawPanelBg(x, y, w, h, bg, layout)
    end

    -- Icon (CSS health/armor icon glyph; drawn before numbers so numbers paint on top if needed)
    if layout.icon_char and layout.icon_font then
        surface.SetFont(layout.icon_font)
        surface.SetTextColor(fc.r, fc.g, fc.b, fc.a)
        local ix = x + S(layout.icon_xpos or 8)
        -- icon_ypos: positive = down from panel top, negative = overhang above
        local iy = y + S(layout.icon_ypos or 0)
        surface.SetTextPos(ix, iy)
        surface.DrawText(layout.icon_char)
    end

    -- Label text (PaintLabel — uses fgColor same as number, per CHudNumericDisplay source)
    if layout.label and layout.text_xpos then
        surface.SetFont(layout.text_font or "HL2Hud_Text")
        surface.SetTextColor(fc.r, fc.g, fc.b, fc.a)
        surface.SetTextPos(x + S(layout.text_xpos), y + S(layout.text_ypos or 20))
        surface.DrawText(layout.label)
    end

    -- Primary number + glow (CHudNumericDisplay::Paint loop)
    local dx = x + S(layout.digit_xpos or 50)
    local dy = y + S(layout.digit_ypos or 2)
    local font     = layout.font      or "HL2Hud_Numbers"
    local glowFont = layout.glow_font or "HL2Hud_NumbersGlow"
    local blur     = state.blur.cur

    if blur > 0 and layout.glow_font ~= false then
        surface.SetFont(glowFont)
        for fl = blur, 0, -1 do
            local a = fl >= 1 and fc.a or (fc.a * fl)
            surface.SetTextColor(Color(fc.r, fc.g, fc.b, math.Clamp(a, 0, 255)))
            paintNumbers(glowFont, dx, dy, value, layout.indent)
            if fl < 1 then break end
        end
    end
    surface.SetTextColor(fc.r, fc.g, fc.b, fc.a)
    paintNumbers(font, dx, dy, value, layout.indent)

    return w, h
end

------------------------------------------------------------------------
-- HL2Hud.DrawCSSAmmoIcon(cls, ix, iy, col)
-- Draws a CSS ammo-type icon (sprite sheet or font glyph).
-- Icon data from CSS mod_textures.txt TextureData section.
------------------------------------------------------------------------
local CSS_AMMO_ICONS = {
    -- 9mm
    weapon_glock        = { file="sprites/640hud1", x=208, y=48,  sw=24, sh=26 },
    weapon_mp5navy      = { file="sprites/640hud1", x=208, y=48,  sw=24, sh=26 },
    weapon_tmp          = { file="sprites/640hud1", x=208, y=48,  sw=24, sh=26 },
    weapon_mac10        = { file="sprites/640hud1", x=208, y=48,  sw=24, sh=26 },
    -- .45 ACP
    weapon_usp          = { file="sprites/640hud1", x=182, y=0,   sw=26, sh=24 },
    weapon_elite        = { file="sprites/640hud1", x=182, y=0,   sw=26, sh=24 },
    weapon_ump45        = { file="sprites/640hud1", x=182, y=0,   sw=26, sh=24 },
    -- 5.7mm
    weapon_fiveseven    = { file="sprites/640hud1", x=208, y=24,  sw=24, sh=24 },
    weapon_p90          = { file="sprites/640hud1", x=208, y=24,  sw=24, sh=24 },
    -- .357
    weapon_deagle       = { file="sprites/640hud1", x=208, y=0,   sw=24, sh=24 },
    -- 5.56
    weapon_famas        = { file="sprites/640hud1", x=157, y=74,  sw=25, sh=24 },
    weapon_galil        = { file="sprites/640hud1", x=157, y=74,  sw=25, sh=24 },
    weapon_m4a1         = { file="sprites/640hud1", x=157, y=74,  sw=25, sh=24 },
    weapon_aug          = { file="sprites/640hud1", x=157, y=74,  sw=25, sh=24 },
    weapon_sg552        = { file="sprites/640hud1", x=157, y=74,  sw=25, sh=24 },
    weapon_sg550        = { file="sprites/640hud1", x=157, y=74,  sw=25, sh=24 },
    -- 7.62
    weapon_ak47         = { file="sprites/640hud1", x=232, y=48,  sw=24, sh=26 },
    weapon_g3sg1        = { file="sprites/640hud1", x=232, y=48,  sw=24, sh=26 },
    weapon_scout        = { file="sprites/640hud1", x=232, y=48,  sw=24, sh=26 },
    -- .338
    weapon_awp          = { file="sprites/640hud1", x=182, y=74,  sw=26, sh=24 },
    -- .50
    weapon_m249         = { file="sprites/640hud1", x=182, y=48,  sw=26, sh=26 },
    -- 12g (font glyph from CSTypeDeath / csd.ttf)
    weapon_m3           = { font="CSS_TypeDeath", char="J" },
    weapon_xm1014       = { font="CSS_TypeDeath", char="J" },
    -- Grenades (font glyph from CSType / cs.ttf)
    weapon_hegrenade    = { font="CSS_Type", char="h" },
    weapon_flashbang    = { font="CSS_Type", char="g" },
    weapon_smokegrenade = { font="CSS_Type", char="g" },
}

local _sheetW, _sheetH
local function getSheetDims()
    if _sheetW then return _sheetW, _sheetH end
    local mat = Material("sprites/640hud1")
    if mat and not mat:IsError() then
        local tex = mat:GetTexture("$basetexture")
        if tex then _sheetW, _sheetH = tex:Width(), tex:Height() end
    end
    _sheetW = _sheetW or 256
    _sheetH = _sheetH or 128
    return _sheetW, _sheetH
end

function HL2Hud.DrawCSSAmmoIcon(cls, ix, iy, col)
    local icon = CSS_AMMO_ICONS[cls]
    if not icon then return end
    if icon.font then
        surface.SetFont(icon.font)
        surface.SetTextColor(col.r, col.g, col.b, col.a)
        surface.SetTextPos(ix, iy)
        surface.DrawText(icon.char)
    else
        local mat = Material(icon.file)
        if mat and not mat:IsError() then
            local tw, th = getSheetDims()
            surface.SetMaterial(mat)
            surface.SetDrawColor(col.r, col.g, col.b, col.a)
            surface.DrawTexturedRectUV(
                ix, iy, S(icon.sw), S(icon.sh),
                icon.x/tw, icon.y/th,
                (icon.x+icon.sw)/tw, (icon.y+icon.sh)/th
            )
        end
    end
end

------------------------------------------------------------------------
-- HL2Hud.MakeLayout(baseName, overrides)
-- Copies a theme layout by name and applies overrides on top.
-- Use this in custom EHUD elements so they inherit the active theme's
-- fonts, panel style, icon system, etc., while setting their own label/icon.
-- Example:
--   local layout = HL2Hud.MakeLayout("health", { label = "SPEED" })
------------------------------------------------------------------------
function HL2Hud.MakeLayout(baseName, overrides)
    local base = HL2Hud.GetLayout(baseName) or {}
    local t = {}
    for k, v in pairs(base) do t[k] = v end
    for k, v in pairs(overrides or {}) do t[k] = v end
    return t
end

------------------------------------------------------------------------
-- COMPAT: HL2Hud.DrawNumericDisplay(x, y, label, value, state)
-- Old API used by examples before the data-driven layout refactor.
-- Maps to DrawElement with a synthetic HL2-style layout.
------------------------------------------------------------------------
function HL2Hud.DrawNumericDisplay(x, y, label, value, state)
    local layout = {
        wide      = 102, tall      = 36,
        panel     = "flat",
        font      = "HL2Hud_Numbers",
        glow_font = "HL2Hud_NumbersGlow",
        digit_xpos = 50, digit_ypos = 2,
        text_xpos  = 8,  text_ypos  = 20,
        label     = label,
    }
    return HL2Hud.DrawElement(x, y, value, state, layout)
end
