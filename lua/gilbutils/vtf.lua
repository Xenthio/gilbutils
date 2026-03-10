-- gilbutils/vtf.lua
-- VTF parsing + DXT1/DXT5 software decode + RAM-like corruption patterns.
-- CLIENT only. Include via: include("gilbutils/vtf.lua")
-- Depends on: gilbutils/data.lua (GilbData.Corrupt)

include("gilbutils/data.lua")
GilbVTF = GilbVTF or {}

------------------------------------------------------------------------
-- VTF parsing
------------------------------------------------------------------------

-- Parse VTF header + extract largest mip raw bytes.
-- Supported formats:
--   DXT1=13, DXT1_oneBitAlpha=14, DXT5=15 (block compressed)
--   RGBA16161616F=12, RGBA8888=0, ABGR8888=1, BGR888=3,
--   RGB888=2, BGRA8888=12... (raw uncompressed — treated as raw blob)
-- Returns: { mipData, allMipData, headerSize, mipCount, width, height, isDXT5, isRaw, bytesPerPixel, fmt, vtf }
-- or nil if format is unrecognised/unsupported.
function GilbVTF.Parse(vtf)
    if #vtf < 64 or vtf:sub(1,3) ~= "VTF" then return nil end
    local function ru32(i)
        local a,b,c,d = string.byte(vtf,i,i+3)
        return a + b*256 + c*65536 + d*16777216
    end
    local fmt        = ru32(53)
    local mipCount   = string.byte(vtf, 57)
    local width      = string.byte(vtf,17) + string.byte(vtf,18)*256
    local height     = string.byte(vtf,19) + string.byte(vtf,20)*256
    local headerSize = ru32(13)

    -- Block-compressed formats
    local isDXT5 = (fmt == 15)
    if fmt == 13 or fmt == 14 or fmt == 15 then
        local bs      = isDXT5 and 16 or 8
        local bw      = math.max(1, math.ceil(width  / 4))
        local bh      = math.max(1, math.ceil(height / 4))
        local mipSize = bw * bh * bs
        local allMipData = vtf:sub(headerSize + 1)
        local mipData    = vtf:sub(#vtf - mipSize + 1)
        return { mipData=mipData, allMipData=allMipData, headerSize=headerSize, mipCount=mipCount,
                 width=width, height=height, isDXT5=isDXT5, isRaw=false, fmt=fmt, vtf=vtf }
    end

    -- Raw/uncompressed formats — bytes per pixel:
    --   0=RGBA8888(4), 1=ABGR8888(4), 2=RGB888(3), 3=BGR888(3),
    --   12=RGBA16161616F(8), 16=BGRA8888(4), 17=BGRX8888(4)
    local rawBpp = ({
        [0]=4,[1]=4,[2]=3,[3]=3,[4]=3,[5]=4,
        [12]=8,[16]=4,[17]=4,[24]=2,[25]=2,
    })[fmt]
    if rawBpp then
        local mipSize    = width * height * rawBpp
        local allMipData = vtf:sub(headerSize + 1)
        local mipData    = vtf:sub(#vtf - mipSize + 1)
        return { mipData=mipData, allMipData=allMipData, headerSize=headerSize, mipCount=mipCount,
                 width=width, height=height, isDXT5=false, isRaw=true, bytesPerPixel=rawBpp, fmt=fmt, vtf=vtf }
    end

    return nil  -- unsupported format
end

-- Rebuild a VTF with replaced pixel data (all mips).
function GilbVTF.Rebuild(info, newAllMipData)
    return info.vtf:sub(1, info.headerSize) .. newAllMipData
end

-- Returns array of {offset, size} for each mip in allMipData (index 1 = smallest mip)
function GilbVTF.MipOffsets(info)
    local mipCount = info.mipCount or 1
    local offsets  = {}
    local pos      = 1
    -- Mips stored smallest→largest
    for i = mipCount - 1, 0, -1 do
        local mw   = math.max(1, math.floor(info.width  / (2^i)))
        local mh   = math.max(1, math.floor(info.height / (2^i)))
        local size
        if info.isRaw then
            size = mw * mh * (info.bytesPerPixel or 4)
        else
            local bs = info.isDXT5 and 16 or 8
            size = math.max(1, math.ceil(mw/4)) * math.max(1, math.ceil(mh/4)) * bs
        end
        table.insert(offsets, { offset=pos, size=size })
        pos = pos + size
    end
    return offsets
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
-- Returns: newData, startByte, endByte (0-indexed byte range that changed)
-- Delegates to GilbData.Corrupt() in gilbutils/data.lua — all modes live there.
function GilbVTF.RamCorrupt(data, allData, mode)
    return GilbData.Corrupt(data, allData, mode)
end
