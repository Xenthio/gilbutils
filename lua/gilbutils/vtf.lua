-- gilbutils/vtf.lua
-- VTF parsing + DXT1/DXT5 software decode + RAM-like corruption patterns.
-- CLIENT only. Include via: include("gilbutils/vtf.lua")

GilbVTF = GilbVTF or {}

------------------------------------------------------------------------
-- VTF parsing
------------------------------------------------------------------------

-- Parse VTF header + extract largest mip raw bytes.
-- Returns: { mipData, width, height, isDXT5, fmt, vtf } or nil if unsupported.
function GilbVTF.Parse(vtf)
    if #vtf < 64 or vtf:sub(1,3) ~= "VTF" then return nil end
    local function ru32(i)
        local a,b,c,d = string.byte(vtf,i,i+3)
        return a + b*256 + c*65536 + d*16777216
    end
    local fmt    = ru32(53)
    local width  = string.byte(vtf,17) + string.byte(vtf,18)*256
    local height = string.byte(vtf,19) + string.byte(vtf,20)*256
    -- DXT1=13, DXT1_oneBitAlpha=14, DXT5=15
    if fmt ~= 13 and fmt ~= 14 and fmt ~= 15 then return nil end
    local isDXT5  = (fmt == 15)
    local bs      = isDXT5 and 16 or 8
    local bw      = math.max(1, math.ceil(width  / 4))
    local bh      = math.max(1, math.ceil(height / 4))
    local mipSize = bw * bh * bs
    local mipData = vtf:sub(#vtf - mipSize + 1)
    return { mipData=mipData, width=width, height=height, isDXT5=isDXT5, fmt=fmt, vtf=vtf }
end

------------------------------------------------------------------------
-- DXT decode
------------------------------------------------------------------------

local function rgb565(lo, hi)
    local v = lo + hi*256
    return math.floor(v/2048)*8, math.floor((v%2048)/32)*4, (v%32)*8
end

local function decodeBlock(s, isDXT5)

    local c = isDXT5 and 9 or 1
    local r0,g0,b0 = rgb565(string.byte(s,c),   string.byte(s,c+1))
    local r1,g1,b1 = rgb565(string.byte(s,c+2), string.byte(s,c+3))
    local c0w = r0*2048 + math.floor(g0/4)*32 + math.floor(b0/8)
    local c1w = r1*2048 + math.floor(g1/4)*32 + math.floor(b1/8)
    local pal = {{r0,g0,b0},{r1,g1,b1}}
    if c0w > c1w then
        pal[3]={math.floor((2*r0+r1)/3),math.floor((2*g0+g1)/3),math.floor((2*b0+b1)/3)}
        pal[4]={math.floor((r0+2*r1)/3),math.floor((g0+2*g1)/3),math.floor((b0+2*b1)/3)}
    else
        pal[3]={math.floor((r0+r1)/2),math.floor((g0+g1)/2),math.floor((b0+b1)/2)}
        pal[4]={0,0,0}
    end
    local io = isDXT5 and 13 or 5
    local px = {}
    for row=0,3 do
        local b = string.byte(s, io+row)
        for col=0,3 do px[row*4+col+1] = pal[math.floor(b/(4^col))%4+1] end
    end
    return px
end

-- Public alias so examples can call GilbVTF.DecodeBlock directly
GilbVTF.DecodeBlock = decodeBlock

-- Decode raw DXT mip data → flat pixel table [1..w*h] = {r,g,b}
function GilbVTF.DecodeMip(data, mw, mh, isDXT5)
    local bs = isDXT5 and 16 or 8
    local bw = math.max(1, math.ceil(mw/4))
    local bh = math.max(1, math.ceil(mh/4))
    local pixels = {}
    for by=0,bh-1 do
        for bx=0,bw-1 do
            local off = (by*bw+bx)*bs
            local blk = data:sub(off+1, off+bs)
            if #blk < bs then blk = blk..string.rep("\0", bs-#blk) end
            local bp = decodeBlock(blk, isDXT5)
            for py=0,3 do for px=0,3 do
                local sx,sy = bx*4+px, by*4+py
                if sx < mw and sy < mh then pixels[sy*mw+sx+1] = bp[py*4+px+1] end
            end end
        end
    end
    return pixels
end

------------------------------------------------------------------------
-- RAM-like corruption patterns
------------------------------------------------------------------------

-- Apply one random RAM failure mode to a byte string.
-- allData (optional): larger pool to borrow bytes from (data bleed mode).
-- Returns new (corrupted) string.
function GilbVTF.RamCorrupt(data, allData, mode)
    local len = #data
    if len == 0 then return data end
    local mode = mode or math.random(1, 6)

    if mode == 1 then
        -- STRIDE REPEAT: stuck address line replays the same memory row
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
        return data:sub(1,dstOff)..table.concat(patch)..data:sub(dstOff+dstLen+1)

    elseif mode == 2 then
        -- BIT FLIP REGION: stuck bit line flips same bit across a whole section
        local mask   = math.random(1, 255)
        local dstOff = math.random(0, math.floor(len/2))
        local dstLen = math.min(math.random(math.floor(len/8), math.floor(len/2)), len-dstOff)
        local region = data:sub(dstOff+1, dstOff+dstLen)
        local out    = {}
        for i=1,#region do out[i]=string.char(bit.bxor(string.byte(region,i), mask)) end
        return data:sub(1,dstOff)..table.concat(out)..data:sub(dstOff+dstLen+1)

    elseif mode == 3 then
        -- DATA BLEED: wrong pointer reads adjacent allocation
        local pool   = allData or data
        local srcLen = math.random(math.floor(len/4), math.floor(len/2))
        local srcOff = math.random(0, math.max(0, #pool-srcLen))
        local bleed  = pool:sub(srcOff+1, srcOff+srcLen)
        local dstOff = math.random(0, len-1)
        local avail  = len-dstOff
        return data:sub(1,dstOff)..bleed:sub(1,avail)..data:sub(dstOff+math.min(srcLen,avail)+1)

    elseif mode == 4 then
        -- XOR PATTERN: bus noise / electrical interference
        local patLen = math.random(2, 8)
        local pat    = {}; for i=1,patLen do pat[i]=math.random(0,255) end
        local dstOff = math.random(0, math.floor(len/2))
        local dstLen = math.min(math.random(math.floor(len/4), math.floor(len*3/4)), len-dstOff)
        local region = data:sub(dstOff+1, dstOff+dstLen)
        local out    = {}
        for i=1,#region do
            out[i]=string.char(bit.bxor(string.byte(region,i), pat[(i-1)%patLen+1]))
        end
        return data:sub(1,dstOff)..table.concat(out)..data:sub(dstOff+dstLen+1)

    elseif mode == 5 then
        -- ZERO WIPE: DMA underrun / cleared allocation
        local dstOff = math.random(0, math.floor(len*2/3))
        local dstLen = math.min(math.random(math.floor(len/16), math.floor(len/6)), len-dstOff)
        return data:sub(1,dstOff)..string.rep("\0",dstLen)..data:sub(dstOff+dstLen+1)

    else
        -- RANDOM SPRINKLE: scattered random bytes across the region
        -- Simulates general DRAM cell decay / retention failure
        local count  = math.random(math.floor(len/32), math.floor(len/4))
        -- Build sorted list of positions to patch
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
        return table.concat(out)
    end
end
