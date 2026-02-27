-- GilbUtils.Gibs
-- Helper library for spawning HL1-accurate gibs from any entity.
-- Requires the hl1_hgib entity (included in GilbUtils).
--
-- API:
--   GilbUtils.Gibs.Explode(ent, dmg)
--     Explodes any entity into HL1-accurate gibs using damage info for direction/overkill.
--     Safe to call from OnTakeDamage or NPCDeath hooks.
--
--   GilbUtils.Gibs.SpawnGib(model, bodygroup, pos, vel, bloodColor)
--     Spawns a single hl1_hgib at pos with the given velocity. Low-level, use Explode for most cases.

GilbUtils = GilbUtils or {}
GilbUtils.Gibs = GilbUtils.Gibs or {}

if CLIENT then return end  -- all gib spawning is serverside

local function SpawnGib(model, bodygroup, pos, vel, bloodColor)
    local gib = ents.Create("hl1_hgib")
    if not IsValid(gib) then return end
    gib:SetNWString("GibModel", model or "models/gibs/hghl1.mdl")
    gib:SetNWInt("GibBodygroup", bodygroup or 0)
    gib:SetNWInt("GibBloodColor", bloodColor or BLOOD_COLOR_RED)
    gib:SetPos(pos)
    gib:Spawn()
    gib:Activate()
    gib.GibVelocity = vel or Vector(0, 0, 0)
    gib.AngVelocity = Angle(math.Rand(100, 200), math.Rand(100, 300), 0)
    return gib
end

-- Public low-level spawn
GilbUtils.Gibs.SpawnGib = SpawnGib

-- Explode an entity into HL1-accurate gibs.
-- ent    — the entity being gibbed (used for position, bounds, blood color, eye pos)
-- dmg    — DamageInfo (optional, used for attack direction and overkill multiplier)
-- opts   — optional table:
--   model       (string)  gib model, default "models/gibs/hghl1.mdl"
--   count       (number)  body gib count, default 4
--   headGib     (bool)    spawn a head gib, default true
function GilbUtils.Gibs.Explode(ent, dmg, opts)
    if not IsValid(ent) then return end
    opts = opts or {}

    local model      = opts.model    or "models/gibs/hghl1.mdl"
    local count      = opts.count    or 4
    local spawnHead  = opts.headGib ~= false

    local bloodColor = BLOOD_COLOR_RED
    if ent.GetBloodColor then bloodColor = ent:GetBloodColor() end

    local obbMins = ent:OBBMins()
    local obbSize = ent:OBBMaxs() - obbMins

    -- Attack direction from damage force (points away from attacker in GMod)
    local attackDir = Vector(0, 0, -1)
    local overkill  = -50  -- default mild overkill
    if dmg then
        local force = dmg:GetDamageForce()
        if force:LengthSqr() > 0 then
            attackDir = force:GetNormalized()
        end
        overkill = -dmg:GetDamage()
    end

    -- HL1 velocity multiplier based on overkill
    local velMul = overkill > -50 and 0.7 or (overkill > -200 and 2.0 or 4.0)

    -- Head gib: spawns at EyePos, 5% chance thrown toward nearest player
    if spawnHead then
        local headPos = (ent.EyePos and ent:EyePos()) or (ent:GetPos() + Vector(0, 0, 64))
        local vel
        local ply = player.GetAll()[1]
        if ply and math.random(1, 100) <= 5 then
            vel = ((ply:EyePos() - headPos):GetNormalized() * 300 + Vector(0, 0, 100)) * velMul
        else
            vel = Vector(math.Rand(-100, 100), math.Rand(-100, 100), math.Rand(200, 300)) * velMul
        end
        if vel:Length() > 1500 then vel = vel:GetNormalized() * 1500 end
        SpawnGib(model, 0, headPos, vel, bloodColor)
    end

    -- Body gibs: random points inside bounding box, scattered by attack direction
    for i = 1, count do
        local pos = ent:GetPos() + obbMins + Vector(
            obbSize.x * math.Rand(0, 1),
            obbSize.y * math.Rand(0, 1),
            obbSize.z * math.Rand(0, 1) + 1
        )
        local vel = attackDir + Vector(
            math.Rand(-0.25, 0.25),
            math.Rand(-0.25, 0.25),
            math.Rand(-0.25, 0.25)
        )
        vel = vel * math.Rand(300, 400) * velMul
        if vel:Length() > 1500 then vel = vel:GetNormalized() * 1500 end
        SpawnGib(model, math.random(1, 5), pos, vel, bloodColor)
    end

    ent:EmitSound("common/bodysplat.wav")
end
