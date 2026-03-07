-- hud_themes.lua — Theme presets for the HL2 HUD remake.
-- Themes control colors, font sizes, font scale baseline, and weapon selection mode.
-- Apply a theme with HL2Hud.SetTheme(name) or the spawnmenu panel.
-- AI can call HL2Hud.SetTheme() or edit HL2Hud.Colors directly.
--
-- Font size data sourced via clientscheme_diff.py (WIN32 values only, DECK/LINUX ignored):
--   GMod     = garrysmod/resource/ClientScheme.res
--   SDK2013  = Source SDK Base 2013 SP/hl2/resource/clientscheme.res  (original HL2)
--   HL2-Post = Half-Life 2/hl2/resource/clientscheme.res              (post-GamepadUI update)
--
-- GMod and SDK2013 are IDENTICAL for all HUD fonts and colors.
-- Post-GamepadUI differences (WIN32 desktop):
--   WeaponIcons/Selected: 64 → 70
--   WeaponIconsSmall:     32 → 36
--   HudSelectionNumbers:  11 → 16
--   HudSelectionText:      8 → 10  (yres-stepped)
--   QuickInfo:            28 → 36
--   HudHintTextLarge:     14 → 22
--   HudHintTextSmall:     11 → 18
--   Colors: identical across all three sources.

if not CLIENT then return end

------------------------------------------------------------------------
-- Theme definitions
------------------------------------------------------------------------

local function defColors()
    return {
        -- GMod ClientScheme.res values
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
        -- SDK2013 / HL2 clientscheme.res values (same for both HL2 themes)
        FgColor         = Color(255, 220,   0, 100),  -- HL2: slightly dimmer, semi-transparent
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

HL2Hud.Themes = {
    ["Garry's Mod"] = {
        label           = "Garry's Mod",
        fontScale       = 480,
        weaponSelection = "gmod",
        cornerRadius    = 8,
        fontSizes = {
            weaponIcons      = 64,
            weaponIconsSmall = 32,
            selectionNumbers = 11,
            quickInfo        = 28,
            hudNumbers       = 32,
        },
        Colors = defColors(),
    },

    ["Half-Life 2"] = {
        label           = "Half-Life 2",
        fontScale       = 480,
        weaponSelection = "hl2",
        cornerRadius    = 8,
        fontSizes = {
            -- SDK2013 — same sizes as GMod but with hidefWeaponIcons at >= 1080p
            weaponIcons      = 64,
            hidefWeaponIcons = 58,
            hidefThreshold   = 1080,
            weaponIconsSmall = 32,
            selectionNumbers = 11,
            quickInfo        = 28,
            hudNumbers       = 32,
        },
        Colors = hl2Colors(),
    },

    ["Half-Life 2 (Post GamepadUI)"] = {
        label           = "Half-Life 2 (Post GamepadUI)",
        fontScale       = 480,
        weaponSelection = "hl2",
        cornerRadius    = 8,
        fontSizes = {
            -- WIN32 desktop values only ([$DECK]/[$LINUX] ignored)
            -- WeaponIcons/Small: unchanged from SDK2013 on WIN32
            weaponIcons      = 64,
            hidefWeaponIcons = 58,
            hidefThreshold   = 1080,
            weaponIconsSmall = 32,
            selectionNumbers = 11,
            quickInfo        = 28,
            hudNumbers       = 32,
            proportionalText = true,  -- HudDefault + selectionText scale with layout, not yres steps
            -- selectionText proportional baseline = 7 (tier-5 catch-all in Post-GamepadUI scheme)
            selectionTextSizes = HL2Hud.yres({7, 10, 12, 16, 7}, {900, 700, 900, 900, 900}),
        },
        Colors = hl2Colors(),
    },
}

-- Ordered list for UI display
HL2Hud.ThemeOrder = {
    "Garry's Mod",
    "Half-Life 2",
    "Half-Life 2 (Post Steam Deck Update)",
}

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
    HL2Hud.FontSizes     = theme.fontSizes
    HL2Hud.CornerRadius  = theme.cornerRadius or 8

    -- Apply colors
    for k, v in pairs(theme.Colors) do
        HL2Hud.Colors[k] = v
    end
    HL2Hud.ApplyColors()

    -- Weapon selection mode
    RunConsoleCommand("hl2hud_gmod", theme.weaponSelection == "gmod" and "1" or "0")

    -- Rebuild fonts with new sizes/scale
    hook.Run("HL2Hud_RebuildFonts")

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
