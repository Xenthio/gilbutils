-- gilbutils/data.lua
-- Generic binary data corruption utilities.
-- Works on any Lua string (byte blob) — VTF, MDL, VVD, WAV, whatever.
-- Include via: include("gilbutils/data.lua")

GilbData = GilbData or {}

------------------------------------------------------------------------
-- GilbData.COMPONENTS — maps failing hardware to the corruption modes it causes.
-- Use with GilbData.RandomModeFor() to get a thematically appropriate mode.
--
-- Components:
--   "ram"    — Bad system RAM:     stuck bits, bit rot, bit flip regions, overflow drift
--   "vram"   — Bad VRAM:           stuck bits, bit rot, stride repeat (texture row glitches), self echo, quantization crush
--   "gpu"    — Bad GPU/shader:     stride repeat, xor pattern, self echo, quantization crush, endian swap
--   "disk"   — Bad HDD:            sector repeat, block transpose, data bleed, zero wipe
--   "ssd"    — Bad SSD/NAND:       zero wipe, block transpose, bit rot, random sprinkle, overflow drift
--   "cpu"    — Bad CPU/ALU:        xor pattern, endian swap, overflow drift, bit flip
--   "bus"    — Bad memory bus:     self echo, xor pattern, bit flip, endian swap
--   "psu"    — Unstable PSU:       overflow drift, bit flip, random sprinkle, zero wipe
------------------------------------------------------------------------
GilbData.COMPONENTS = {
    ram  = { 7, 8, 2, 14 },           -- stuck bits, bit rot, bit flip, overflow drift
    vram = { 7, 8, 1, 9, 12 },        -- stuck bits, bit rot, stride repeat, self echo, quantization crush
    gpu  = { 1, 4, 9, 12, 11 },       -- stride repeat, xor pattern, self echo, quantization crush, endian swap
    disk = { 10, 13, 3, 5 },          -- sector repeat, block transpose, data bleed, zero wipe
    ssd  = { 5, 13, 8, 6, 14 },       -- zero wipe, block transpose, bit rot, random sprinkle, overflow drift
    cpu  = { 4, 11, 14, 2 },          -- xor pattern, endian swap, overflow drift, bit flip
    bus  = { 9, 4, 2, 11 },           -- self echo, xor pattern, bit flip, endian swap
    psu  = { 14, 2, 6, 5 },           -- overflow drift, bit flip, random sprinkle, zero wipe
}

-- GilbData.RandomModeFor(components) — pick a random corruption mode from a set of faulty components.
-- components: a string component name, or a table of component names.
-- Builds the union of all modes from the listed components, then picks one at random.
--
-- Examples:
--   GilbData.RandomModeFor("vram")               -- pure VRAM failure
--   GilbData.RandomModeFor({"ram", "psu"})        -- unstable PSU causing RAM errors
--   GilbData.RandomModeFor({"disk", "ssd"})       -- storage failure
--   GilbData.RandomModeFor({"gpu", "bus", "vram"}) -- GPU subsystem meltdown
function GilbData.RandomModeFor(components)
    if type(components) == "string" then components = {components} end
    local seen  = {}
    local modes = {}
    for _, comp in ipairs(components) do
        local list = GilbData.COMPONENTS[comp]
        if list then
            for _, m in ipairs(list) do
                if not seen[m] then seen[m] = true; modes[#modes+1] = m end
            end
        end
    end
    if #modes == 0 then return math.random(1, 14) end
    return modes[math.random(1, #modes)]
end

-- GilbData.Corrupt(data, allData, mode) — corrupt a byte string in-place (returns new string).
--
-- data    : the byte string to corrupt (e.g. a mip slice, a VVD vertex block)
-- allData : optional wider pool to bleed bytes from (e.g. full VTF for mode 3)
-- mode    : 1-14, or nil for random
--
-- Modes:
--   1  = STRIDE REPEAT      — tile a random row over a region
--   2  = BIT FLIP           — XOR a region with a single-byte mask
--   3  = DATA BLEED         — copy bytes from allData (or self) into a region
--   4  = XOR PATTERN        — XOR a region with a short repeating pattern
--   5  = ZERO WIPE          — zero out a region
--   6  = RANDOM SPRINKLE    — scatter random bytes at random positions
--   7  = STUCK BITS         — force a bit position to always 0 or 1 across a region (bad RAM cell)
--   8  = BIT ROT            — sparse single-bit flips scattered across data (magnetic decay)
--   9  = SELF ECHO          — XOR a region with an offset copy of itself (interference banding)
--   10 = SECTOR REPEAT      — tile one fixed block over a large region (stuck disk head)
--   11 = ENDIAN SWAP        — swap byte pairs or 4-byte chunks (mismatched endianness)
--   12 = QUANTIZATION CRUSH — AND every byte with a bitmask, crushing bit depth
--   13 = BLOCK TRANSPOSE    — swap two same-size chunks at different offsets
--   14 = OVERFLOW DRIFT     — ADD a constant to every byte with wraparound (voltage drift)
--
-- Returns: corrupted string, startOffset, endOffset (0-indexed byte range that was modified)
function GilbData.Corrupt(data, allData, mode)
    local len = #data
    if len == 0 then return data, 0, 0 end
    if CLIENT then
        local forced = GetConVar("gilbdata_force_mode"):GetString()
        if forced ~= "0" and forced ~= "" then
            local num = tonumber(forced)
            if num then
                mode = math.floor(num)
            else
                -- Space-separated component names e.g. "vram gpu bus"
                local comps = {}
                for word in forced:gmatch("%S+") do comps[#comps+1] = word end
                mode = GilbData.RandomModeFor(comps)
            end
        end
    end
    mode = mode or math.random(1, 14)

    if mode == 1 then
        -- STRIDE REPEAT
        local stride = math.random(8, math.min(64, math.floor(len/4)))
        local srcOff = math.random(0, len-stride)
        local row    = data:sub(srcOff+1, srcOff+stride)
        local dstOff = math.random(0, len-1)
        local dstLen = math.min(math.random(stride*2, stride*16), len-dstOff)
        local patch  = {}; local pos = 0
        while pos < dstLen do
            local chunk = math.min(stride, dstLen-pos)
            patch[#patch+1] = row:sub(1, chunk); pos = pos+chunk
        end
        return data:sub(1,dstOff)..table.concat(patch)..data:sub(dstOff+dstLen+1), dstOff, dstOff+dstLen-1

    elseif mode == 2 then
        -- BIT FLIP REGION
        local mask   = math.random(1, 255)
        local dstOff = math.random(0, math.floor(len/2))
        local dstLen = math.min(math.random(math.floor(len/8), math.floor(len/2)), len-dstOff)
        local region = data:sub(dstOff+1, dstOff+dstLen)
        local out    = {}
        for i=1,#region do out[i]=string.char(bit.bxor(string.byte(region,i), mask)) end
        return data:sub(1,dstOff)..table.concat(out)..data:sub(dstOff+dstLen+1), dstOff, dstOff+dstLen-1

    elseif mode == 3 then
        -- DATA BLEED — bleeds bytes from allData (or self) into a region
        local pool   = allData or data
        local srcLen = math.random(math.floor(len/4), math.floor(len/2))
        local srcOff = math.random(0, math.max(0, #pool-srcLen))
        local bleed  = pool:sub(srcOff+1, srcOff+srcLen)
        local dstOff = math.random(0, len-1)
        local avail  = len-dstOff
        local written = math.min(srcLen, avail)
        return data:sub(1,dstOff)..bleed:sub(1,avail)..data:sub(dstOff+written+1), dstOff, dstOff+written-1

    elseif mode == 4 then
        -- XOR PATTERN
        local patLen = math.random(2, 8)
        local pat    = {}; for i=1,patLen do pat[i]=math.random(0,255) end
        local dstOff = math.random(0, math.floor(len/2))
        local dstLen = math.min(math.random(math.floor(len/4), math.floor(len*3/4)), len-dstOff)
        local region = data:sub(dstOff+1, dstOff+dstLen)
        local out    = {}
        for i=1,#region do
            out[i]=string.char(bit.bxor(string.byte(region,i), pat[(i-1)%patLen+1]))
        end
        return data:sub(1,dstOff)..table.concat(out)..data:sub(dstOff+dstLen+1), dstOff, dstOff+dstLen-1

    elseif mode == 5 then
        -- ZERO WIPE
        local dstOff = math.random(0, math.floor(len*2/3))
        local dstLen = math.min(math.random(math.floor(len/16), math.floor(len/6)), len-dstOff)
        return data:sub(1,dstOff)..string.rep("\0",dstLen)..data:sub(dstOff+dstLen+1), dstOff, dstOff+dstLen-1

    elseif mode == 6 then
        -- RANDOM SPRINKLE — scatter random byte values at random positions
        local count   = math.random(math.floor(len/32), math.floor(len/4))
        local pos_set = {}
        for _=1,count do pos_set[math.random(0,len-1)] = math.random(0,255) end
        local sorted = {}
        for p,v in pairs(pos_set) do sorted[#sorted+1]={p,v} end
        table.sort(sorted, function(a,b) return a[1]<b[1] end)
        local out = {}; local cur = 1
        for _,pv in ipairs(sorted) do
            local idx,byte = pv[1]+1, pv[2]
            if idx >= cur then
                out[#out+1] = data:sub(cur, idx-1)
                out[#out+1] = string.char(byte)
                cur = idx+1
            end
        end
        out[#out+1] = data:sub(cur)
        local s0 = sorted[1] and sorted[1][1] or 0
        local s1 = sorted[#sorted] and sorted[#sorted][1] or 0
        return table.concat(out), s0, s1

    elseif mode == 7 then
        -- STUCK BITS — force one bit position to always 0 or 1 across a region (bad RAM cell row)
        local bitPos  = math.random(0, 7)
        local stuck1  = math.random(0, 1) == 1  -- stuck high or stuck low
        local dstOff  = math.random(0, math.floor(len/2))
        local dstLen  = math.min(math.random(math.floor(len/8), math.floor(len/2)), len-dstOff)
        local region  = data:sub(dstOff+1, dstOff+dstLen)
        local mask    = bit.lshift(1, bitPos)
        local out     = {}
        for i=1,#region do
            local b = string.byte(region, i)
            if stuck1 then
                out[i] = string.char(bit.bor(b, mask))
            else
                out[i] = string.char(bit.band(b, bit.bxor(0xFF, mask)))
            end
        end
        return data:sub(1,dstOff)..table.concat(out)..data:sub(dstOff+dstLen+1), dstOff, dstOff+dstLen-1

    elseif mode == 8 then
        -- BIT ROT — sparse single-bit flips scattered across the whole data (magnetic decay)
        local count  = math.random(math.floor(len/64), math.floor(len/8))
        local flips  = {}
        for _=1,count do
            local pos = math.random(0, len-1)
            flips[pos] = bit.lshift(1, math.random(0,7))
        end
        local sorted = {}
        for p,m in pairs(flips) do sorted[#sorted+1]={p,m} end
        table.sort(sorted, function(a,b) return a[1]<b[1] end)
        local out = {}; local cur = 1
        for _,pm in ipairs(sorted) do
            local idx, mask = pm[1]+1, pm[2]
            if idx >= cur then
                out[#out+1] = data:sub(cur, idx-1)
                out[#out+1] = string.char(bit.bxor(string.byte(data, idx), mask))
                cur = idx+1
            end
        end
        out[#out+1] = data:sub(cur)
        local s0 = sorted[1] and sorted[1][1] or 0
        local s1 = sorted[#sorted] and sorted[#sorted][1] or 0
        return table.concat(out), s0, s1

    elseif mode == 9 then
        -- SELF ECHO — XOR a region with an offset copy of itself (interference banding on static data)
        local echoOffset = math.random(math.floor(len/16), math.floor(len/4))
        local dstOff     = math.random(0, math.floor(len/2))
        local dstLen     = math.min(math.random(math.floor(len/8), math.floor(len/2)), len-dstOff)
        local region     = data:sub(dstOff+1, dstOff+dstLen)
        local echoStart  = math.max(1, dstOff+1 - echoOffset)
        local echo       = data:sub(echoStart, echoStart+dstLen-1)
        local out        = {}
        for i=1,#region do
            local eb = string.byte(echo, i) or 0
            out[i] = string.char(bit.bxor(string.byte(region, i), eb))
        end
        return data:sub(1,dstOff)..table.concat(out)..data:sub(dstOff+dstLen+1), dstOff, dstOff+dstLen-1

    elseif mode == 10 then
        -- SECTOR REPEAT — tile one fixed-size block over a large region (stuck disk head)
        local secSize = math.random(64, math.min(512, math.floor(len/4)))
        local secOff  = math.random(0, math.max(0, len-secSize))
        local sector  = data:sub(secOff+1, secOff+secSize)
        local dstOff  = math.random(0, math.floor(len/2))
        local dstLen  = math.min(math.random(secSize*4, secSize*16), len-dstOff)
        local patch   = {}; local pos = 0
        while pos < dstLen do
            local chunk = math.min(secSize, dstLen-pos)
            patch[#patch+1] = sector:sub(1, chunk); pos = pos+chunk
        end
        return data:sub(1,dstOff)..table.concat(patch)..data:sub(dstOff+dstLen+1), dstOff, dstOff+dstLen-1

    elseif mode == 11 then
        -- ENDIAN SWAP — swap byte pairs or 4-byte chunks (mismatched endianness; floats go haywire)
        local chunkSize = math.random(0,1) == 0 and 2 or 4
        local dstOff    = math.random(0, math.floor(len/2))
        -- align to chunk boundary
        dstOff = dstOff - (dstOff % chunkSize)
        local dstLen = math.min(math.random(math.floor(len/8), math.floor(len/2)), len-dstOff)
        dstLen = dstLen - (dstLen % chunkSize)
        if dstLen <= 0 then dstLen = chunkSize end
        local region = data:sub(dstOff+1, dstOff+dstLen)
        local out    = {}
        for i=1,#region,chunkSize do
            local chunk = {}
            for j=chunkSize,1,-1 do
                chunk[#chunk+1] = string.char(string.byte(region, i+j-1) or 0)
            end
            out[#out+1] = table.concat(chunk)
        end
        return data:sub(1,dstOff)..table.concat(out)..data:sub(dstOff+dstLen+1), dstOff, dstOff+dstLen-1

    elseif mode == 12 then
        -- QUANTIZATION CRUSH — AND every byte with a bitmask, reducing effective bit depth
        -- e.g. 0xF0 keeps top 4 bits, 0xC0 keeps top 2 bits (posterization effect)
        local shifts = math.random(1, 4)  -- crush 1-4 low bits
        local mask   = bit.band(0xFF, bit.lshift(0xFF, shifts))
        local dstOff = math.random(0, math.floor(len/2))
        local dstLen = math.min(math.random(math.floor(len/4), math.floor(len*3/4)), len-dstOff)
        local region = data:sub(dstOff+1, dstOff+dstLen)
        local out    = {}
        for i=1,#region do out[i]=string.char(bit.band(string.byte(region,i), mask)) end
        return data:sub(1,dstOff)..table.concat(out)..data:sub(dstOff+dstLen+1), dstOff, dstOff+dstLen-1

    elseif mode == 13 then
        -- BLOCK TRANSPOSE — swap two same-size chunks at different offsets (filesystem reorder)
        local blkSize = math.random(16, math.min(256, math.floor(len/4)))
        local offA    = math.random(0, math.floor(len/2)-blkSize)
        local offB    = math.random(offA+blkSize, len-blkSize)
        local blockA  = data:sub(offA+1, offA+blkSize)
        local blockB  = data:sub(offB+1, offB+blkSize)
        -- rebuild with A and B swapped
        local out = data:sub(1,offA) .. blockB
                 .. data:sub(offA+blkSize+1, offB) .. blockA
                 .. data:sub(offB+blkSize+1)
        return out, offA, offB+blkSize-1

    else
        -- OVERFLOW DRIFT — ADD a constant to every byte with wraparound across a region (voltage drift)
        local drift  = math.random(1, 127)
        local dstOff = math.random(0, math.floor(len/2))
        local dstLen = math.min(math.random(math.floor(len/8), math.floor(len/2)), len-dstOff)
        local region = data:sub(dstOff+1, dstOff+dstLen)
        local out    = {}
        for i=1,#region do
            out[i] = string.char(bit.band(string.byte(region,i) + drift, 0xFF))
        end
        return data:sub(1,dstOff)..table.concat(out)..data:sub(dstOff+dstLen+1), dstOff, dstOff+dstLen-1
    end
end
