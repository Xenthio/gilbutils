-- GilbUtils autorun — loads all modules
GilbUtils = GilbUtils or {}

if SERVER then
    include("gilbutils/gibs.lua")
    AddCSLuaFile("gilbutils/gibs.lua")
    print("[GilbUtils] Loaded")
end
