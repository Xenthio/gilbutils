ENT.Type                  = "anim"
ENT.Base                  = "base_gmodentity"
ENT.PrintName             = "HL1 Gib (Optimised)"
ENT.Author                = "GilbUtils"
ENT.Spawnable             = false
ENT.AutomaticFrameAdvance = true

-- Identical physics to hl1_hgib (MOVETYPE_CUSTOM, manual Think loop).
-- The "optimised" distinction is reserved for future work; for now correctness first.

local GIB_ELASTICITY = 0.45
local GIB_FRICTION   = 4
local GIB_STOPSPEED  = 100
local GIB_GRAVITY    = 800

local function ClipVelocity(vel, normal)
	return vel - normal * (vel:Dot(normal) * (1 + GIB_ELASTICITY))
end

function ENT:Initialize()
	local model = self:GetNWString("GibModel", "models/gibs/hghl1.mdl")
	if model == "" then model = "models/gibs/hghl1.mdl" end
	self:SetModel(model)
	self:SetCollisionBounds(Vector(-4, -4, -4), Vector(4, 4, 4))

	self.GibVelocity     = Vector(0, 0, 0)
	self.AngVelocity     = Angle(math.Rand(100, 200), math.Rand(100, 300), 0)
	self.GibOnGround     = false
	self.BloodDecalsLeft = 5
	self.BloodColor      = BLOOD_COLOR_RED
	self.LifeTime        = 25

	if CLIENT then return end

	self:SetBodygroup(0, self:GetNWInt("GibBodygroup", 0))
	self:SetMoveType(MOVETYPE_CUSTOM)
	self:SetSolid(SOLID_BBOX)
	self:AddSolidFlags(FSOLID_NOT_STANDABLE)
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

	self:NextThink(CurTime() + engine.TickInterval())
end

function ENT:Think()
	if CLIENT then self:NextThink(CurTime()) return true end

	local dt = FrameTime()
	if dt <= 0 then self:NextThink(CurTime()) return true end

	-- Push initial velocity on first tick (spawner sets GibVelocity after Activate)
	if not self._ready then
		self._ready = true
		self:NextThink(CurTime())
		return true
	end

	local pos = self:GetPos()
	local vel = self.GibVelocity

	if self.GibOnGround then
		local speed = vel:Length2D()
		if speed < 2 then
			self.GibVelocity = Vector(0, 0, 0)
			SafeRemoveEntityDelayed(self, self.LifeTime)
			return
		end

		local control  = math.max(speed, GIB_STOPSPEED)
		local newspeed = math.max(0, speed - dt * control * GIB_FRICTION)
		vel = Vector(vel.x * (newspeed / speed), vel.y * (newspeed / speed), 0)

		local tr = util.TraceLine({ start = pos, endpos = pos + vel * dt, filter = self, mask = MASK_SOLID })
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

	-- Airborne
	vel.z = vel.z - GIB_GRAVITY * dt
	local ang = self:GetAngles()
	ang:Add(self.AngVelocity * dt)
	self:SetAngles(ang)

	local tr = util.TraceLine({ start = pos, endpos = pos + vel * dt, filter = self, mask = MASK_SOLID })

	if tr.Hit then
		local normal  = tr.HitNormal
		local isFloor = normal.z > 0.7

		if self.BloodDecalsLeft > 0 and self.BloodColor ~= DONT_BLEED then
			local decal = (self.BloodColor == BLOOD_COLOR_YELLOW) and "YellowBlood" or "Blood"
			util.Decal(decal, tr.HitPos + normal, tr.HitPos - normal)
			self.BloodDecalsLeft = self.BloodDecalsLeft - 1
			if math.random(0, 2) == 0 then
				self:EmitSound("debris/flesh" .. math.random(1, 7) .. ".wav", 75, 100,
					0.8 * math.min(1.0, math.abs(vel.z) / 450.0))
			end
		end

		vel = ClipVelocity(vel, normal)

		if isFloor and math.abs(vel.z) < 60 then
			vel.z = 0
			self.GibOnGround = true
			self.AngVelocity = Angle(0, 0, 0)
			local a = self:GetAngles(); a.p = 0; a.r = 0; self:SetAngles(a)
		end

		self:SetPos(tr.HitPos + normal * 0.1)
	else
		self:SetPos(pos + vel * dt)
	end

	self.GibVelocity = vel
	self:NextThink(CurTime())
	return true
end

function ENT:Touch(ent) end
function ENT:Draw() self:DrawModel() end
