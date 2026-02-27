ENT.Type      = "anim"
ENT.Base      = "base_gmodentity"
ENT.PrintName = "HL1 Debris Gib"
ENT.Author    = "GilbUtils"
ENT.Spawnable = false

-- HL1 TE_BREAKMODEL physics port from HUD_TempEntUpdate / C_LocalTempEntity::Frame (Source SDK 2013).
-- bounceFactor = 1.0 (wood default), FTENT_SLOWGRAVITY = half gravity.
-- Used for breakable prop debris (crates, etc.) — NOT for combat gibs (use hl1_hgib for those).

local SV_GRAVITY = 800
local THINK_RATE = 0.015  -- ~66hz

function ENT:Initialize()
	if CLIENT then return end

	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_BBOX)
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	self:SetAngles(Angle(math.Rand(0, 360), math.Rand(0, 360), math.Rand(0, 360)))

	self.GibVel     = self.GibVel  or Vector(0, 0, 0)
	self.GibAVel    = Angle(math.Rand(-256, 256), math.Rand(-256, 256), math.Rand(-256, 256))
	self.GibRotate  = true
	self.GibSettled = false
	-- FTENT_SLOWGRAVITY: half gravity per think step
	self.GibGrav    = -SV_GRAVITY * 0.5 * THINK_RATE

	self:NextThink(CurTime())
end

function ENT:Think()
	if CLIENT then self:NextThink(CurTime()) return true end

	-- Once settled, do nothing — don't accumulate gravity or move
	if self.GibSettled then
		self:NextThink(CurTime() + 0.5)
		return true
	end

	-- FTENT_ROTATE: tumble in air
	if self.GibRotate then
		local ang = self:GetAngles()
		ang.p = ang.p + self.GibAVel.p * THINK_RATE
		ang.y = ang.y + self.GibAVel.y * THINK_RATE
		ang.r = ang.r + self.GibAVel.r * THINK_RATE
		self:SetAngles(ang)
	end

	-- FTENT_COLLIDEWORLD sweep
	local prevPos = self:GetPos()
	local newPos  = prevPos + self.GibVel * THINK_RATE

	local tr = util.TraceLine({
		start  = prevPos,
		endpos = newPos,
		filter = self,
		mask   = MASK_SOLID_BRUSHONLY,
	})

	if tr.Fraction < 1 then
		self:SetPos(prevPos + self.GibVel * THINK_RATE * tr.Fraction)

		local n    = tr.HitNormal
		local damp = 0.5  -- bounceFactor(1.0) * slowgravity damp(0.5)

		if n.z > 0.9 then
			-- Settle condition: downward vel is tiny (matches HL1 HUD_TempEntUpdate settle check)
			if self.GibVel.z <= 0 and self.GibVel.z >= self.GibGrav * 3 then
				damp            = 0
				self.GibRotate  = false
				self.GibSettled = true
				self.GibVel     = Vector(0, 0, 0)
				self.GibAVel    = Angle(0, 0, 0)
				local ang       = self:GetAngles()
				ang.p = 0; ang.r = 0
				self:SetAngles(ang)
				self:NextThink(CurTime() + 0.5)
				return true
			end
		end

		if damp ~= 0 then
			-- Reflect off surface
			local proj  = self.GibVel:Dot(n)
			self.GibVel = self.GibVel - n * proj * 2
			-- Non-floor bounce: negate yaw, damp angles
			if n.z <= 0.9 then
				local ang = self:GetAngles()
				ang.y = -ang.y
				ang.p = ang.p * 0.9
				ang.y = ang.y * 0.9
				ang.r = ang.r * 0.9
				self:SetAngles(ang)
			end
			self.GibVel = self.GibVel * damp
		end
	else
		self:SetPos(newPos)
	end

	-- Apply slow gravity after collision (matching HL1 order)
	self.GibVel.z = self.GibVel.z + self.GibGrav

	self:NextThink(CurTime() + THINK_RATE)
	return true
end

function ENT:Draw() self:DrawModel() end
