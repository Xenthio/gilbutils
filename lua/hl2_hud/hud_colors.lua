-- hud_colors.lua — Color constants sourced from ClientScheme.res and hudlayout.res.
-- Edit HL2Hud.Colors.* at any time to recolor the HUD live.
--
-- ClientScheme.res values:
--   FgColor          "255 235 20 255"   (base fg, slightly warmer)
--   BgColor          "0 0 0 76"
--   BrightFg         "255 220 0 255"
--   DamagedBg        "180 0 0 200"
--   DamagedFg        "180 0 0 230"
--   BrightDamagedFg  "255 0 0 255"
-- hudlayout.res values:
--   AuxPowerHighColor  "255 220 0 220"
--   AuxPowerLowColor   "255 0 0 220"
--   AuxPowerDisabledAlpha  70

HL2Hud.Colors = HL2Hud.Colors or {
    FgColor          = Color(255, 220,   0, 255),
    BrightFg         = Color(255, 220,   0, 255),
    DamagedFg        = Color(180,   0,   0, 230),
    BrightDamagedFg  = Color(255,   0,   0, 255),
    BgColor          = Color(  0,   0,   0,  76),
    DamagedBg        = Color(180,   0,   0, 200),
    AuxHigh          = Color(255, 220,   0, 220),
    AuxLow           = Color(255,   0,   0, 220),
    AuxDisabled      = 70,
}

-- HL2Hud.ApplyColors() — call after changing HL2Hud.Colors to propagate to live anim state.
-- Only snaps anims that are at their "resting" FgColor/BgColor values (not mid-animation).
-- The rainbow example hook should call this every Think.
function HL2Hud.ApplyColors()
    if not HL2Hud.healthEvent then return end  -- elements not loaded yet
    HL2Hud.healthEvent("ColorsChanged")
    HL2Hud.suitEvent("ColorsChanged")
    HL2Hud.ammoEvent("ColorsChanged")
    if HL2Hud.auxEvent then HL2Hud.auxEvent("ColorsChanged") end
end
