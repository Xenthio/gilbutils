-- GilbUtils autorun — loads all modules
GilbUtils = GilbUtils or {}

if SERVER then
    AddCSLuaFile("gilbutils/gibs.lua")
    AddCSLuaFile("autorun/client/cl_extensible_hud.lua")
    AddCSLuaFile("autorun/client/cl_hl2_hud.lua")
    AddCSLuaFile("hl2_hud/hud_anim.lua")
    AddCSLuaFile("hl2_hud/hud_fonts.lua")
    AddCSLuaFile("hl2_hud/hud_colors.lua")
    AddCSLuaFile("hl2_hud/hud_numeric_display.lua")
    AddCSLuaFile("hl2_hud/hud_health.lua")
    AddCSLuaFile("hl2_hud/hud_battery.lua")
    AddCSLuaFile("hl2_hud/hud_suit_power.lua")
    AddCSLuaFile("hl2_hud/hud_ammo.lua")
end

include("gilbutils/gibs.lua")

-- ExtensibleHUD loads automatically via its own client autorun file
print("[GilbUtils] Loaded")
