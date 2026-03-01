ENT.Type                  = "anim"
ENT.Base                  = "base_gmodentity"
ENT.PrintName             = "HL1 Gib (Optimised)"
ENT.Author                = "GilbUtils"
ENT.Spawnable             = false
ENT.AutomaticFrameAdvance = true

-- hl1_hgib_o optimisation strategy:
--   Phase 1 (airborne): MOVETYPE_FLYGRAVITY — engine handles gravity + position integration.
--                       Think() does nothing. SetLocalAngularVelocity handles spin for free.
--   Phase 2 (after first ground contact): Touch() captures velocity, switches to
--                       MOVETYPE_CUSTOM, and from then on Think() does full manual physics
--                       (identical to hl1_hgib) for multi-bounce and friction.
--
-- Result: saves all Think() cost during the initial flight arc (often 1-3 seconds).
-- After first contact, cost is identical to hl1_hgib.

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

	-- Phase 1: engine handles flight
	self:SetMoveType(MOVETYPE_FLYGRAVITY)
	self:SetMoveCollide(MOVECOLLIDE_FLY_CUSTOM)
	self:SetSolid(SOLID_BBOX)
	self:AddSolidFlags(FSOLID_NOT_STANDABLE)
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	self:SetGravity(GIB_GRAVITY / 600)

	-- Engine integrates angular spin during Phase 1
	self:SetLocalAngularVelocity(Angle(math.Rand(100, 200), math.Rand(100, 300), 0))

	self.GibVelocity     = Vector(0, 0, 0)
	self.GibOnGround     = false
	self.BloodDecalsLeft = 5
	self.BloodColor      = BLOOD_COLOR_RED
	self.LifeTime        = 25
	self.WaitTillLandTime = CurTime() + 4
	self._phase2         = false  -- true once we've switched to manual physics
	-- Fallback angular velocity for Phase 2 manual tumble (Phase 1 uses engine angvel)
	self.AngVelocity = Angle(math.Rand(100, 200), math.Rand(100, 300), 0)

	-- Defer one tick so spawner can set GibVelocity after Activate()
	self:NextThink(CurTime() + engine.TickInterval())
end

function ENT:Touch(ent)
	if CLIENT then return end
	if self._phase2 then return end  -- already in manual mode, Touch ignored

	-- Capture current engine velocity before switching modes
	local vel = self:GetAbsVelocity()

	-- Trace down for surface normal
	local pos = self:GetPos()
	local tr = util.TraceLine({
		start  = pos + Vector(0, 0, 4),
		endpos = pos - Vector(0, 0, 12),
		filter = self,
		mask   = MASK_SOLID,
	})
	local normal = tr.Hit and tr.HitNormal or Vector(0, 0, 1)

	-- Blood decal on first contact
	if self.BloodDecalsLeft > 0 and self.BloodColor ~= DONT_BLEED then
		local decal = (self.BloodColor == BLOOD_COLOR_YELLOW) and "YellowBlood" or "Blood"
		util.Decal(decal, pos + normal, pos - normal)
		self.BloodDecalsLeft = self.BloodDecalsLeft - 1
		if math.random(0, 2) == 0 then
			local volume = 0.8 * math.min(1.0, math.abs(vel.z) / 450.0)
			self:EmitSound("debris/flesh" .. math.random(1, 7) .. ".wav", 75, 100, volume)
		end
	end

	-- Apply HL1 bounce
	local newVel = ClipVelocity(vel, normal, GIB_ELASTICITY)
	if normal.z > 0.7 and math.abs(newVel.z) < 60 then
		newVel.z = 0
		self.GibOnGround = true
		self:SetLocalAngularVelocity(Angle(0, 0, 0))
		local ang = self:GetAngles()
		ang.p = 0; ang.r = 0
		self:SetAngles(ang)
	end

	-- Switch to Phase 2: manual Think() physics from here
	self._phase2     = true
	self.GibVelocity = newVel
	self:SetMoveType(MOVETYPE_CUSTOM)
	self:SetMoveCollide(MOVECOLLIDE_DEFAULT)
	self:SetAbsVelocity(Vector(0, 0, 0))  -- engine no longer moves us
	self:NextThink(CurTime())
end

function ENT:Think()
	if CLIENT then self:NextThink(CurTime()) return true end

	-- Phase 1: push initial velocity into engine on first tick, then do nothing
	if not self._phase2 then
		if not self._velocityApplied then
			self._velocityApplied = true
			if self.GibVelocity:LengthSqr() > 0 then
				self:SetAbsVelocity(self.GibVelocity)
			end
		end
		-- Stall guard
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

	-- Phase 2: full manual physics (identical to hl1_hgib)
	local dt = FrameTime()
	if dt <= 0 then self:NextThink(CurTime()) return true end

	if CurTime() > self.WaitTillLandTime then
		if self.GibVelocity:LengthSqr() < 1 then
			SafeRemoveEntityDelayed(self, self.LifeTime)
			return
		else
			self.WaitTillLandTime = CurTime() + 0.5
		end
	end

	local pos = self:GetPos()
	local vel = self.GibVelocity

	if self.GibOnGround then
		local speed = vel:Length2D()
		if speed > 0 then
			local control  = math.max(speed, GIB_STOPSPEED)
			local newspeed = math.max(0, speed - dt * control * GIB_FRICTION)
			vel.x = vel.x * (newspeed / speed)
			vel.y = vel.y * (newspeed / speed)
		end
		vel.z = 0

		if vel:Length2D() < 2 then
			self.GibVelocity = Vector(0, 0, 0)
			self:NextThink(CurTime())
			return true
		end

		local tr = util.TraceLine({
			start  = pos,
			endpos = pos + vel * dt,
			filter = self,
			mask   = MASK_SOLID,
		})
		if tr.Hit then
			vel.x = 0; vel.y = 0
			self:SetPos(tr.HitPos + tr.HitNormal * 0.1)
		else
			self:SetPos(pos + vel * dt)
		end

		self.GibVelocity = vel
		self:NextThink(CurTime())
		return true
	end

	-- Airborne (bouncing) — manual gravity + trace
	vel.z = vel.z - GIB_GRAVITY * dt
	local ang = self:GetAngles()
	ang:Add(self.AngVelocity * dt)
	self:SetAngles(ang)

	local tr = util.TraceLine({
		start  = pos,
		endpos = pos + vel * dt,
		filter = self,
		mask   = MASK_SOLID,
	})

	if tr.Hit then
		local normal  = tr.HitNormal
		local isFloor = normal.z > 0.7

		if self.BloodDecalsLeft > 0 and self.BloodColor ~= DONT_BLEED then
			local decal = (self.BloodColor == BLOOD_COLOR_YELLOW) and "YellowBlood" or "Blood"
			util.Decal(decal, tr.HitPos + normal, tr.HitPos - normal)
			self.BloodDecalsLeft = self.BloodDecalsLeft - 1
			if math.random(0, 2) == 0 then
				local volume = 0.8 * math.min(1.0, math.abs(vel.z) / 450.0)
				self:EmitSound("debris/flesh" .. math.random(1, 7) .. ".wav", 75, 100, volume)
			end
		end

		vel = ClipVelocity(vel, normal, GIB_ELASTICITY)

		if isFloor and math.abs(vel.z) < 60 then
			vel.z = 0
			self.GibOnGround = true
			self.AngVelocity = Angle(0, 0, 0)
			local a = self:GetAngles(); a.p = 0; a.r = 0
			self:SetAngles(a)
		end

		self:SetPos(tr.HitPos + normal * 0.1)
	else
		self:SetPos(pos + vel * dt)
	end

	self.GibVelocity = vel
	self:NextThink(CurTime())
	return true
end

function ENT:Draw() self:DrawModel() end
