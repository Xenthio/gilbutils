-- gilbutils/bsp.lua
-- BSP file parser for Valve's Source engine map format.
-- Extracts material paths, static prop model paths, and entity KV data from the loaded map.
-- CLIENT only. Include via: include("gilbutils/bsp.lua")
-- Usage: local bsp = GilbBSP.Load()  -- loads current map automatically

GilbBSP = GilbBSP or {}

------------------------------------------------------------------------
-- Internal helpers
------------------------------------------------------------------------

local function ru32(data, i)
    local a,b,c,d = string.byte(data, i, i+3)
    if not d then return 0 end
    return a + b*256 + c*65536 + d*16777216
end

local function ri32(data, i)
    local v = ru32(data, i)
    if v >= 0x80000000 then v = v - 0x100000000 end
    return v
end

local function ru16(data, i)
    local a,b = string.byte(data, i, i+1)
    if not b then return 0 end
    return a + b*256
end

------------------------------------------------------------------------
-- GilbBSP.Load([mapname]) — parse the BSP for the current (or named) map.
-- Returns a BSP table with methods, or nil on failure.
--
-- Returned table exposes:
--   bsp:GetMaterials()   — list of material path strings (world geometry textures)
--   bsp:GetStaticProps() — list of static prop model path strings
--   bsp:GetEntities()    — list of entity KV tables  { key=value, ... }
--   bsp:GetSkyName()     — skyname string from worldspawn, or nil
------------------------------------------------------------------------
function GilbBSP.Load(mapname)
    mapname = mapname or game.GetMap()
    local path = "maps/" .. mapname .. ".bsp"
    local data = file.Read(path, "GAME") or file.Read(path, "MOD")
    if not data then
        -- Try without maps/ prefix (some search path configs)
        data = file.Read(mapname .. ".bsp", "GAME") or file.Read(mapname .. ".bsp", "MOD")
    end
    if not data then
        print("[GilbBSP] Could not read " .. path .. " (tried GAME + MOD)")
        return nil
    end
    if data:sub(1,4) ~= "VBSP" then
        print("[GilbBSP] Not a valid BSP: " .. path)
        return nil
    end

    local version = ru32(data, 5)
    print(string.format("[GilbBSP] Loaded %s (version %d, %d bytes)", mapname, version, #data))

    -- Lump directory starts at byte 9 (after magic + version)
    -- Each entry: offset(4), length(4), version(4), fourCC(4) = 16 bytes, 64 lumps total
    local function getLump(index)
        local base   = 9 + index * 16  -- 0-indexed lump index
        local offset = ru32(data, base)
        local length = ru32(data, base + 4)
        if offset == 0 or length == 0 then return "" end
        return data:sub(offset + 1, offset + length)
    end

    local bsp = { _data=data, _getLump=getLump }

    --------------------------------------------------------------------
    -- Materials — Lump 43 (TEXDATA_STRING_DATA): null-separated strings
    -- All material paths used by world faces. No GAME/ prefix.
    --------------------------------------------------------------------
    function bsp:GetMaterials()
        local strData = getLump(43)
        if strData == "" then return {} end
        local mats = {}
        local seen = {}
        local pos = 1
        while pos <= #strData do
            local nul = strData:find("\0", pos, true)
            local s
            if nul then
                s = strData:sub(pos, nul - 1)
                pos = nul + 1
            else
                s = strData:sub(pos)
                pos = #strData + 1
            end
            if s and #s > 0 then
                local clean = s:lower():gsub("\\", "/")
                if not seen[clean] then
                    seen[clean] = true
                    mats[#mats+1] = clean
                end
            end
        end
        print(string.format("[GilbBSP] %d unique materials found", #mats))
        return mats
    end

    --------------------------------------------------------------------
    -- Static Props — Lump 35 (GAME_LUMP), subtype 'sprp'
    -- Returns list of model path strings (e.g. "models/props/barrel.mdl")
    --------------------------------------------------------------------
    function bsp:GetStaticProps()
        local gl = getLump(35)
        if gl == "" then return {} end

        -- Game lump header: lumpCount (int32)
        local lumpCount = ri32(gl, 1)
        local SPRP_ID   = 0x73707270  -- 'sprp' little-endian

        -- Find the sprp sub-lump
        local sprpOffset, sprpLength, sprpVersion
        local glBase = ru32(data, 9 + 35*16)  -- absolute offset of game lump in file

        for i = 0, lumpCount - 1 do
            local e    = 5 + i * 16  -- each entry: id(4)+flags(2)+version(2)+offset(4)+length(4)
            local id   = ru32(gl, e)
            local ver  = ru16(gl, e + 6)
            local off  = ru32(gl, e + 8)
            local len  = ru32(gl, e + 12)
            if id == SPRP_ID then
                sprpOffset  = off
                sprpLength  = len
                sprpVersion = ver
                break
            end
        end

        if not sprpOffset or sprpLength == 0 then return {} end

        -- Read sprp data from absolute file offset
        local sprp = data:sub(sprpOffset + 1, sprpOffset + sprpLength)
        if #sprp < 4 then return {} end

        -- Static prop dict: dictCount (int32), then dictCount × 128-byte model name strings
        local dictCount = ri32(sprp, 1)
        local models    = {}
        for i = 0, dictCount - 1 do
            local off   = 5 + i * 128
            local chunk = sprp:sub(off, off + 127)
            -- Find the null terminator manually (Lua patterns don't support \0 in char classes in all versions)
            local nulPos = chunk:find("\0", 1, true)
            local name   = nulPos and chunk:sub(1, nulPos - 1) or chunk
            if name and name ~= "" then
                models[#models+1] = name:lower():gsub("\\", "/")
            end
        end

        print(string.format("[GilbBSP] %d unique static prop models found", #models))
        return models
    end

    --------------------------------------------------------------------
    -- Entities — Lump 0 (ENTITIES): plain text KV format
    -- Returns list of tables { classname="...", key="value", ... }
    --------------------------------------------------------------------
    function bsp:GetEntities()
        local entData = getLump(0)
        if entData == "" then return {} end
        local entities = {}
        for block in entData:gmatch("{([^}]+)}") do
            local ent = {}
            for key, val in block:gmatch('"([^"]+)"%s*"([^"]*)"') do
                ent[key:lower()] = val
            end
            if next(ent) then entities[#entities+1] = ent end
        end
        print(string.format("[GilbBSP] %d entities parsed", #entities))
        return entities
    end

    --------------------------------------------------------------------
    -- Static Prop Materials — uses a temporary ClientsideModel to let the engine
    -- resolve each prop's material list, rather than parsing the MDL binary ourselves.
    -- Only runs CLIENT. Returns a flat deduplicated list of material path strings.
    --------------------------------------------------------------------
    function bsp:GetStaticPropMaterials()
        if SERVER then return {} end
        local props = self:GetStaticProps()
        local mats  = {}
        local seen  = {}
        local done  = {}  -- deduplicate by model path too

        for _, mdlPath in ipairs(props) do
            if done[mdlPath] then continue end
            done[mdlPath] = true

            -- Spawn a temp clientside model, grab its materials, remove it
            local ent = ClientsideModel(mdlPath)
            if not IsValid(ent) then continue end
            local entMats = ent:GetMaterials()
            ent:Remove()

            if entMats then
                for _, m in ipairs(entMats) do
                    local clean = m:lower():gsub("\\","/")
                    if clean ~= "" and not seen[clean] then
                        seen[clean] = true
                        mats[#mats+1] = clean
                    end
                end
            end
        end

        print(string.format("[GilbBSP] %d unique static prop materials found", #mats))
        return mats
    end

    --------------------------------------------------------------------
    -- BSP Decals — infodecal entities from the entity lump have a "texture" key.
    -- Returns list of material path strings (under materials/decals/).
    --------------------------------------------------------------------
    function bsp:GetDecalMaterials()
        local ents = self:GetEntities()
        local mats = {}
        local seen = {}
        for _, e in ipairs(ents) do
            if e.classname == "infodecal" and e.texture then
                local m = e.texture:lower():gsub("\\", "/")
                if not seen[m] then seen[m] = true; mats[#mats+1] = m end
            end
        end
        print(string.format("[GilbBSP] %d unique decal materials found", #mats))
        return mats
    end
    function bsp:GetSkyName()
        local ents = self:GetEntities()
        for _, e in ipairs(ents) do
            if e.classname == "worldspawn" and e.skyname then
                return e.skyname
            end
        end
        return nil
    end

    return bsp
end
