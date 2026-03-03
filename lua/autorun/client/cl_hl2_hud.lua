-- cl_hl2_hud.lua — GilbUtils built-in HL2 HUD replacement
-- Loads each element from lua/hl2_hud/. See individual files for per-element docs.
--
-- Global API (HL2Hud table):
--   HL2Hud.Colors.*          — live-editable color/alpha fields (see hud_colors.lua)
--   HL2Hud.healthEvent(name) — fire CHudHealth animation events
--   HL2Hud.suitEvent(name)   — fire CHudBattery animation events
--   HL2Hud.auxEvent(name)    — fire CHudSuitPower animation events
--   HL2Hud.healthElem        — EHUD element (health column base)
--   HL2Hud.suitElem          — EHUD element (suit column base)
--   HL2Hud.auxElem           — EHUD element (health vstack, priority 5)
--   HL2Hud.ammoElem          — EHUD element (ammo column base)
--   HL2Hud.ammoSecondaryElem — EHUD element (ammo vstack, priority 5)

if SERVER then return end
if not EHUD then include("autorun/client/cl_extensible_hud.lua") end

HL2Hud = HL2Hud or {}

-- Shared infrastructure (order matters)
include("hl2_hud/hud_anim.lua")
include("hl2_hud/hud_fonts.lua")
include("hl2_hud/hud_colors.lua")
include("hl2_hud/hud_numeric_display.lua")

-- Elements
include("hl2_hud/hud_health.lua")
include("hl2_hud/hud_battery.lua")
include("hl2_hud/hud_suit_power.lua")
include("hl2_hud/hud_ammo.lua")
include("hl2_hud/hud_secondary_ammo.lua")
-- include("hl2_hud/hud_weapon_selection.lua")  -- TODO

-- Suppress native panels
hook.Add("HUDShouldDraw", "HL2Hud_HideNative", function(name)
    if name == "CHudHealth"          then return false end
    if name == "CHudBattery"         then return false end
    if name == "CHudSuit"            then return false end
    if name == "CHudAmmo"            then return false end
    if name == "CHudAmmoSecondary"   then return false end
end)
EHUD.OwnsAuxBar = true

-- Register into EHUD
local hCol = EHUD.GetColumn("health")
local sCol = EHUD.GetColumn("suit")
if hCol then hCol.base_element = HL2Hud.healthElem end
if sCol then sCol.base_element = HL2Hud.suitElem   end
EHUD.AddToColumn("health", "hl2_aux_power",       HL2Hud.auxElem,           5)

local aCol = EHUD.GetColumn("ammo")
if aCol then aCol.base_element = HL2Hud.ammoElem end
EHUD.AddToColumn("ammo", "hl2_ammo_secondary", HL2Hud.ammoSecondaryElem, 5)

print("[GilbUtils] HL2 HUD loaded")
