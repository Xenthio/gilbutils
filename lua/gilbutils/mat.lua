-- gilbutils/mat.lua
-- Material scanning and texture→material mapping utilities.
-- CLIENT only. Include via: include("gilbutils/mat.lua")

GilbMat = GilbMat or {}

-- Preserve original Material() globally so re-runs and Stop() can restore it.
_G._OrigMaterial = _G._OrigMaterial or Material

-- Full set of known texture slots across all shader types.
local TEX_SLOTS = {
    -- Standard
    "$basetexture", "$basetexture2", "$bumpmap", "$bumpmap2",
    "$detail", "$normalmap", "$normalmap2",
    -- Blend/mask
    "$blendmodulatetexture", "$blendtexture", "$blendmasktexture",
    -- Specular/phong
    "$envmapmask", "$phongexponenttexture", "$phongwarptexture",
    -- Lighting
    "$lightwarptexture", "$selfillummask", "$ambientoccltexture",
    -- Water/refraction
    "$refracttexture", "$waterbumptexture", "$underwateroverlay",
    -- Misc
    "$toolstexture", "$iris",
}
GilbMat.TEX_SLOTS = TEX_SLOTS

------------------------------------------------------------------------
-- TexMap
-- A deduplicated texture→[{mat,key,origTex}] mapping.
-- Create one per use-site: local tm = GilbMat.NewTexMap()
------------------------------------------------------------------------

function GilbMat.NewTexMap()
    return {
        cache   = {},   -- texName → { refs={}, loaded=false, ... }
        list    = {},   -- ordered unique texNames
        matSeen = {},   -- matName → true (already processed)
    }
end

-- Prefixes that are UI/icon textures — not renderable world materials, no VTF on disk.
local SKIP_PREFIXES = {
    "icon16/", "icon32/", "icon64/",
    "games/", "entities/", "spawnicons/",
    "vgui/", "gui/", "hud/",
}

-- Register all texture slots for a single material name into a TexMap.
-- No file I/O — purely in-memory GetTexture() calls.
-- onNewTex(texName) called when a texture is seen for the first time.
function GilbMat.RegisterMat(tm, matName, onNewTex)
    if not matName or matName == "" or matName:sub(1,2) == ".." then return end
    if tm.matSeen[matName] then return end
    -- Skip UI/icon materials — they're PNG/non-VTF and not world textures
    for _, prefix in ipairs(SKIP_PREFIXES) do
        if matName:sub(1, #prefix) == prefix then return end
    end
    tm.matSeen[matName] = true

    local mat = _G._OrigMaterial(matName)
    -- Note: don't bail on IsError() — world/prop materials may appear as error mats
    -- before the engine has rendered them for the first time, but GetTexture() can
    -- still succeed on some slots. Skip only if mat is nil.
    if not mat then return end

    for _, key in ipairs(TEX_SLOTS) do
        local ok, tex = pcall(function() return mat:GetTexture(key) end)
        if not ok or not tex or tex:IsError() then continue end
        local tname = tex:GetName()
        if not tname or tname == "" then continue end

        if not tm.cache[tname] then
            tm.cache[tname] = { refs={}, loaded=false }
            table.insert(tm.list, tname)
            if onNewTex then onNewTex(tname) end
        end

        local entry = tm.cache[tname]
        local found = false
        for _, r in ipairs(entry.refs) do
            if r.mat == mat and r.key == key then found = true; break end
        end
        if not found then
            table.insert(entry.refs, { mat=mat, key=key, origTex=tex })
        end
    end
end

-- Apply a texture object to every ref in a TexMap entry.
function GilbMat.ApplyTex(tm, texName, newTex)
    local entry = tm.cache[texName]
    if not entry then return end
    for _, r in ipairs(entry.refs) do
        r.mat:SetTexture(r.key, newTex)
    end
end

-- Restore the original texture for a single texture name in a TexMap.
function GilbMat.RestoreOne(tm, texName)
    local entry = tm.cache[texName]
    if not entry then return end
    for _, r in ipairs(entry.refs) do
        r.mat:SetTexture(r.key, r.origTex)
    end
end

-- Restore all original textures in a TexMap.
function GilbMat.RestoreAll(tm)
    for _, entry in pairs(tm.cache) do
        for _, r in ipairs(entry.refs) do
            r.mat:SetTexture(r.key, r.origTex)
        end
    end
end

------------------------------------------------------------------------
-- Scanner
-- Batched per-frame mat scanner — avoids freezing on large worlds.
------------------------------------------------------------------------

-- Create a scanner. Call :Queue(name) to add mats, :Start() to begin.
-- onDone() called when queue is empty.
-- batchSize: mats processed per frame (default 32).
function GilbMat.NewScanner(tm, onNewTex, onDone, batchSize)
    local sc = {
        tm        = tm,
        onNewTex  = onNewTex,
        onDone    = onDone,
        batchSize = batchSize or 32,
        queue     = {},
        hookName  = "GilbMat_Scan_" .. tostring({}),
        running   = false,
    }

    function sc:Queue(name)
        if name and name ~= "" and name:sub(1,2) ~= ".." and not self.tm.matSeen[name] then
            self.queue[#self.queue+1] = name
        end
    end

    -- Queue all materials from a single entity (GetMaterials + GetMaterial override).
    function sc:QueueEntity(ent)
        if not IsValid(ent) then return end
        local mats = ent:GetMaterials()
        if mats then for _, n in ipairs(mats) do self:Queue(n) end end
        local m = ent:GetMaterial()
        if m and m ~= "" then self:Queue(m) end
    end

    -- Queue world geometry (Entity(0)) + all current entities.
    function sc:QueueWorld()
        local world = Entity(0)
        if world and world.GetMaterials then
            for _, n in ipairs(world:GetMaterials()) do self:Queue(n) end
        end
        for _, ent in ipairs(ents.GetAll()) do self:QueueEntity(ent) end
    end

    -- Queue all materials found in the BSP (world geometry textures, skybox, static prop
    -- materials via MDL parsing, and BSP decals from infodecal entities).
    -- Requires gilbutils/bsp.lua and gilbutils/mdl.lua for full coverage.
    function sc:QueueBSP(mapname)
        if not GilbBSP then
            print("[GilbMat] GilbBSP not loaded — include gilbutils/bsp.lua first")
            return
        end
        local bsp = GilbBSP.Load(mapname)
        if not bsp then return end

        -- World geometry materials (BSP lump 43)
        for _, m in ipairs(bsp:GetMaterials()) do self:Queue(m) end

        -- Skybox from worldspawn entity
        local sky = bsp:GetSkyName()
        if sky then
            local faces = { "bk","dn","ft","lf","rt","up" }
            for _, face in ipairs(faces) do self:Queue("skybox/" .. sky .. face) end
        end

        -- Static prop materials (via temporary ClientsideModel — engine resolves paths)
        for _, m in ipairs(bsp:GetStaticPropMaterials()) do self:Queue(m) end

        -- BSP decals (infodecal entities)
        for _, m in ipairs(bsp:GetDecalMaterials()) do self:Queue(m) end
    end

    -- Queue materials from all env_sprite entities (sprite path stored in GetMaterial).
    function sc:QueueSprites()
        for _, ent in ipairs(ents.FindByClass("env_sprite")) do
            local m = ent:GetMaterial()
            if m and m ~= "" then self:Queue(m) end
        end
    end

    -- Queue decal materials by scanning the materials/decals/ directory.
    -- Queue a curated set of always-present HL2/GMod materials that are hard to catch
    -- via scanning (weapon skins, impact effects, blood, common particles, flesh, etc.)
    -- These are known to be resident in memory whenever the game is running.
    function sc:QueueCommon()
        local function scanVMTs(dir, pattern)
            for _, f in ipairs(file.Find("materials/"..dir.."/"..pattern..".vmt", "GAME")) do
                self:Queue(dir.."/"..f:sub(1,-5))
            end
        end

        -- Impact / blood decals (dynamically spawned, not map-placed)
        for _, sub in ipairs(file.Find("materials/decals/", "GAME")) do
            scanVMTs("decals/"..sub, "shot*")
            scanVMTs("decals/"..sub, "shot*_subrect")
        end
        scanVMTs("decals/flesh", "blood*")
        scanVMTs("decals/flesh", "blood*_subrect")
        scanVMTs("decals",       "scorch*")

        -- Effects
        local effectPats = {
            "muzzleflash*", "combinemuzzle*", "strider_muzzle*",
            "tracer*",
            "fire_cloud*", "fire_embers*", "fire_glow*",
            "fleck_*",
            "energyball*", "energysplash*",
            "ar2ground*", "ar2_altfire*",
            "blood*",
            "spark*", "splash*",
        }
        for _, pat in ipairs(effectPats) do scanVMTs("effects", pat) end

        -- Particle textures (subdirs: fire_particle_* etc)
        for _, sub in ipairs(file.Find("materials/particle/", "GAME")) do
            if sub:sub(1, 5) == "fire_" or sub:sub(1, 5) == "smoke" then
                scanVMTs("particle/"..sub, "*")
            end
        end
        scanVMTs("particle", "fire*")
        scanVMTs("particle", "smoke*")
        scanVMTs("particle", "sparkles*")
        scanVMTs("particle", "rain*")
        scanVMTs("particle", "snow*")

        -- Weapon viewmodels + player
        for _, w in ipairs({
            "v_pistol/hands", "v_pistol/v_pist_glock18",
            "v_shotgun/v_shotgun", "v_smg1/v_smg1",
            "v_ar2/v_combine_rifle", "v_rpg/v_rpg",
            "v_crossbow/v_crossbow", "v_physcannon/v_physcannon",
            "v_crowbar/v_crowbar", "v_357/v_357",
            "v_grenade/v_grenade", "v_hands",
        }) do self:Queue("models/weapons/"..w) end
        self:Queue("models/player/group01/male_01")
        self:Queue("models/player/group01/female_01")
    end

    function sc:Start()
        if self.running then return end
        self.running = true
        local self2 = self
        hook.Add("Think", self.hookName, function()
            if #self2.queue == 0 then
                hook.Remove("Think", self2.hookName)
                self2.running = false
                if self2.onDone then self2.onDone() end
                return
            end
            for i = 1, math.min(self2.batchSize, #self2.queue) do
                GilbMat.RegisterMat(self2.tm, table.remove(self2.queue, 1), self2.onNewTex)
            end
        end)
    end

    function sc:Stop()
        hook.Remove("Think", self.hookName)
        self.running = false
    end

    return sc
end

-- Intercept Material() globally to catch dynamically loaded mats.
-- Pass a scanner to auto-queue any new mat names that come through.
-- Call GilbMat.StopIntercept() to restore.
function GilbMat.StartIntercept(scanner)
    Material = function(name, ...)
        local m = _G._OrigMaterial(name, ...)
        if name and name ~= "" and name:sub(1,2) ~= ".." then
            timer.Simple(0.1, function() scanner:Queue(name); scanner:Start() end)
        end
        return m
    end
end

function GilbMat.StopIntercept()
    Material = _G._OrigMaterial
end

-- Hook util.Decal / util.DecalEx to catch decals as they're actually applied.
-- Only registers the decal material if it gets used in-game.
function GilbMat.StartDecalIntercept(scanner)
    local _DecalEx = util.DecalEx
    util.DecalEx = function(mat, ent, pos, normal, color, w, h)
        if IsValid(mat) then
            local name = mat:GetName()
            if name and name ~= "" then
                scanner:Queue(name); scanner:Start()
            end
        end
        return _DecalEx(mat, ent, pos, normal, color, w, h)
    end

    local _Decal = util.Decal
    util.Decal = function(name, start, end_, ...)
        if name and name ~= "" then
            scanner:Queue("decals/" .. name); scanner:Start()
        end
        return _Decal(name, start, end_, ...)
    end
end

function GilbMat.StopDecalIntercept()
    -- No stored originals to worry about — just nil the overrides
    -- (assumes nobody else overrode these, which is usually safe)
    util.DecalEx = nil  -- restore to C function
    util.Decal   = nil
end

-- Hook ParticleEffect / ParticleEffectAttach to catch active particle systems.
-- Registers the particle system name so if we ever find a way to grab its materials we can.
-- Also hooks CreateParticleSystem for more coverage.
-- Best-effort: GMod doesn't expose particle material lists, but the Material() intercept
-- will catch particle materials as the engine loads them during playback.
function GilbMat.StartParticleIntercept(scanner)
    local _PE = ParticleEffect
    ParticleEffect = function(name, ...)
        -- Material() intercept will catch the actual texture loads as the particle plays
        return _PE(name, ...)
    end
    -- The real coverage comes from StartIntercept() catching Material() calls
    -- that the particle system makes when it first renders each emitter.
end

function GilbMat.StopParticleIntercept()
    ParticleEffect = nil  -- restore to C function
end
