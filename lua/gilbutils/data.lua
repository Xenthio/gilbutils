-- gilbutils/data.lua
-- Generic binary data corruption utilities.
-- Works on any Lua string (byte blob) — VTF, MDL, VVD, WAV, whatever.
-- Include via: include("gilbutils/data.lua")

GilbData = GilbData or {}

-- GilbData.Corrupt(data, allData, mode) — corrupt a byte string in-place (returns new string).
--
-- data    : the byte string to corrupt (e.g. a mip slice, a VVD vertex block)
-- allData : optional wider pool to bleed bytes from (e.g. full VTF for mode 3)
-- mode    : 1-6, or nil for random
--
-- Modes:
--   1 = STRIDE REPEAT  — pick a random stride-width row, tile it over a region
--   2 = BIT FLIP       — XOR a region with a random single-byte mask
--   3 = DATA BLEED     — copy a random chunk from allData (or data) into a region
--   4 = XOR PATTERN    — XOR a region with a short repeating byte pattern
--   5 = ZERO WIPE      — zero out a region
--   6 = RANDOM SPRINKLE — scatter random bytes at random positions
--
-- Returns: corrupted string, startOffset, endOffset (0-indexed byte range that was modified)
function GilbData.Corrupt(data, allData, mode)
    local len = #data
    if len == 0 then return data, 0, 0 end
    mode = mode or math.random(1, 6)

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

    else
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
    end
end
