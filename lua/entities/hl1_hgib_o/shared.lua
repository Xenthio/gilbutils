ENT.Type                  = "anim"
ENT.Base                  = "base_gmodentity"
ENT.PrintName             = "HL1 Gib (Optimised)"
ENT.Author                = "GilbUtils"
ENT.Spawnable             = false
ENT.AutomaticFrameAdvance = true

-- hl1_hgib_o: behaviorally identical to hl1_hgib but uses engine movement.
-- MOVETYPE_FLYGRAVITY + MOVECOLLIDE_FLY_CUSTOM:
--   Engine handles gravity integration, position sweeping, and collision detection.
--   Touch() receives collision events and applies our ClipVelocity response.
--   Think() only handles friction/settle after landing, decals, and lifetime.
--
-- NOTE: MOVETYPE_WALK causes "PhysicsSimulate: bad movetype 2" spam.
-- Stay on MOVETYPE_FLYGRAVITY throughout; switch to MOVETYPE_NONE only when fully stopped.

local GIB_ELASTICITY = 1 - 0.55  -- 0.45
local GIB_FRICTION   = 4
local GIB_STOPSPEED  = 100
local GIB_GRAVITY    = 800        -- u/s², scaled against sv_gravity default of 600

local function ClipVelocity(vel, normal, elasticity)
	local backoff = vel:Dot(normal) * (1 + elasticity)
	return vel - normal * backoff
end

function ENT:Initialize()
	local model = self:GetNWString("GibModel", "models/gibs/hghl1.mdl")
	if model == "" then model = "models/gibs/hghl1.mdl" end
	self:SetModel(model)
	self:SetCollisionBounds(Vector(-4, -4, -4), Vector(4, 4, 4))

	if CLIENT then return end

	self:SetBodygroup(0, self:GetNWInt("GibBodygroup", 0))

	-- Engine handles gravity + velocity integration. Touch() handles collision response.
	self:SetMoveType(MOVETYPE_FLYGRAVITY)
	self:SetMoveCollide(MOVECOLLIDE_FLY_CUSTOM)
	self:SetSolid(SOLID_BBOX)
	self:AddSolidFlags(FSOLID_NOT_STANDABLE)
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

	-- Scale gravity to match HL1's 800 u/s² (sv_gravity default = 600)
	self:SetGravity(GIB_GRAVITY / 600)

	self.GibOnGround     = false
	self.BloodDecalsLeft = 5
	self.BloodColor      = BLOOD_COLOR_RED
	self.LifeTime        = 25
	self.WaitTillLandTime = CurTime() + 4

	-- Engine integrates angular velocity for us
	self:SetLocalAngularVelocity(Angle(math.Rand(100, 200), math.Rand(100, 300), 0))

	-- GibVelocity is set by the SpawnGib helper after Spawn(); apply it now
	if self.GibVelocity then
		self:SetAbsVelocity(self.GibVelocity)
	end

	self:NextThink(CurTime())
end

function ENT:Touch(ent)
	if CLIENT then return end
	if self.GibOnGround then return end

	local vel = self:GetAbsVelocity()

	-- Trace straight down to get the floor normal reliably.
	-- A short downward trace from our origin finds the surface we just hit.
	local pos  = self:GetPos()
	local tr = util.TraceLine({
		start  = pos + Vector(0, 0, 2),
		endpos  = pos - Vector(0, 0, 8),
		filter = self,
		mask   = MASK_SOLID,
	})

	local normal  = tr.Hit and tr.HitNormal or Vector(0, 0, 1)
	local isFloor = normal.z > 0.7

	-- Blood decal on contact
	if self.BloodDecalsLeft > 0 and self.BloodColor ~= DONT_BLEED then
		local decal = (self.BloodColor == BLOOD_COLOR_YELLOW) and "YellowBlood" or "Blood"
		util.Decal(decal, pos + normal, pos - normal)
		self.BloodDecalsLeft = self.BloodDecalsLeft - 1
		if math.random(0, 2) == 0 then
			local volume = 0.8 * math.min(1.0, math.abs(vel.z) / 450.0)
			self:EmitSound("debris/flesh" .. math.random(1, 7) .. ".wav", 75, 100, volume)
		end
	end

	local newVel = ClipVelocity(vel, normal, GIB_ELASTICITY)

	if isFloor and math.abs(newVel.z) < 60 then
		-- Settled on a floor — kill vertical, stop spinning, hand off to Think friction
		newVel.z = 0
		self.GibOnGround = true
		self:SetLocalAngularVelocity(Angle(0, 0, 0))
		local ang = self:GetAngles()
		ang.p = 0; ang.r = 0
		self:SetAngles(ang)
		-- Keep MOVETYPE_FLYGRAVITY to avoid "bad movetype" PhysicsSimulate spam.
		-- Gravity is zeroed out by killing Z velocity; Think() drives horizontal friction.
		self:SetGravity(0)
	end

	self:SetAbsVelocity(newVel)
end

function ENT:Think()
	if CLIENT then self:NextThink(CurTime()) return true end

	-- Airborne: just watch for stall / lifetime
	if not self.GibOnGround then
		if CurTime() > self.WaitTillLandTime then
			if self:GetAbsVelocity():LengthSqr() < 1 then
				SafeRemoveEntityDelayed(self, self.LifeTime)
				return
			else
				self.WaitTillLandTime = CurTime() + 0.5
			end
		end
		self:NextThink(CurTime())
		return true
	end

	-- Grounded: apply friction each tick
	local vel   = self:GetAbsVelocity()
	local dt    = FrameTime()
	local speed = vel:Length2D()

	if speed < 2 then
		self:SetAbsVelocity(Vector(0, 0, 0))
		self:SetMoveType(MOVETYPE_NONE)  -- fully static now; safe to freeze
		SafeRemoveEntityDelayed(self, self.LifeTime)
		return
	end

	local control  = math.max(speed, GIB_STOPSPEED)
	local newspeed = math.max(0, speed - dt * control * GIB_FRICTION)
	local scale    = newspeed / speed
	self:SetAbsVelocity(Vector(vel.x * scale, vel.y * scale, 0))

	self:NextThink(CurTime())
	return true
end

function ENT:Draw() self:DrawModel() end
