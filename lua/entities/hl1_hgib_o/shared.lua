ENT.Type                  = "anim"
ENT.Base                  = "base_gmodentity"
ENT.PrintName             = "HL1 Gib (Optimised)"
ENT.Author                = "GilbUtils"
ENT.Spawnable             = false
ENT.AutomaticFrameAdvance = true

-- Mirrors HL1 CGib exactly:
--   MOVETYPE_FLYGRAVITY + MOVECOLLIDE_DEFAULT → engine handles bounce via SetElasticity
--   Touch fires every frame while in contact (MOVECOLLIDE_DEFAULT behaviour)
--   Touch handles: blood decals on airborne bounce, vel*=0.9 when grounded (FL_ONGROUND)
--   SetElasticity(0.45) = HL1 pev->friction=0.55 → backoff=1.45 → restitution=0.45

function ENT:Initialize()
	local model = self:GetNWString("GibModel", "models/gibs/hghl1.mdl")
	if model == "" then model = "models/gibs/hghl1.mdl" end
	self:SetModel(model)
	self:SetCollisionBounds(Vector(0, 0, 0), Vector(0, 0, 0))

	self.BloodDecalsLeft = 5
	self.BloodColor      = BLOOD_COLOR_RED
	self.GibVelocity     = Vector(0, 0, 0)  -- used only for initial push
	self.LifeTime        = 25

	if CLIENT then return end

	self:SetBodygroup(0, self:GetNWInt("GibBodygroup", 0))
	self:SetMoveType(MOVETYPE_FLYGRAVITY)
	self:SetMoveCollide(MOVECOLLIDE_FLY_BOUNCE)
	self:SetSolid(SOLID_BBOX)
	self:AddSolidFlags(FSOLID_NOT_STANDABLE)
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	self:SetGravity(800 / 600)
	self:SetElasticity(0.45 / 0.2)  -- HL1 pev->friction=0.55 → backoff=1.45 → restitution=0.45
	self:SetLocalAngularVelocity(Angle(math.Rand(100, 200), math.Rand(100, 300), 0))

	self:NextThink(CurTime() + engine.TickInterval())
end

function ENT:Touch(ent)
	if CLIENT then return end

	local pos = self:GetPos()
	local tr  = util.TraceLine({ start = pos + Vector(0,0,4), endpos = pos - Vector(0,0,10), filter = self, mask = MASK_SOLID })
	local nearFloor = tr.Hit and tr.HitNormal.z > 0.7
	self._groundFrames = nearFloor and (self._groundFrames or 0) + 1 or 0

	if self._groundFrames >= 2 then
		-- Grounded: bleed speed (HL1 BounceGibTouch: vel *= 0.9)
		local vel = self:GetAbsVelocity() * 0.9
		vel.z = 0
		self:SetAbsVelocity(vel)

		-- Flatten rotation
		self:SetLocalAngularVelocity(Angle(0, 0, 0))
		local ang = self:GetAngles(); ang.p = 0; ang.r = 0; self:SetAngles(ang)

		if vel:Length2D() < 2 then
			self:SetAbsVelocity(Vector(0, 0, 0))
			self:SetMoveType(MOVETYPE_NONE)
			SafeRemoveEntityDelayed(self, self.LifeTime)
		end
		return
	end

	-- Airborne bounce: blood decal + sound
	if self.BloodDecalsLeft > 0 and self.BloodColor ~= DONT_BLEED then
		local pos = self:GetPos()
		local vel = self:GetAbsVelocity()
		local tr  = util.TraceLine({ start = pos + Vector(0,0,8), endpos = pos - Vector(0,0,24), filter = self, mask = MASK_SOLID })
		if tr.Hit then
			local decal = (self.BloodColor == BLOOD_COLOR_YELLOW) and "YellowBlood" or "Blood"
			util.Decal(decal, tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal)
			self.BloodDecalsLeft = self.BloodDecalsLeft - 1
			if math.random(0, 2) == 0 then
				self:EmitSound("debris/flesh" .. math.random(1, 7) .. ".wav", 75, 100,
					0.8 * math.min(1.0, math.abs(vel.z) / 450.0))
			end
		end
	end
end

function ENT:Think()
	if CLIENT then self:NextThink(CurTime()) return true end

	-- First tick: push initial velocity
	if not self._ready then
		self._ready = true
		self:SetAbsVelocity(self.GibVelocity)
	end

	self:NextThink(CurTime())
	return true
end

function ENT:Draw() self:DrawModel() end
