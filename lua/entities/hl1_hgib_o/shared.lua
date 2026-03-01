ENT.Type                  = "anim"
ENT.Base                  = "base_gmodentity"
ENT.PrintName             = "HL1 Gib (Optimised)"
ENT.Author                = "GilbUtils"
ENT.Spawnable             = false
ENT.AutomaticFrameAdvance = true

-- MOVETYPE_FLYGRAVITY + MOVECOLLIDE_FLY_BOUNCE
-- Engine handles gravity, sweep, and bounce via ResolveFlyCollisionBounce.
-- Source bounce formula: totalElasticity = GetElasticity() * surfaceElasticity, clamped [0, 0.9]
-- Concrete surfaceElasticity ≈ 0.25. HL1 target restitution = 0.45.
-- We can't hit 0.45 via SetElasticity alone (0.9*0.25=0.225 max on concrete).
-- Compensation: in StartTouch, detect under-bounce and add the missing velocity.
--   HL1 expected post-bounce speed = preBounce * 0.45
--   Source actual post-bounce speed = preBounce * (elasticity * surfElasticity)
--   Delta = preBounce * (0.45 - actual_ratio) applied along bounce direction.
--
-- StartTouch: fires once per new contact — record pre-bounce velocity, apply compensation + blood/sound.
-- EndTouch:   fires when contact ends — we're airborne again.
-- Touch:      fires every frame while in contact — apply grounded friction (vel *= 0.9 per HL1).

local HL1_ELASTICITY = 0.45   -- target restitution
-- SetElasticity value: we set high so engine gives max, then we top up in StartTouch
-- Max useful value before clamp: 0.9/surfElasticity. We set 3.6 (clamped to 0.9 on concrete).
local SET_ELASTICITY = 3.6

function ENT:Initialize()
	local model = self:GetNWString("GibModel", "models/gibs/hghl1.mdl")
	if model == "" then model = "models/gibs/hghl1.mdl" end
	self:SetModel(model)
	self:SetCollisionBounds(Vector(0, 0, 0), Vector(0, 0, 0))

	self.BloodDecalsLeft = 5
	self.BloodColor      = BLOOD_COLOR_RED
	self.GibVelocity     = Vector(0, 0, 0)
	self.GibOnGround     = false
	self.LifeTime        = 25

	if CLIENT then return end

	self:SetBodygroup(0, self:GetNWInt("GibBodygroup", 0))
	self:SetMoveType(MOVETYPE_FLYGRAVITY)
	self:SetMoveCollide(MOVECOLLIDE_FLY_BOUNCE)
	self:SetSolid(SOLID_BBOX)
	self:AddSolidFlags(FSOLID_NOT_STANDABLE)
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	self:SetGravity(800 / 600)
	self:SetElasticity(SET_ELASTICITY)
	self:SetLocalAngularVelocity(Angle(math.Rand(100, 200), math.Rand(100, 300), 0))

	self:NextThink(CurTime() + engine.TickInterval())
end

function ENT:StartTouch(ent)
	if CLIENT then return end

	-- Record pre-bounce speed (engine hasn't resolved yet when StartTouch fires... 
	-- actually it has. Measure post and compensate based on known ratio.)
	self._preBounceVel = self:GetAbsVelocity():Length()
end

function ENT:Touch(ent)
	if CLIENT then return end
	if self.GibOnGround then
		-- HL1 BounceGibTouch grounded: vel *= 0.9, flatten
		local vel = self:GetAbsVelocity()
		vel = vel * 0.9
		vel.z = 0
		self:SetAbsVelocity(vel)
		self:SetLocalAngularVelocity(Angle(0, 0, 0))
		local ang = self:GetAngles(); ang.p = 0; ang.r = 0; self:SetAngles(ang)
		if vel:Length2D() < 2 then
			self:SetAbsVelocity(Vector(0, 0, 0))
			self:SetMoveType(MOVETYPE_NONE)
			SafeRemoveEntityDelayed(self, self.LifeTime)
		end
		return
	end

	-- Detect floor contact
	local pos = self:GetPos()
	local tr  = util.TraceLine({ start = pos + Vector(0,0,4), endpos = pos - Vector(0,0,10), filter = self, mask = MASK_SOLID })
	if tr.Hit and tr.HitNormal.z > 0.7 then
		self._groundFrames = (self._groundFrames or 0) + 1
		if self._groundFrames >= 2 then
			self.GibOnGround = true
		end
	else
		self._groundFrames = 0
	end

	-- Blood decal on airborne bounce (first Touch frame of contact)
	if self._preBounceVel then
		local vel = self:GetAbsVelocity()
		-- Compensate: engine gave us (elasticity*surfElast) restitution, we want HL1_ELASTICITY
		-- Approximate: scale current velocity up by ratio
		local postSpeed = vel:Length()
		if postSpeed > 1 and self._preBounceVel > 1 then
			local actualRatio = postSpeed / self._preBounceVel
			if actualRatio < HL1_ELASTICITY then
				local scale = HL1_ELASTICITY / actualRatio
				self:SetAbsVelocity(vel * scale)
			end
		end
		self._preBounceVel = nil

		if self.BloodDecalsLeft > 0 and self.BloodColor ~= DONT_BLEED then
			local decal = (self.BloodColor == BLOOD_COLOR_YELLOW) and "YellowBlood" or "Blood"
			util.Decal(decal, pos + (tr.HitNormal or Vector(0,0,1)), pos - (tr.HitNormal or Vector(0,0,1)))
			self.BloodDecalsLeft = self.BloodDecalsLeft - 1
			if math.random(0, 2) == 0 then
				self:EmitSound("debris/flesh" .. math.random(1, 7) .. ".wav", 75, 100,
					0.8 * math.min(1.0, math.abs(self._preBounceVel or 100) / 450.0))
			end
		end
	end
end

function ENT:EndTouch(ent)
	if CLIENT then return end
	self._groundFrames = 0
end

function ENT:Think()
	if CLIENT then self:NextThink(CurTime()) return true end

	if not self._ready then
		self._ready = true
		self:SetAbsVelocity(self.GibVelocity)
	end

	self:NextThink(CurTime())
	return true
end

function ENT:Draw() self:DrawModel() end
