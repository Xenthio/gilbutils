ENT.Type                  = "anim"
ENT.Base                  = "base_gmodentity"
ENT.PrintName             = "HL1 Gib (Optimised)"
ENT.Author                = "GilbUtils"
ENT.Spawnable             = false
ENT.AutomaticFrameAdvance = true

-- hl1_hgib_o: MOVETYPE_FLYGRAVITY + MOVECOLLIDE_FLY_CUSTOM
--
-- The engine handles gravity integration and position sweeping each tick.
-- HOWEVER: with MOVECOLLIDE_FLY_CUSTOM, Touch() is responsible for ALL velocity
-- modification on collision. The engine does NOT pre-bounce or pre-stop the entity.
-- But GetAbsVelocity() inside Touch() returns the velocity AFTER the engine has already
-- clipped it for this frame — so we self-track GibVelocity (same as hl1_hgib) to
-- always have the correct pre-collision velocity for ClipVelocity().
--
-- Think() syncs GibVelocity from the engine each frame so gravity is captured.
-- Touch() uses GibVelocity for ClipVelocity, then calls SetAbsVelocity with the result.
-- Think() only handles friction when grounded.
--
-- NOTE: Never switch to MOVETYPE_WALK — causes "PhysicsSimulate: bad movetype 2" spam.

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

	self:SetMoveType(MOVETYPE_FLYGRAVITY)
	self:SetMoveCollide(MOVECOLLIDE_FLY_CUSTOM)
	self:SetSolid(SOLID_BBOX)
	self:AddSolidFlags(FSOLID_NOT_STANDABLE)
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

	-- Scale gravity to match HL1's 800 u/s² (sv_gravity default = 600)
	self:SetGravity(GIB_GRAVITY / 600)

	self.GibVelocity     = Vector(0, 0, 0)  -- our tracked velocity (pre-collision)
	self.GibOnGround     = false
	self.BloodDecalsLeft = 5
	self.BloodColor      = BLOOD_COLOR_RED
	self.LifeTime        = 25
	self.WaitTillLandTime = CurTime() + 4

	-- Engine integrates angular velocity for us — no manual angle math needed
	self:SetLocalAngularVelocity(Angle(math.Rand(100, 200), math.Rand(100, 300), 0))

	-- GibVelocity set by SpawnGib helper after Spawn(); apply it now
	if self.GibVelocity and self.GibVelocity:LengthSqr() > 0 then
		self:SetAbsVelocity(self.GibVelocity)
	end

	self:NextThink(CurTime())
end

function ENT:Touch(ent)
	if CLIENT then return end
	if self.GibOnGround then return end

	-- Use our self-tracked velocity, not GetAbsVelocity() — the engine may have
	-- already modified it by the time Touch() fires.
	local vel = self.GibVelocity

	-- Trace down to get the surface normal we just hit
	local pos = self:GetPos()
	local tr = util.TraceLine({
		start  = pos + Vector(0, 0, 4),
		endpos  = pos - Vector(0, 0, 12),
		filter = self,
		mask   = MASK_SOLID,
	})

	local normal  = tr.Hit and tr.HitNormal or Vector(0, 0, 1)
	local isFloor = normal.z > 0.7

	-- Blood decal
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
		self:SetGravity(0)  -- kill gravity; Think() handles horizontal friction
	end

	self.GibVelocity = newVel
	self:SetAbsVelocity(newVel)
end

function ENT:Think()
	if CLIENT then self:NextThink(CurTime()) return true end

	if not self.GibOnGround then
		-- Sync tracked velocity from engine each frame so gravity accumulation is captured
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

	-- Grounded: apply friction manually
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
	local scale    = newspeed / speed
	local newVel   = Vector(vel.x * scale, vel.y * scale, 0)
	self.GibVelocity = newVel
	self:SetAbsVelocity(newVel)

	self:NextThink(CurTime())
	return true
end

function ENT:Draw() self:DrawModel() end
