-- GilbUtils autorun — loads all modules
GilbUtils = GilbUtils or {}

if SERVER then
    AddCSLuaFile("gilbutils/gibs.lua")
end

include("gilbutils/gibs.lua")
print("[GilbUtils] Loaded")
