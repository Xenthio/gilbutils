-- hud_fonts.lua — Font definitions matching ClientScheme.res exactly
-- Source: garrysmod/resource/ClientScheme.res
-- Font sizes are driven by HL2Hud.FontSizes (set by hud_themes.lua).
--
-- Scaling rules:
--   HudNumbers, WeaponIcons, QuickInfo — proportional (tall * ScrH/base)
--   HudDefault, HudSelectionText       — absolute yres-stepped (NOT proportional)
--   HudSelectionNumbers                — proportional, unless theme sets selectionNumbersAbsolute=true

if not CLIENT then return end

------------------------------------------------------------------------
-- HL2Hud.yres(sizes, weights)
-- Compact helper for Source-style yres-stepped font size tables.
-- Standard breakpoints: <600, <768, <1024, <1200, 1200+
-- sizes:   5 values  e.g. {8, 10, 12, 16, 17}
-- weights: 5 values, or a single number applied to all tiers
------------------------------------------------------------------------
local YRES_BREAKS = { 599, 767, 1023, 1199, math.huge }

function HL2Hud.yres(sizes, weights)
    local out = {}
    for i, maxY in ipairs(YRES_BREAKS) do
        local w = type(weights) == "table" and weights[i] or (weights or 700)
        out[i] = { maxY = maxY, size = sizes[i], weight = w }
    end
    return out
end

local function resolveYres(tbl, h)
    for _, tier in ipairs(tbl) do
        if h <= tier.maxY then return tier.size, tier.weight, tier.additive end
    end
    local last = tbl[#tbl]
    return last.size, last.weight, last.additive
end

------------------------------------------------------------------------

local function makeFonts()
    local base = (HL2Hud and HL2Hud.FontScaleBase) or 480
    local sz   = (HL2Hud and HL2Hud.FontSizes)     or {}
    local s    = ScrH() / base
    local h    = ScrH()

    local hidefThreshold = sz.hidefThreshold or 1080
    local useHidef       = h >= hidefThreshold and sz.hidefWeaponIcons ~= nil

    local wepIconSize  = useHidef and sz.hidefWeaponIcons or (sz.weaponIcons or 64)
    local wepSmallSize = sz.weaponIconsSmall or 32
    local quickSize    = sz.quickInfo        or 28
    local numSize      = sz.hudNumbers       or 32
    local selNumSize   = sz.selectionNumbers or 11

    -- HudSelectionText — absolute yres-stepped. GMod default: 8/10/12/16/17
    local selTextTable = sz.selectionTextSizes or HL2Hud.yres(
        {8, 10, 12, 16, 17},
        {700, 700, 900, 900, 1000}
    )
    -- HudSelectionText
    -- proportionalText themes: scale tier-1 baseline by s (Post-GamepadUI)
    -- absolute themes: resolve yres steps as engine does (GMod, HL2)
    local selTextSize, selTextWeight
    if sz.proportionalText then
        selTextSize   = math.Round((selTextTable[1] and selTextTable[1].size or 8) * s)
        selTextWeight = selTextTable[1] and selTextTable[1].weight or 700
    else
        selTextSize, selTextWeight = resolveYres(selTextTable, h)
    end

    -- HudDefault — same split
    local defaultSizes = sz.hudDefaultSizes or {
        { maxY = 599,       size = 9,  weight = 700, additive = false },
        { maxY = 767,       size = 12, weight = 700, additive = false },
        { maxY = 1023,      size = 14, weight = 900, additive = false },
        { maxY = 1199,      size = 20, weight = 900, additive = false },
        { maxY = math.huge, size = 24, weight = 900, additive = true  },
    }
    local defSize, defWeight, defAdditive
    if sz.proportionalText then
        defSize     = math.Round((defaultSizes[1] and defaultSizes[1].size or 9) * s)
        defWeight   = defaultSizes[1] and defaultSizes[1].weight or 700
        defAdditive = false
    else
        defSize, defWeight, defAdditive = resolveYres(defaultSizes, h)
    end

    -- HudSelectionNumbers — proportional (scheme value is 480p baseline)
    local selNumFinal = math.Round(selNumSize * s)

    surface.CreateFont("HL2Hud_Numbers", {
        font = "HalfLife2", size = math.Round(numSize * s),
        weight = 0, antialias = true, additive = true,
    })
    surface.CreateFont("HL2Hud_NumbersGlow", {
        font = "HalfLife2", size = math.Round(numSize * s),
        weight = 0, blursize = math.Round(4 * s), scanlines = math.Round(2 * s),
        antialias = true, additive = true,
    })
    surface.CreateFont("HL2Hud_NumbersSmall", {
        font = "HalfLife2", size = math.Round(16 * s),
        weight = 1000, antialias = true, additive = true,
    })
    surface.CreateFont("HL2Hud_Text", {
        font = "Verdana", size = defSize, weight = defWeight,
        antialias = true, additive = defAdditive,
    })
    surface.CreateFont("HL2Hud_WeaponIcons", {
        font = "HalfLife2", size = math.min(math.Round(wepIconSize * s), 128),
        weight = 0, antialias = true, additive = true,
    })
    surface.CreateFont("HL2Hud_WeaponIconsSelected", {
        font = "HalfLife2", size = math.min(math.Round(wepIconSize * s), 128),
        weight = 0, blursize = math.Round(4 * s), scanlines = math.min(math.Round(2 * s), 5),
        antialias = true, additive = true,
    })
    surface.CreateFont("HL2Hud_WeaponIconsSmall", {
        font = "HalfLife2", size = math.min(math.Round(wepSmallSize * s), 64),
        weight = 0, antialias = true, additive = true,
    })
    surface.CreateFont("HL2Hud_SelectionNumbers", {
        font = "Verdana", size = selNumFinal,
        weight = 700, antialias = true, additive = true,
    })
    surface.CreateFont("HL2Hud_WeaponText", {
        font = "Verdana", size = selTextSize, weight = selTextWeight,
        antialias = true, additive = true,
    })
    surface.CreateFont("HL2Hud_QuickInfo", {
        font = "HL2cross", size = math.Round(quickSize * s),
        weight = 0, antialias = true, additive = true,
    })
end

hook.Add("OnScreenSizeChanged", "HL2Hud_Fonts", makeFonts)
hook.Add("HL2Hud_RebuildFonts", "HL2Hud_Fonts", makeFonts)
makeFonts()
