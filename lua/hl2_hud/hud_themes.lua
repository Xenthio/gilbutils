-- hud_themes.lua — Theme presets for the HL2 HUD remake.
-- Themes control colors, font sizes, font scale baseline, and weapon selection mode.
-- Apply a theme with HL2Hud.SetTheme(name) or the spawnmenu panel.
--
-- Font size data sourced via clientscheme_diff.py (WIN32 values only, DECK/LINUX ignored):
--   GMod     = garrysmod/resource/ClientScheme.res
--   SDK2013  = Source SDK Base 2013 SP/hl2/resource/clientscheme.res  (original HL2)
--   HL2-Post = Half-Life 2/hl2/resource/clientscheme.res              (post-GamepadUI update)
--
-- GMod and SDK2013 are IDENTICAL for all HUD fonts and colors.
-- Post-GamepadUI mode is a separate checkbox (hl2hud_postgamepadui) that patches
-- font sizes on top of any theme — it's not a theme itself.
--
-- Post-GamepadUI WIN32 differences vs GMod/SDK2013:
--   selectionNumbers: 11 → 16
--   quickInfo:        28 → 36
--   proportionalText: false → true  (HudDefault + selectionText scale proportionally)
--   selectionText baseline: 8 → 7   (tier-1 of the proportional table)

if not CLIENT then return end

CreateClientConVar("hl2hud_postgamepadui", "0", true, false,
    "Apply Post-GamepadUI font scaling on top of current theme (proportional at high res)")

------------------------------------------------------------------------
-- Color palettes
------------------------------------------------------------------------

local function defColors()
    return {
        FgColor         = Color(255, 235,  20, 255),  -- GMod: warmer yellow, full alpha
        BrightFg        = Color(255, 220,   0, 255),
        DamagedFg       = Color(180,   0,   0, 230),
        BrightDamagedFg = Color(255,   0,   0, 255),
        BgColor         = Color(  0,   0,   0,  76),
        DamagedBg       = Color(180,   0,   0, 200),
        AuxHigh         = Color(255, 220,   0, 220),
        AuxLow          = Color(255,   0,   0, 220),
        AuxDisabled     = 70,
    }
end

local function hl2Colors()
    return {
        FgColor         = Color(255, 220,   0, 100),  -- HL2/Portal: semi-transparent yellow
        BrightFg        = Color(255, 220,   0, 255),
        DamagedFg       = Color(180,   0,   0, 230),
        BrightDamagedFg = Color(255,   0,   0, 255),
        BgColor         = Color(  0,   0,   0,  76),
        DamagedBg       = Color(180,   0,   0, 200),
        AuxHigh         = Color(255, 220,   0, 220),
        AuxLow          = Color(255,   0,   0, 220),
        AuxDisabled     = 70,
    }
end

local function cssColors()
    -- Source: clientscheme.res (CSS) + hudanimations.txt
    -- FgColor default = OrangeDim (255 176 0 120) — dim rest state
    -- BrightFg = Orange (255 176 0 255) — full alpha flash on events
    -- DamagedFg = HudIcon_Red (160 0 0 255) — damage/low health
    -- BgColor = bgcolor_override from hudlayout.res = 0 0 0 96 (not TransparentBlack)
    -- No DamagedBg (CSS never flashes the panel background red)
    return {
        FgColor         = Color(255, 176,   0, 120),  -- OrangeDim: default dim rest state
        BrightFg        = Color(255, 176,   0, 255),  -- Orange: full alpha, flash on events
        DamagedFg       = Color(160,   0,   0, 255),  -- HudIcon_Red: low health / damage
        BrightDamagedFg = Color(160,   0,   0, 255),  -- same (CSS has no extra-bright red)
        BgColor         = Color(  0,   0,   0,  96),  -- bgcolor_override from hudlayout.res
        DamagedBg       = Color(  0,   0,   0,  96),  -- CSS never flashes panel red — same as BgColor
        AuxHigh         = Color(255, 176,   0, 220),
        AuxLow          = Color(255,   0,   0, 220),
        AuxDisabled     = 70,
    }
end

------------------------------------------------------------------------
-- Base font sizes (pre-Post-GamepadUI)
------------------------------------------------------------------------

local baseFontSizes = {
    weaponIcons      = 64,
    weaponIconsSmall = 32,
    selectionNumbers = 11,
    quickInfo        = 28,
    hudNumbers       = 32,
    -- hidef: SDK2013 has tall_hidef=58 at >=1080p; GMod does not
}

local hl2FontSizes = {
    weaponIcons      = 64,
    hidefWeaponIcons = 58,
    hidefThreshold   = 1080,
    weaponIconsSmall = 32,
    selectionNumbers = 11,
    quickInfo        = 28,
    hudNumbers       = 32,
}

------------------------------------------------------------------------
-- Theme definitions
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Default layouts (HL2/GMod style — CHudNumericDisplay defaults)
-- hudlayout.res WIN32 values. Elements fall back to these when the
-- active theme doesn't override a layout.
------------------------------------------------------------------------
HL2Hud.DefaultLayouts = {
    -- CHudHealth: xpos=16 ypos=432 wide=102 tall=36
    --   digit_xpos=50 digit_ypos=2  text_xpos=8 text_ypos=20
    health = {
        wide       = 102,   tall       = 36,
        panel      = "flat",
        font       = "HL2Hud_Numbers",
        glow_font  = "HL2Hud_NumbersGlow",
        digit_xpos = 50,    digit_ypos = 2,
        text_xpos  = 8,     text_ypos  = 20,
        label      = "HEALTH",
    },
    -- CHudBattery: xpos=140 ypos=432 wide=108 tall=36
    --   digit_xpos=50 digit_ypos=2  text_xpos=8 text_ypos=20
    battery = {
        wide       = 108,   tall       = 36,
        panel      = "flat",
        font       = "HL2Hud_Numbers",
        glow_font  = "HL2Hud_NumbersGlow",
        digit_xpos = 50,    digit_ypos = 2,
        text_xpos  = 8,     text_ypos  = 20,
        label      = "SUIT",
    },
    -- CHudAmmo primary: wide=136 (animated), digit_xpos=44 digit_ypos=2
    --   text_xpos=8 text_ypos=20
    --   digit2_xpos=98 digit2_ypos=16  (reserve, HudNumbersSmall)
    ammo = {
        wide        = 136,  tall        = 36,
        panel       = "flat",
        font        = "HL2Hud_Numbers",
        glow_font   = "HL2Hud_NumbersGlow",
        small_font  = "HL2Hud_NumbersSmall",
        digit_xpos  = 44,   digit_ypos  = 2,
        digit2_xpos = 98,   digit2_ypos = 16,
        text_xpos   = 8,    text_ypos   = 20,
        label       = "AMMO",
    },
    -- CHudAmmo secondary (alt-fire grenade etc): wide=60
    --   digit_xpos=36 digit_ypos=2  text_xpos=8 text_ypos=22
    ammo_secondary = {
        wide       = 60,    tall       = 36,
        panel      = "flat",
        font       = "HL2Hud_Numbers",
        glow_font  = "HL2Hud_NumbersGlow",
        digit_xpos = 36,    digit_ypos = 2,
        text_xpos  = 8,     text_ypos  = 22,
        label      = "ALT",
    },
}

------------------------------------------------------------------------
-- CSS layouts
-- cs_hud_health.cpp / cs_hud_ammo.cpp + hudlayout.res
--   panel = "rounded" (PaintBackgroundType 2, ~4px corner radius)
--   indent = true     (CHudNumericDisplay::SetIndent — pads to 3 chars)
--   digit_ypos = -4   (direct offset from panel ypos, intentionally overhangs)
--   icon_ypos  = -4   (same)
------------------------------------------------------------------------
local cssLayouts = {
    -- CHudHealth: xpos=8 ypos=446 wide=80 tall=25
    --   icon drawn via DrawSelf (proportional to tall-YRES(2)), font glyph approx same
    --   digit_xpos=35 digit_ypos=-4  (direct panel-relative, negative = overhang above)
    --   abs_x/abs_y = absolute hudlayout position in 480p units (bypasses EHUD margin system)
    health = {
        wide        = 80,    tall        = 25,
        panel       = "rounded",
        font        = "CSS_Numbers",
        glow_font   = false,
        indent      = true,
        digit_xpos  = 35,    digit_ypos  = -4,
        icon_char   = "b",   icon_font   = "CSS_Icons",
        icon_xpos   = 8,     icon_ypos   = -4,
    },
    -- CHudArmor: xpos=148 ypos=446 wide=80 tall=25
    --   Always draws (ShouldDraw checks IsObserver only, not armor value)
    battery = {
        wide        = 80,    tall        = 25,
        panel       = "rounded",
        font        = "CSS_Numbers",
        glow_font   = false,
        indent      = true,
        digit_xpos  = 34,    digit_ypos  = -4,
        icon_char   = "a",   icon_font   = "CSS_Icons",
        icon_xpos   = 8,     icon_ypos   = -4,
    },
    -- CHudAmmo: xpos=r157 ypos=446 wide=142 tall=25
    --   Reserve uses SAME font/indent as clip (m_hNumberFont, not a small font)
    --   digit2_xpos=63: reserve x with same indent logic as clip
    --   bar: additive white texture rect
    --   icon: gWR.GetAmmoIconFromWeapon, drawn at icon_xpos/ypos
    ammo = {
        wide        = 142,   tall        = 25,
        right       = 157,   -- xpos=r157 (right-anchored, absolute from right edge)
        panel       = "rounded",
        font        = "CSS_Numbers",
        glow_font   = false,
        -- No small_font: CSS uses same HudNumbers font for both clip and reserve
        indent      = true,
        digit_xpos  = 8,     digit_ypos  = -4,
        digit2_xpos = 63,    digit2_ypos = -4,
        bar_xpos    = 53,    bar_ypos    = 3,
        bar_width   = 2,     bar_height  = 20,
        ammo_icon_xpos = 110, ammo_icon_ypos = 2,
    },
    ammo_secondary = false,  -- CSS has no secondary ammo panel (false = explicit disable, nil would fall through to DefaultLayouts)
}

HL2Hud.Themes = {
    ["Garry's Mod"] = {
        label           = "Garry's Mod",
        fontScale       = 480,
        weaponSelection = "gmod",
        ammoIcon        = false,
        cornerRadius    = 8,
        fontSizes       = baseFontSizes,
        Colors          = defColors(),
    },

    ["Half-Life 2"] = {
        label           = "Half-Life 2",
        fontScale       = 480,
        weaponSelection = "hl2",
        ammoIcon        = true,
        cornerRadius    = 8,
        fontSizes       = hl2FontSizes,
        Colors          = hl2Colors(),
    },

    ["Portal"] = {
        label           = "Portal",
        fontScale       = 480,
        weaponSelection = "hl2",
        ammoIcon        = true,
        cornerRadius    = 8,
        fontSizes       = hl2FontSizes,
        Colors          = hl2Colors(),  -- identical to HL2 (confirmed from extracted files)
    },

    ["Counter-Strike: Source"] = {
        label           = "Counter-Strike: Source",
        fontScale       = 480,
        weaponSelection = "css",
        ammoIcon        = true,
        cornerRadius    = 8,
        fontSizes       = hl2FontSizes,
        Colors          = cssColors(),
        layouts         = cssLayouts,
        -- EHUD layout: CSS panels at ypos=446, tall=25 (480p hudlayout units)
        -- EHUD bottom-aligns in a 36-unit row: drawY = baseY + (36-tall)*s = baseY + 11*s
        -- We want drawY = 446*s → baseY = 435*s → BASE_Y_OFFSET = 480-435 = 45
        -- COL_GAP: health wide=80, armor xpos=148 → gap = 148-80-8 = 60 units
        ehudLayout      = { marginLeft = 8, marginRight = 16, baseYOffset = 45, colGap = 60 },
    },
}

HL2Hud.ThemeOrder = {
    "Garry's Mod",
    "Half-Life 2",
    "Portal",
    "Counter-Strike: Source",
}

------------------------------------------------------------------------
-- Post-GamepadUI font patch
-- Applied on top of the active theme's fontSizes when hl2hud_postgamepadui=1
------------------------------------------------------------------------

-- Returns a copy of baseSizes with Post-GamepadUI overrides applied
local function applyPostGamepadUIPatch(baseSizes)
    local out = {}
    for k, v in pairs(baseSizes) do out[k] = v end
    out.proportionalText  = true
    -- selectionText: Post-GamepadUI tier-1 baseline = 7 (catch-all proportional entry)
    out.selectionTextSizes = HL2Hud.yres({7, 10, 12, 16, 7}, {900, 700, 900, 900, 900})
    return out
end

-- Called after SetTheme or when the convar changes — applies patch if needed
function HL2Hud.ApplyFontPatch()
    local theme = HL2Hud.Themes[HL2Hud.ActiveTheme]
    if not theme then return end

    local postGPUI = GetConVar("hl2hud_postgamepadui"):GetBool()
    if postGPUI then
        HL2Hud.FontSizes = applyPostGamepadUIPatch(theme.fontSizes)
    else
        HL2Hud.FontSizes = theme.fontSizes
    end

    hook.Run("HL2Hud_RebuildFonts")
end

-- Watch the convar for live changes
cvars.AddChangeCallback("hl2hud_postgamepadui", function()
    HL2Hud.ApplyFontPatch()
end, "HL2Hud_PostGamepadUI")

------------------------------------------------------------------------
-- Active theme state
------------------------------------------------------------------------
HL2Hud.ActiveTheme   = HL2Hud.ActiveTheme   or "Garry's Mod"
HL2Hud.FontScaleBase = HL2Hud.FontScaleBase or 480
HL2Hud.FontSizes     = HL2Hud.FontSizes     or HL2Hud.Themes["Garry's Mod"].fontSizes
HL2Hud.CornerRadius  = HL2Hud.CornerRadius  or 8

------------------------------------------------------------------------
-- HL2Hud.SetTheme(name)
------------------------------------------------------------------------
function HL2Hud.SetTheme(name)
    local theme = HL2Hud.Themes[name]
    if not theme then
        print("[HL2Hud] Unknown theme: " .. tostring(name))
        return
    end

    HL2Hud.ActiveTheme   = name
    HL2Hud.FontScaleBase = theme.fontScale
    HL2Hud.CornerRadius  = theme.cornerRadius or 8

    -- Apply colors
    for k, v in pairs(theme.Colors) do
        HL2Hud.Colors[k] = v
    end
    HL2Hud.ApplyColors()

    -- Weapon selection mode: "gmod", "hl2", or "css"
    RunConsoleCommand("hl2hud_gmod",      theme.weaponSelection == "gmod" and "1" or "0")
    RunConsoleCommand("hl2hud_ammo_icon", theme.ammoIcon and "1" or "0")
    -- Store selection mode for CSS dispatch (HL2Hud_WeaponSelectionPaint hook reads ActiveTheme)

    -- Apply EHUD layout margins for this theme
    -- CSS: health at xpos=8, ypos=446 → marginLeft=8, baseYOffset=34 (480-446)
    -- HL2/GMod: standard margins
    if EHUD and EHUD.SetLayout then
        local layout = theme.ehudLayout
        if layout then
            EHUD.SetLayout(layout.marginLeft, layout.marginRight, layout.baseYOffset, layout.colGap)
        else
            EHUD.SetLayout(16, 16, 48)  -- defaults
        end
    end

    -- Apply font sizes (with Post-GamepadUI patch if enabled)
    HL2Hud.ApplyFontPatch()

    -- Persist
    cookie.Set("hl2hud_theme", name)

    print("[HL2Hud] Theme applied: " .. name)
    hook.Run("HL2Hud_ThemeChanged", name, theme)
end

------------------------------------------------------------------------
-- Restore saved theme on load
------------------------------------------------------------------------
hook.Add("InitPostEntity", "HL2Hud_RestoreTheme", function()
    local saved = cookie.GetString("hl2hud_theme", "Garry's Mod")
    if HL2Hud.Themes[saved] then
        HL2Hud.SetTheme(saved)
    end
end)
