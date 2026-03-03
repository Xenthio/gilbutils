-- GilbUtils autorun — loads all modules
GilbUtils = GilbUtils or {}

if SERVER then
    AddCSLuaFile("gilbutils/gibs.lua")
    AddCSLuaFile("autorun/client/cl_extensible_hud.lua")
end

include("gilbutils/gibs.lua")

-- ExtensibleHUD loads automatically via its own client autorun file
print("[GilbUtils] Loaded")
