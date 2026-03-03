-- hud_fonts.lua — Font definitions matching ClientScheme.res HudNumbers / HudDefault
-- All additive to composite correctly over the transparent panel background.

local function makeFonts()
    local s = ScrH() / 480
    -- HudNumbers (HalfLife2, additive)
    surface.CreateFont("HL2Hud_Numbers",      { font="Halflife2", size=math.Round(32*s), antialias=true, additive=true })
    -- HudNumbersGlow (HalfLife2, blur+scanlines, additive)
    surface.CreateFont("HL2Hud_NumbersGlow",  { font="Halflife2", size=math.Round(32*s), blursize=math.Round(4*s), scanlines=math.Round(2*s), antialias=true, additive=true })
    -- HudNumbersSmall (HalfLife2, additive)
    surface.CreateFont("HL2Hud_NumbersSmall", { font="Halflife2", size=math.Round(16*s), weight=1000, antialias=true, additive=true })
    -- HudDefault label font — additive so it composites cleanly over the dark transparent panel bg
    surface.CreateFont("HL2Hud_Text",         { font="Verdana",   size=math.Round(8*s),  weight=700, antialias=true, additive=true })
end
hook.Add("OnScreenSizeChanged", "HL2Hud_Fonts", makeFonts)
makeFonts()
