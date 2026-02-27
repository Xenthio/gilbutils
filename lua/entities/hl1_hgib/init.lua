AddCSLuaFile()

local ENT = {}
ENT.Type                  = "anim"
ENT.Base                  = "base_gmodentity"
ENT.PrintName             = "HL1 Gib"
ENT.Author                = "GilbUtils"
ENT.Spawnable             = false
ENT.AutomaticFrameAdvance = true

local GIB_ELASTICITY = 1 - 0.55
local GIB_FRICTION   = 4
local GIB_STOPSPEED  = 100
local GIB_GRAVITY    = 800

local function ClipVelocity(vel, normal, elasticity)
    local backoff = vel:Dot(normal) * (1 + elasticity)
    return vel - normal * backoff
end

function ENT:SetupDataTables()
    self:NetworkVar("Int",    0, "GibBodygroup")
    self:NetworkVar("Int",    1, "GibBloodColor")
    self:NetworkVar("String", 0, "GibModel")
end

function ENT:Initialize()
    -- Model is set by the spawner via :SetGibModel() BEFORE Spawn(),
    -- so by Initialize() the NW string is already set server-side.
    -- Client receives the correct model via the entity baseline.
    local model = self:GetGibModel()
    if model == "" then model = "models/gibs/hghl1.mdl" end
    self:SetModel(model)

    if SERVER then
        self:SetBodygroup(0, self:GetGibBodygroup())
        self:SetMoveType(MOVETYPE_CUSTOM)
        self:SetSolid(SOLID_BBOX)
        self:AddSolidFlags(FSOLID_NOT_STANDABLE)
        self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

        self.GibVelocity      = Vector(0, 0, 0)
        self.AngVelocity      = Angle(math.Rand(100, 200), math.Rand(100, 300), 0)
        self.GibOnGround      = false
        self.BloodDecalsLeft  = 5
        self.BloodColor       = self:GetGibBloodColor()
        self.LifeTime         = 25
        self.WaitTillLandTime = CurTime() + 4

        self:NextThink(CurTime())
    end
end

function ENT:Think()
    if CLIENT then self:NextThink(CurTime()) return true end

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
            local scale    = newspeed / speed
            vel.x = vel.x * scale
            vel.y = vel.y * scale
        end
        vel.z = 0

        -- CRITICAL: zero AngVelocity permanently on landing.
        -- GibOnGround can flicker when vel~0 causes trace to miss,
        -- so AngVelocity must be cleared here or the gib will spin on the floor.
        local ang = self:GetAngles()
        ang.p = 0; ang.r = 0
        self:SetAngles(ang)
        self.AngVelocity = Angle(0, 0, 0)
    else
        vel.z = vel.z - GIB_GRAVITY * dt

        local ang = self:GetAngles()
        ang:Add(self.AngVelocity * dt)
        self:SetAngles(ang)
    end

    local tr = util.TraceLine({
        start  = pos,
        endpos = pos + vel * dt,
        filter = self,
        mask   = MASK_SOLID,
    })

    if tr.Hit then
        local normal  = tr.HitNormal
        local isFloor = normal.z > 0.7

        if not self.GibOnGround and self.BloodDecalsLeft > 0 and self.BloodColor ~= DONT_BLEED then
            local decal = (self.BloodColor == BLOOD_COLOR_YELLOW) and "YellowBlood" or "Blood"
            util.Decal(decal, tr.HitPos + normal, tr.HitPos - normal)
            self.BloodDecalsLeft = self.BloodDecalsLeft - 1
            if math.random(0, 2) == 0 then
                local volume = 0.8 * math.min(1.0, math.abs(vel.z) / 450.0)
                self:EmitSound("debris/flesh" .. math.random(1, 7) .. ".wav", 75, 100, volume)
            end
        end

        vel = ClipVelocity(vel, normal, GIB_ELASTICITY)

        if isFloor and vel.z < 0 then
            if math.abs(vel.z) < 60 then
                vel.z = 0
                self.GibOnGround = true
            else
                self.GibOnGround = false
            end
        else
            self.GibOnGround = false
        end

        self:SetPos(tr.HitPos + normal * 0.1)
    else
        self.GibOnGround = false
        self:SetPos(pos + vel * dt)
    end

    self.GibVelocity = vel
    self:NextThink(CurTime())
    return true
end

function ENT:Touch(ent) end
function ENT:Draw() self:DrawModel() end

scripted_ents.Register(ENT, "hl1_hgib")
