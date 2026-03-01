ENT.Type                  = "anim"
ENT.Base                  = "base_gmodentity"
ENT.PrintName             = "HL1 Gib (Optimised)"
ENT.Author                = "GilbUtils"
ENT.Spawnable             = false
ENT.AutomaticFrameAdvance = true

-- MOVETYPE_FLYGRAVITY + MOVECOLLIDE_FLY_CUSTOM
-- Touch() fires before ResolveFlyCollisionCustom. With FLY_CUSTOM, the engine
-- only zeros velocity on floor+speed<30 (our settle case). All other cases:
-- our SetAbsVelocity in Touch() sticks. So we bounce directly in Touch() using
-- GetAbsVelocity() which is still the pre-collision value at that point.
-- Think() only handles grounded friction.

local ELASTICITY  = 0.45
local STOPSPEED   = 100
local FRICTION    = 4

local function ClipVelocity(vel, normal)
	return vel - normal * (vel:Dot(normal) * (1 + ELASTICITY))
end

function ENT:Initialize()
	local model = self:GetNWString("GibModel", "models/gibs/hghl1.mdl")
	if model == "" then model = "models/gibs/hghl1.mdl" end
	self:SetModel(model)
	self:SetCollisionBounds(Vector(0, 0, 0), Vector(0, 0, 0))

	self.GibVelocity     = Vector(0, 0, 0)
	self.GibOnGround     = false
	self.BloodDecalsLeft = 5
	self.BloodColor      = BLOOD_COLOR_RED
	self.LifeTime        = 25

	if CLIENT then return end

	self:SetBodygroup(0, self:GetNWInt("GibBodygroup", 0))
	self:SetMoveType(MOVETYPE_FLYGRAVITY)
	self:SetMoveCollide(MOVECOLLIDE_FLY_CUSTOM)
	self:SetSolid(SOLID_BBOX)
	self:AddSolidFlags(FSOLID_NOT_STANDABLE)
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	self:SetGravity(800 / 600)
	self:SetLocalAngularVelocity(Angle(math.Rand(100, 200), math.Rand(100, 300), 0))

	self:NextThink(CurTime() + engine.TickInterval())
end

function ENT:Touch(ent)
	if CLIENT then return end
	if self.GibOnGround then return end

	-- GetAbsVelocity() here is pre-collision (Touch fires before ResolveFlyCollisionCustom)
	local vel = self:GetAbsVelocity()
	if vel:LengthSqr() < 1 then return end

	-- Find surface normal by tracing in velocity direction
	local dir = vel:GetNormalized()
	local pos = self:GetPos()
	local tr  = util.TraceLine({ start = pos - dir * 2, endpos = pos + dir * 8, filter = self, mask = MASK_SOLID })
	local normal  = tr.Hit and tr.HitNormal or -dir
	local isFloor = normal.z > 0.7

	-- Blood decal
	if self.BloodDecalsLeft > 0 and self.BloodColor ~= DONT_BLEED then
		local decal = (self.BloodColor == BLOOD_COLOR_YELLOW) and "YellowBlood" or "Blood"
		util.Decal(decal, pos + normal, pos - normal)
		self.BloodDecalsLeft = self.BloodDecalsLeft - 1
		if math.random(0, 2) == 0 then
			self:EmitSound("debris/flesh" .. math.random(1, 7) .. ".wav", 75, 100,
				0.8 * math.min(1.0, math.abs(vel.z) / 450.0))
		end
	end

	local newVel = ClipVelocity(vel, normal)

	if isFloor and math.abs(newVel.z) < 60 then
		newVel.z = 0
		self.GibVelocity = newVel
		self.GibOnGround = true
		self:SetLocalAngularVelocity(Angle(0, 0, 0))
		local ang = self:GetAngles(); ang.p = 0; ang.r = 0; self:SetAngles(ang)
		self:SetGravity(0)
	else
		self.GibVelocity = newVel
	end

	self:SetAbsVelocity(newVel)
end

function ENT:Think()
	if CLIENT then self:NextThink(CurTime()) return true end

	-- First tick: push externally-set GibVelocity into engine
	if not self._ready then
		self._ready = true
		self:SetAbsVelocity(self.GibVelocity)
		self:NextThink(CurTime())
		return true
	end

	if not self.GibOnGround then
		self:NextThink(CurTime())
		return true
	end

	-- Grounded friction
	local vel   = self.GibVelocity
	local speed = vel:Length2D()
	if speed < 2 then
		self:SetAbsVelocity(Vector(0, 0, 0))
		self:SetMoveType(MOVETYPE_NONE)
		SafeRemoveEntityDelayed(self, self.LifeTime)
		return
	end

	local newspeed = math.max(0, speed - math.max(speed, STOPSPEED) * FRICTION * FrameTime())
	local newVel   = Vector(vel.x * (newspeed / speed), vel.y * (newspeed / speed), 0)
	self.GibVelocity = newVel
	self:SetAbsVelocity(newVel)

	self:NextThink(CurTime())
	return true
end

function ENT:Draw() self:DrawModel() end
