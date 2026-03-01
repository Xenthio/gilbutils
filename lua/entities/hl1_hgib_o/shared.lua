ENT.Type                  = "anim"
ENT.Base                  = "base_gmodentity"
ENT.PrintName             = "HL1 Gib (Optimised)"
ENT.Author                = "GilbUtils"
ENT.Spawnable             = false
ENT.AutomaticFrameAdvance = true

-- MOVETYPE_FLYGRAVITY + MOVECOLLIDE_FLY_CUSTOM
-- Engine owns gravity + position sweep. Touch() owns velocity on collision.
-- Touch fires every frame while in contact, so we debounce it — ClipVelocity
-- applies once per contact sequence, not once per frame.
-- Grounded friction is time-based in Think(), not per-Touch.

local ELASTICITY   = 0.45   -- HL1: pev->friction=0.55 → restitution=0.45
local STOPSPEED    = 30     -- speed < 30 → full stop (matches Source engine)
local FRICTION     = 4      -- deceleration rate (units/s²-ish, same as hl1_hgib)
local TOUCH_WINDOW = 0.05   -- seconds before we allow another ClipVelocity (debounce)

local function ClipVelocity(vel, normal)
	return vel - normal * (vel:Dot(normal) * (1 + ELASTICITY))
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
	self:SetGravity(800 / 600)

	self:SetLocalAngularVelocity(Angle(math.Rand(100, 200), math.Rand(100, 300), 0))

	self.GibVelocity     = Vector(0, 0, 0)
	self.GibOnGround     = false
	self.BloodDecalsLeft = 5
	self.BloodColor      = BLOOD_COLOR_RED
	self.LifeTime        = 25
	self._lastTouch      = 0

	-- Defer so spawner can set GibVelocity after Activate()
	self:NextThink(CurTime() + engine.TickInterval())
end

function ENT:Touch(ent)
	if CLIENT then return end

	-- Debounce: only process one ClipVelocity per contact sequence
	local now = CurTime()
	if now - self._lastTouch < TOUCH_WINDOW then return end
	self._lastTouch = now

	local pos    = self:GetPos()
	local tr     = util.TraceLine({ start = pos + Vector(0,0,4), endpos = pos - Vector(0,0,12), filter = self, mask = MASK_SOLID })
	local normal = tr.Hit and tr.HitNormal or Vector(0, 0, 1)
	local isFloor = normal.z > 0.7

	if self.GibOnGround then return end  -- friction handled in Think

	-- Blood decal
	if self.BloodDecalsLeft > 0 and self.BloodColor ~= DONT_BLEED then
		local decal = (self.BloodColor == BLOOD_COLOR_YELLOW) and "YellowBlood" or "Blood"
		util.Decal(decal, pos + normal, pos - normal)
		self.BloodDecalsLeft = self.BloodDecalsLeft - 1
		if math.random(0, 2) == 0 then
			self:EmitSound("debris/flesh" .. math.random(1, 7) .. ".wav", 75, 100,
				0.8 * math.min(1.0, math.abs(self.GibVelocity.z) / 450.0))
		end
	end

	local newVel = ClipVelocity(self.GibVelocity, normal)

	if isFloor and math.abs(newVel.z) < 60 then
		newVel.z = 0
		self.GibOnGround = true
		self:SetLocalAngularVelocity(Angle(0, 0, 0))
		local ang = self:GetAngles(); ang.p = 0; ang.r = 0; self:SetAngles(ang)
		self:SetGravity(0)
	end

	self.GibVelocity = newVel
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

	local dt = FrameTime()

	if not self.GibOnGround then
		-- Sync so GibVelocity stays accurate as gravity accumulates
		self.GibVelocity = self:GetAbsVelocity()
	else
		-- Time-based friction on ground
		local vel   = self.GibVelocity
		local speed = vel:Length2D()

		if speed < STOPSPEED then
			self:SetAbsVelocity(Vector(0, 0, 0))
			self:SetMoveType(MOVETYPE_NONE)
			SafeRemoveEntityDelayed(self, self.LifeTime)
			return
		end

		local control  = math.max(speed, 100)  -- HL1 sv_stopspeed = 100
		local newspeed = math.max(0, speed - control * FRICTION * dt)
		local scale    = newspeed / speed
		local newVel   = Vector(vel.x * scale, vel.y * scale, 0)
		self.GibVelocity = newVel
		self:SetAbsVelocity(newVel)
	end

	self:NextThink(CurTime())
	return true
end

function ENT:Draw() self:DrawModel() end
