-- gilbutils/mdl.lua
-- MDL + VVD parsing, corruption, and file writing.
-- CLIENT only. Include via: include("gilbutils/mdl.lua")

GilbMDL = GilbMDL or {}

------------------------------------------------------------------------
-- Utility: read unsigned integers (little-endian)
------------------------------------------------------------------------

local function ru32(data, offset)
    if offset + 3 > #data then return 0 end
    local a, b, c, d = string.byte(data, offset, offset+3)
    return a + b*256 + c*65536 + d*16777216
end

local function ru16(data, offset)
    if offset + 1 > #data then return 0 end
    local a, b = string.byte(data, offset, offset+1)
    return a + b*256
end

local function ru8(data, offset)
    if offset > #data then return 0 end
    return string.byte(data, offset)
end

local function writeU32(val)
    return string.char(
        val % 256,
        math.floor(val / 256) % 256,
        math.floor(val / 65536) % 256,
        math.floor(val / 16777216) % 256
    )
end

local function writeU16(val)
    return string.char(val % 256, math.floor(val / 256) % 256)
end

------------------------------------------------------------------------
-- MDL Parsing
------------------------------------------------------------------------

-- Parse MDL header, returns info table or nil if invalid.
-- Extracts: magic, version, checksum, num bones, bone offsets, etc.
function GilbMDL.ParseHeader(mdlData)
    if #mdlData < 4 or mdlData:sub(1, 4) ~= "IDST" then return nil end
    
    local hdr = {
        magic       = mdlData:sub(1, 4),
        version     = ru32(mdlData, 5),
        checksum    = ru32(mdlData, 9),
        name        = mdlData:sub(13, 76):match("^%Z*"),  -- null-terminated string, max 64 chars
        dataLength  = ru32(mdlData, 77),
        eyePosition = { ru32(mdlData, 81), ru32(mdlData, 85), ru32(mdlData, 89) },
        illumPosition = { ru32(mdlData, 93), ru32(mdlData, 97), ru32(mdlData, 101) },
        hullMinX    = ru32(mdlData, 105),
        hullMinY    = ru32(mdlData, 109),
        hullMinZ    = ru32(mdlData, 113),
        hullMaxX    = ru32(mdlData, 117),
        hullMaxY    = ru32(mdlData, 121),
        hullMaxZ    = ru32(mdlData, 125),
        viewBBMinX  = ru32(mdlData, 129),
        viewBBMinY  = ru32(mdlData, 133),
        viewBBMinZ  = ru32(mdlData, 137),
        viewBBMaxX  = ru32(mdlData, 141),
        viewBBMaxY  = ru32(mdlData, 145),
        viewBBMaxZ  = ru32(mdlData, 149),
        flags       = ru32(mdlData, 153),
        numBones    = ru32(mdlData, 157),
        boneIndexOffset = ru32(mdlData, 161),
        numBoneControllers = ru32(mdlData, 165),
        boneControllerIndexOffset = ru32(mdlData, 169),
        numHitboxes = ru32(mdlData, 173),
        hitboxIndexOffset = ru32(mdlData, 177),
        numSequences = ru32(mdlData, 181),
        seqOffset   = ru32(mdlData, 185),
        numBodyParts = ru32(mdlData, 189),
        bodyPartOffset = ru32(mdlData, 193),
        mdlData     = mdlData
    }
    
    return hdr
end

-- Extract bone position/rotation arrays from MDL file.
-- Returns: { bonePositions = [...], boneRotations = [...], boneNames = [...] }
function GilbMDL.ExtractBones(hdr)
    if not hdr or hdr.numBones == 0 then return nil end
    
    local mdl = hdr.mdlData
    local offset = hdr.boneIndexOffset + 1
    local bones = { positions = {}, rotations = {}, names = {} }
    
    for i = 1, hdr.numBones do
        if offset + 108 > #mdl then break end
        
        -- MSTUDIOBONE struct: 108 bytes each
        local name = mdl:sub(offset, offset+31):match("^%Z*")
        local px = ru32(mdl, offset+32)  -- float as uint32
        local py = ru32(mdl, offset+36)
        local pz = ru32(mdl, offset+40)
        
        -- Store raw float bits for now; corruption operates on byte-level
        table.insert(bones.names, name)
        table.insert(bones.positions, { px, py, pz, offset=offset+32 })
        table.insert(bones.rotations, { offset+44 })  -- quat rotation at +44
        
        offset = offset + 108
    end
    
    return bones
end

------------------------------------------------------------------------
-- VVD Parsing
------------------------------------------------------------------------

-- Parse VVD header and vertex data.
-- Returns: { header = {...}, vertices = [raw bytes], fileSize, vvdData }
function GilbMDL.ParseVVD(vvdData)
    if #vvdData < 4 or vvdData:sub(1, 4) ~= "IDSV" then return nil end
    
    -- VVD header layout (all offsets 0-indexed, Lua uses +1):
    --  0: magic (4)
    --  4: version (int32)
    --  8: checksum (int32)
    -- 12: numLODs (int32)
    -- 16: numLODVertices[8] (8 × int32 = 32 bytes)  ← big array!
    -- 48: numFixups (int32)
    -- 52: fixupTableOffset (int32)
    -- 56: vertexDataOffset (int32)
    -- 60: tangentDataOffset (int32)
    local hdr = {
        magic             = vvdData:sub(1, 4),
        version           = ru32(vvdData, 5),
        checksum          = ru32(vvdData, 9),
        numLODs           = ru32(vvdData, 13),
        numLODVertices    = ru32(vvdData, 17),  -- LOD0 vertex count (first of 8)
        numFixups         = ru32(vvdData, 49),
        fixupTableOffset  = ru32(vvdData, 53),
        vertexDataOffset  = ru32(vvdData, 57),
        tangentDataOffset = ru32(vvdData, 61),
    }
    
    -- Vertices start at vertexDataOffset; each vertex is ~48 bytes in most cases
    local vertexData = vvdData:sub(hdr.vertexDataOffset + 1)
    
    return {
        header = hdr,
        vertices = vertexData,
        fileSize = #vvdData,
        vvdData = vvdData
    }
end

------------------------------------------------------------------------
-- Corruption helpers
------------------------------------------------------------------------

-- Corrupt vertex position data in VVD.
-- Modifies random X/Y/Z floats (as uint32 bit patterns) in vertices.
-- Returns: newVVDData, numBytesCorrupted
function GilbMDL.CorruptVertexPositions(vvdInfo, seed, mode)
    math.randomseed(seed)
    
    local vvd = vvdInfo.vvdData
    local hdr = vvdInfo.header
    local vertexBase = hdr.vertexDataOffset
    
    -- Vertex struct is 48 bytes: 3×float (pos), 3×float (norm), 2×float (uv), 4×byte (bone weights), 4×byte (bone indices), 2×float (uv2)
    -- Position: bytes 0-11 (3 floats)
    
    local numVertices = hdr.numLODVertices
    if numVertices == 0 or numVertices > 100000 then return vvd, 0 end
    
    local vertexStride = 48
    local maxCorruptions = math.max(1, math.floor(numVertices / 4))
    local corrupted = 0
    local bytesMod = {}
    
    for i = 1, maxCorruptions do
        local vIdx = math.random(0, numVertices - 1)
        local vBase = vertexBase + vIdx * vertexStride + 1
        
        -- Pick X, Y, or Z (each 4 bytes)
        local axis = math.random(1, 3)
        local axisOffset = (axis - 1) * 4
        local floatOffset = vBase + axisOffset
        
        if floatOffset + 3 <= #vvd then
            -- Mode: bit flip the float bits
            if mode == 1 then
                -- Flip random bits in the float
                local flipMask = math.random(0, 255)
                for j = 0, 3 do
                    local byte = ru8(vvd, floatOffset + j)
                    bytesMod[floatOffset + j] = bit.bxor(byte, flipMask)
                    corrupted = corrupted + 1
                end
            elseif mode == 2 then
                -- Zero out the float (NaN or 0)
                for j = 0, 3 do
                    bytesMod[floatOffset + j] = 0
                    corrupted = corrupted + 1
                end
            elseif mode == 3 then
                -- Swap bytes within float (endianness flip)
                local b0 = ru8(vvd, floatOffset)
                local b1 = ru8(vvd, floatOffset + 1)
                local b2 = ru8(vvd, floatOffset + 2)
                local b3 = ru8(vvd, floatOffset + 3)
                bytesMod[floatOffset]     = b3
                bytesMod[floatOffset + 1] = b2
                bytesMod[floatOffset + 2] = b1
                bytesMod[floatOffset + 3] = b0
                corrupted = 4
            else
                -- Mode 4: random bit flip
                local flipMask = math.random(1, 255)
                for j = 0, 3 do
                    local byte = ru8(vvd, floatOffset + j)
                    bytesMod[floatOffset + j] = bit.bxor(byte, flipMask)
                    corrupted = corrupted + 1
                end
            end
        end
    end
    
    -- Apply modifications
    if #bytesMod == 0 then return vvd, 0 end
    
    local result = {}
    for i = 1, #vvd do
        result[i] = string.char(bytesMod[i] or ru8(vvd, i))
    end
    
    return table.concat(result), corrupted
end

-- Corrupt bone transformation offsets in MDL.
-- Returns: newMDLData, numBytesCorrupted
function GilbMDL.CorruptBoneTransforms(hdr, seed, mode)
    math.randomseed(seed)
    
    local mdl = hdr.mdlData
    local numBones = hdr.numBones
    if numBones == 0 or numBones > 256 then return mdl, 0 end
    
    local offset = hdr.boneIndexOffset + 1
    local corrupted = 0
    local bytesMod = {}
    
    for i = 1, numBones do
        if offset + 108 > #mdl then break end
        
        -- Corrupt position (bytes 32-43, 3 floats) or rotation (bytes 44-59, 4 floats quat)
        if math.random() < 0.5 then
            -- Position
            local posOff = offset + 32
            for j = 0, 11 do
                if math.random() < 0.3 then
                    local byte = ru8(mdl, posOff + j)
                    bytesMod[posOff + j] = bit.bxor(byte, math.random(1, 255))
                    corrupted = corrupted + 1
                end
            end
        else
            -- Rotation quat
            local rotOff = offset + 44
            for j = 0, 15 do
                if math.random() < 0.3 then
                    local byte = ru8(mdl, rotOff + j)
                    bytesMod[rotOff + j] = bit.bxor(byte, math.random(1, 255))
                    corrupted = corrupted + 1
                end
            end
        end
        
        offset = offset + 108
    end
    
    if #bytesMod == 0 then return mdl, 0 end
    
    local result = {}
    for i = 1, #mdl do
        result[i] = string.char(bytesMod[i] or ru8(mdl, i))
    end
    
    return table.concat(result), corrupted
end

------------------------------------------------------------------------
-- VVD Writing
------------------------------------------------------------------------

-- Write modified VVD data back to file.
function GilbMDL.WriteVVD(vvdData, filepath)
    file.Write(filepath, vvdData)
end

-- Write modified MDL data back to file.
function GilbMDL.WriteMDL(mdlData, filepath)
    file.Write(filepath, mdlData)
end
