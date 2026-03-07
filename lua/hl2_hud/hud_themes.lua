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
    return {
        -- CSS uses Orange (255 176 0) instead of yellow, full alpha, darker bg
        FgColor         = Color(255, 176,   0, 255),  -- "Orange" full alpha
        BrightFg        = Color(255, 220,   0, 255),  -- selection highlights stay yellow
        DamagedFg       = Color(180,   0,   0, 230),
        BrightDamagedFg = Color(255,   0,   0, 255),
        BgColor         = Color(  0,   0,   0, 196),  -- "TransparentBlack" — much more opaque
        DamagedBg       = Color(180,   0,   0, 200),
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
        weaponSelection = "hl2",
        ammoIcon        = true,
        cornerRadius    = 8,
        fontSizes       = hl2FontSizes,
        Colors          = cssColors(),  -- orange FgColor, opaque BgColor (TransparentBlack=196 alpha)
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

    -- Weapon selection / ammo icon convars
    RunConsoleCommand("hl2hud_gmod",      theme.weaponSelection == "gmod" and "1" or "0")
    RunConsoleCommand("hl2hud_ammo_icon", theme.ammoIcon and "1" or "0")

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
