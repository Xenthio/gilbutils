ENT.Type                  = "anim"
ENT.Base                  = "base_gmodentity"
ENT.PrintName             = "HL1 Gib (Optimised)"
ENT.Author                = "GilbUtils"
ENT.Spawnable             = false
ENT.AutomaticFrameAdvance = true

-- hl1_hgib_o: MOVETYPE_FLYGRAVITY + MOVECOLLIDE_FLY_CUSTOM
--
-- Engine handles gravity integration and position sweeping each tick.
-- Touch() fires every frame while in contact with a surface and is responsible
-- for all velocity modification (that's what MOVECOLLIDE_FLY_CUSTOM means).
--
-- Key: GetAbsVelocity() inside Touch() returns the post-engine-resolution velocity,
-- NOT the pre-collision value. So we self-track GibVelocity in Think() (syncing from
-- the engine each airborne frame to capture gravity) and use that in Touch() for
-- ClipVelocity — giving us the correct pre-collision speed for accurate bouncing.
--
-- Think() is cheap: just syncs velocity while airborne + handles friction when grounded.
-- No manual gravity, no manual position integration, no manual traces during flight.

local GIB_ELASTICITY = 1 - 0.55
local GIB_FRICTION   = 4
local GIB_STOPSPEED  = 100
local GIB_GRAVITY    = 800

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

	self:SetMoveType(MOVETYPE_FLYGRAVITY)
	self:SetMoveCollide(MOVECOLLIDE_FLY_CUSTOM)
	self:SetSolid(SOLID_BBOX)
	self:AddSolidFlags(FSOLID_NOT_STANDABLE)
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	self:SetGravity(GIB_GRAVITY / 600)

	self:SetLocalAngularVelocity(Angle(math.Rand(100, 200), math.Rand(100, 300), 0))

	self.GibVelocity     = Vector(0, 0, 0)
	self.GibOnGround     = false
	self.BloodDecalsLeft = 5
	self.BloodColor      = BLOOD_COLOR_RED
	self.LifeTime        = 25
	self.WaitTillLandTime = CurTime() + 4

	-- Defer one tick so spawner can set GibVelocity after Activate()
	self:NextThink(CurTime() + engine.TickInterval())
end

function ENT:Touch(ent)
	if CLIENT then return end

	-- Use self-tracked GibVelocity — NOT GetAbsVelocity() which is post-engine-resolution
	local vel    = self.GibVelocity
	local pos    = self:GetPos()

	-- Get the surface normal we're touching via a short downward trace
	local tr = util.TraceLine({
		start  = pos + Vector(0, 0, 4),
		endpos = pos - Vector(0, 0, 12),
		filter = self,
		mask   = MASK_SOLID,
	})
	local normal  = tr.Hit and tr.HitNormal or Vector(0, 0, 1)
	local isFloor = normal.z > 0.7

	if self.GibOnGround then
		-- Already grounded — just prevent sinking, keep horizontal velocity
		-- Think() handles friction; Touch() just needs to not bounce us again
		self:SetAbsVelocity(Vector(vel.x, vel.y, 0))
		return
	end

	-- Blood decal on bounce
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
		newVel.z = 0
		self.GibOnGround = true
		self:SetLocalAngularVelocity(Angle(0, 0, 0))
		local ang = self:GetAngles()
		ang.p = 0; ang.r = 0
		self:SetAngles(ang)
		self:SetGravity(0)
	end

	self.GibVelocity = newVel
	self:SetAbsVelocity(newVel)
end

function ENT:Think()
	if CLIENT then self:NextThink(CurTime()) return true end

	-- First tick: push externally-set GibVelocity into engine
	if not self._velocityApplied then
		self._velocityApplied = true
		if self.GibVelocity:LengthSqr() > 0 then
			self:SetAbsVelocity(self.GibVelocity)
		end
		self:NextThink(CurTime())
		return true
	end

	if not self.GibOnGround then
		-- Sync from engine so GibVelocity stays accurate (gravity accumulates here)
		self.GibVelocity = self:GetAbsVelocity()

		if CurTime() > self.WaitTillLandTime then
			if self.GibVelocity:LengthSqr() < 1 then
				SafeRemoveEntityDelayed(self, self.LifeTime)
				return
			else
				self.WaitTillLandTime = CurTime() + 0.5
			end
		end

		self:NextThink(CurTime())
		return true
	end

	-- Grounded: friction
	local vel   = self.GibVelocity
	local dt    = FrameTime()
	local speed = vel:Length2D()

	if speed < 2 then
		self.GibVelocity = Vector(0, 0, 0)
		self:SetAbsVelocity(Vector(0, 0, 0))
		self:SetMoveType(MOVETYPE_NONE)
		SafeRemoveEntityDelayed(self, self.LifeTime)
		return
	end

	local control  = math.max(speed, GIB_STOPSPEED)
	local newspeed = math.max(0, speed - dt * control * GIB_FRICTION)
	local newVel   = Vector(vel.x * (newspeed / speed), vel.y * (newspeed / speed), 0)
	self.GibVelocity = newVel
	self:SetAbsVelocity(newVel)

	self:NextThink(CurTime())
	return true
end

function ENT:Draw() self:DrawModel() end
