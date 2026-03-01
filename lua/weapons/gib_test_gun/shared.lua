-- gib_test_gun/shared.lua
-- Test SWEP for comparing hl1_hgib vs hl1_hgib_o
-- LEFT CLICK  → fires hl1_hgib_o (optimised, engine movement)
-- RIGHT CLICK → fires hl1_hgib  (original, manual Think physics)

SWEP.PrintName   = "Gib Test Gun"
SWEP.Author      = "GilbUtils"
SWEP.Instructions = "LMB: hl1_hgib_o | RMB: hl1_hgib"

SWEP.Spawnable   = true
SWEP.AdminOnly   = false

SWEP.Primary.ClipSize     = -1
SWEP.Primary.DefaultClip  = -1
SWEP.Primary.Automatic    = true
SWEP.Primary.Ammo         = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = true
SWEP.Secondary.Ammo        = "none"

SWEP.HoldType = "pistol"

-- Fire delay in seconds (rapid fire)
local FIRE_DELAY = 0.07

local function FireGib(ent_class, swep)
	if SERVER then
		local owner = swep:GetOwner()
		if not IsValid(owner) then return end

		local eyePos = owner:EyePos()
		local eyeAng = owner:EyeAngles()
		local fwd    = eyeAng:Forward()

		-- Slight random spread so gibs fan out visibly
		local spread = Vector(
			math.Rand(-0.05, 0.05),
			math.Rand(-0.05, 0.05),
			math.Rand(-0.05, 0.05)
		)
		local dir = (fwd + spread):GetNormalized()

		local speed = math.Rand(300, 600)

		local gib = ents.Create(ent_class)
		if not IsValid(gib) then return end

		gib:SetNWString("GibModel", "models/gibs/hghl1.mdl")
		gib:SetNWInt("GibBodygroup", math.random(0, 5))
		gib:SetPos(eyePos + fwd * 32)
		gib:Spawn()
		gib:Activate()
		gib:SetModel("models/gibs/hghl1.mdl")
		gib:SetBodygroup(0, math.random(0, 5))

		local vel = dir * speed + Vector(0, 0, math.Rand(50, 150))
		gib.GibVelocity = vel
		gib.BloodColor  = BLOOD_COLOR_RED

		-- hl1_hgib_o reads GibVelocity in Think's first sync; set AbsVelocity directly too
		if gib.SetAbsVelocity then
			gib:SetAbsVelocity(vel)
		end
	end
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + FIRE_DELAY)
	FireGib("hl1_hgib_o", self)
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + FIRE_DELAY)
	FireGib("hl1_hgib", self)
end

function SWEP:DrawHUD()
	if not self:GetOwner():IsValid() then return end
	draw.SimpleText("LMB: hl1_hgib_o  |  RMB: hl1_hgib", "DermaDefault",
		ScrW() / 2, ScrH() - 80, Color(255, 220, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
