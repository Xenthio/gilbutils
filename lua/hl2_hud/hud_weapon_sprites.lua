-- hud_weapon_sprites.lua
-- Parses garrysmod/scripts/weapon_*.txt TextureData blocks at load time.
-- Builds HL2Hud.WeaponSprites[classname] = { weapon = {mat,u0,v0,u1,v1}, weapon_s = {...} }
-- Used by hud_weapon_selection.lua as a sprite-based icon fallback for weapons
-- that have TextureData but no HalfLife2 font icon character.

HL2Hud.WeaponSprites = HL2Hud.WeaponSprites or {}

local matCache = {}
local function getMat(path)
    if not matCache[path] then
        matCache[path] = Material(path, "noclamp smooth")
    end
    return matCache[path]
end

local function parseSpriteEntry(tbl)
    if not tbl or not tbl.file then return nil end
    local mat  = getMat(tbl.file)
    local tw   = mat:GetInt("$realTextureWidth")  or mat:Width()
    local th   = mat:GetInt("$realTextureHeight") or mat:Height()
    if tw == 0 or th == 0 then tw = 512; th = 256 end  -- sane fallback
    local x, y, w, h = tonumber(tbl.x) or 0, tonumber(tbl.y) or 0,
                        tonumber(tbl.width) or 64, tonumber(tbl.height) or 64
    return {
        mat = mat,
        u0 = x / tw,  v0 = y / th,
        u1 = (x + w) / tw, v1 = (y + h) / th,
        srcW = w, srcH = h,
    }
end

local function loadWeaponSprites()
    HL2Hud.WeaponSprites = {}
    local files = file.Find("scripts/weapon_*.txt", "GAME")
    for _, fname in ipairs(files) do
        local cls = fname:match("^(.-)%.txt$")  -- strip extension
        local raw = file.Read("scripts/" .. fname, "GAME")
        if raw then
            local ok, tbl = pcall(util.KeyValuesToTable, raw)
            if ok and tbl and tbl.WeaponData and tbl.WeaponData.TextureData then
                local td = tbl.WeaponData.TextureData
                local sprNormal   = parseSpriteEntry(td.weapon)
                local sprSelected = parseSpriteEntry(td.weapon_s) or sprNormal
                if sprNormal then
                    HL2Hud.WeaponSprites[cls] = {
                        weapon   = sprNormal,
                        weapon_s = sprSelected,
                    }
                end
            end
        end
    end
end

loadWeaponSprites()

-- Draw a weapon sprite icon centred in the given box.
-- bSelected: use weapon_s sprite and apply glow alpha.
-- fgAlpha: 0-255 master alpha from animation system.
-- glowAlpha: 0-1 glow multiplier (animSelAlpha.cur/7) for selected pass.
function HL2Hud.DrawWeaponSprite(cls, bSelected, x, y, boxWide, boxTall, fgAlpha, glowAlpha)
    local sprites = HL2Hud.WeaponSprites[cls]
    if not sprites then return false end

    local spr = (bSelected and sprites.weapon_s) or sprites.weapon
    if not spr then return false end

    -- Scale sprite to fit box while preserving aspect
    local scale = math.min(boxWide / spr.srcW, boxTall / spr.srcH)
    local dw = math.Round(spr.srcW * scale)
    local dh = math.Round(spr.srcH * scale)
    local dx = x + math.floor((boxWide - dw) / 2)
    local dy = y + math.floor((boxTall - dh) / 2)

    local col = HL2Hud.Colors.FgColor
    surface.SetDrawColor(col.r, col.g, col.b, fgAlpha)
    surface.SetMaterial(spr.mat)
    surface.DrawTexturedRectUV(dx, dy, dw, dh, spr.u0, spr.v0, spr.u1, spr.v1)

    -- Selected glow pass: draw weapon_s sprite on top at glow alpha
    if bSelected and glowAlpha and glowAlpha > 0 then
        local sprS = sprites.weapon_s or sprites.weapon
        surface.SetDrawColor(col.r, col.g, col.b, math.Round(fgAlpha * glowAlpha))
        surface.SetMaterial(sprS.mat)
        surface.DrawTexturedRectUV(dx, dy, dw, dh, sprS.u0, sprS.v0, sprS.u1, sprS.v1)
    end

    return true
end
