-- hud_fonts.lua — Font definitions for HL2 HUD elements.
-- All fonts prefixed HL2Hud_, scaled to ScrH/480.

local function makeFonts()
    local s = ScrH() / 480
    surface.CreateFont("HL2Hud_Numbers",      { font="Halflife2", size=math.Round(32*s), antialias=true, additive=true })
    surface.CreateFont("HL2Hud_NumbersGlow",  { font="Halflife2", size=math.Round(32*s), blursize=math.Round(4*s), scanlines=math.Round(2*s), antialias=true, additive=true })
    surface.CreateFont("HL2Hud_NumbersSmall", { font="Halflife2", size=math.Round(20*s), antialias=true, additive=true })
    surface.CreateFont("HL2Hud_Text",         { font="Verdana",   size=math.Round(8*s),  weight=900, antialias=true })
end
hook.Add("OnScreenSizeChanged", "HL2Hud_Fonts", makeFonts)
makeFonts()
