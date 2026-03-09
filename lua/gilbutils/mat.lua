-- gilbutils/mat.lua
-- Material scanning and texture→material mapping utilities.
-- CLIENT only. Include via: include("gilbutils/mat.lua")

GilbMat = GilbMat or {}

-- Preserve original Material() globally so re-runs and Stop() can restore it.
_G._OrigMaterial = _G._OrigMaterial or Material

local TEX_SLOTS = {
    "$basetexture", "$basetexture2", "$bumpmap", "$bumpmap2",
    "$detail", "$blendmodulatetexture", "$blendtexture",
    "$blendmasktexture", "$normalmap", "$normalmap2"
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

-- Register all texture slots for a single material name into a TexMap.
-- No file I/O — purely in-memory GetTexture() calls.
-- onNewTex(texName) called when a texture is seen for the first time.
function GilbMat.RegisterMat(tm, matName, onNewTex)
    if not matName or matName == "" or matName:sub(1,2) == ".." then return end
    if tm.matSeen[matName] then return end
    tm.matSeen[matName] = true

    local mat = _G._OrigMaterial(matName)
    if not mat or mat:IsError() then return end

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

    function sc:QueueEntity(ent)
        if not IsValid(ent) then return end
        local mats = ent:GetMaterials()
        if mats then for _, n in ipairs(mats) do self:Queue(n) end end
        local m = ent:GetMaterial()
        if m and m ~= "" then self:Queue(m) end
    end

    function sc:QueueWorld()
        local world = Entity(0)
        if world and world.GetMaterials then
            for _, n in ipairs(world:GetMaterials()) do self:Queue(n) end
        end
        for _, ent in ipairs(ents.GetAll()) do self:QueueEntity(ent) end
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
            timer.Simple(0.1, function() scanner:Queue(name) end)
        end
        return m
    end
end

function GilbMat.StopIntercept()
    Material = _G._OrigMaterial
end
