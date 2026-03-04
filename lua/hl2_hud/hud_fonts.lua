-- hud_fonts.lua — Font definitions matching ClientScheme.res exactly
-- Source: garrysmod/resource/ClientScheme.res

if not CLIENT then return end

local function makeFonts()
    local s  = ScrH() / 480  -- full scale for text fonts
    local si = math.min(ScrH(), 1080) / 480  -- capped scale for large icon fonts (avoids BlitTextureBits)

    -- HudNumbers (HalfLife2, tall=32, additive)
    surface.CreateFont("HL2Hud_Numbers", {
        font      = "HalfLife2",
        size      = math.Round(32 * s),
        weight    = 0,
        antialias = true,
        additive  = true,
    })

    -- HudNumbersGlow (HalfLife2, tall=32, blur=4, scanlines=2, additive)
    surface.CreateFont("HL2Hud_NumbersGlow", {
        font      = "HalfLife2",
        size      = math.Round(32 * s),
        weight    = 0,
        blursize  = math.min(math.Round(4 * s), 4),  -- cap to avoid texture size issues
        scanlines = 2,
        antialias = true,
        additive  = true,
    })

    -- HudNumbersSmall (HalfLife2, tall=16, weight=1000, additive)
    surface.CreateFont("HL2Hud_NumbersSmall", {
        font      = "HalfLife2",
        size      = math.Round(16 * s),
        weight    = 1000,
        antialias = true,
        additive  = true,
    })

    -- HudDefault — matches ClientScheme.res HudDefault yres breakpoints exactly
    -- (weight and additive vary by resolution tier)
    do
        local h = ScrH()
        local size, weight, additive
        if    h < 600  then size = 9;  weight = 700; additive = false
        elseif h < 768  then size = 12; weight = 700; additive = false
        elseif h < 1024 then size = 14; weight = 900; additive = false
        elseif h < 1200 then size = 20; weight = 900; additive = false
        else                 size = 24; weight = 900; additive = true
        end
        surface.CreateFont("HL2Hud_Text", {
            font      = "Verdana",
            size      = size,
            weight    = weight,
            antialias = true,
            additive  = additive,
        })
    end

    -- WeaponIcons — proportionally scaled (80% of LargeBoxTall at 480p baseline)
    -- BlitTextureBits triggers when size+blursize*2 > ~128px, so NO blursize here.
    -- Glow is achieved by drawing WeaponIconsSelected (no blur) additively on top.
    surface.CreateFont("HL2Hud_WeaponIcons", {
        font      = "HalfLife2",
        size      = math.min(math.Round(64 * s), 128),  -- cap at 128px (BlitTextureBits limit)
        weight    = 0,
        antialias = true,
        additive  = true,
    })

    -- WeaponIconsSelected — same size, scanlines only (no blursize - see above)
    -- Drawn additively on top of WeaponIcons to create the glow effect
    surface.CreateFont("HL2Hud_WeaponIconsSelected", {
        font      = "HalfLife2",
        size      = math.min(math.Round(64 * s), 128),  -- cap at 128px
        weight    = 0,
        antialias = true,
        scanlines = 2,
        additive  = true,
    })

    -- WeaponIconsSmall — proportionally scaled (half of WeaponIcons)
    surface.CreateFont("HL2Hud_WeaponIconsSmall", {
        font      = "HalfLife2",
        size      = math.min(math.Round(32 * s), 64),   -- cap at 64px
        weight    = 0,
        antialias = true,
        additive  = true,
    })

    -- HudSelectionNumbers — matches ClientScheme.res (Verdana 11, additive)
    surface.CreateFont("HL2Hud_SelectionNumbers", {
        font      = "Verdana",
        size      = math.Round(11 * s),
        weight    = 700,
        antialias = true,
        additive  = true,
    })

    -- HudSelectionText — matches ClientScheme.res HudSelectionText (Verdana 8, additive)
    surface.CreateFont("HL2Hud_WeaponText", {
        font      = "Verdana",
        size      = math.Round(8 * s),
        weight    = 700,
        antialias = true,
        additive  = true,
    })
end

hook.Add("OnScreenSizeChanged", "HL2Hud_Fonts", makeFonts)
makeFonts()
