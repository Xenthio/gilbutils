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
    -- Store raw pixel coords; resolve UVs at draw time once material is loaded
    return {
        file = tbl.file,
        px = tonumber(tbl.x) or 0,
        py = tonumber(tbl.y) or 0,
        srcW = tonumber(tbl.width)  or 64,
        srcH = tonumber(tbl.height) or 64,
    }
end

local function resolveSpriteUVs(spr)
    if spr.mat then return spr end  -- already resolved
    local mat = getMat(spr.file)
    local tw = mat:Width()
    local th = mat:Height()
    if tw == 0 or th == 0 then return nil end  -- not loaded yet, try next frame
    spr.mat = mat
    spr.u0 = spr.px / tw;  spr.v0 = spr.py / th
    spr.u1 = (spr.px + spr.srcW) / tw; spr.v1 = (spr.py + spr.srcH) / th
    return spr
end

-- Hardcoded HL1 weapon sprites (weapon_*_hl1.txt not in GAME search path)
-- All use 170x45 pixel subrects from 640hudN sprite sheets
local HL1_SPRITES = {
    weapon_crowbar_hl1  = { weapon={"sprites/640hud1",0,  0  }, weapon_s={"sprites/640hud4",0,  0  } },
    weapon_glock_hl1    = { weapon={"sprites/640hud1",0,  45 }, weapon_s={"sprites/640hud4",0,  45 } },
    weapon_357_hl1      = { weapon={"sprites/640hud1",0,  90 }, weapon_s={"sprites/640hud4",0,  90 } },
    weapon_mp5_hl1      = { weapon={"sprites/640hud1",0,  135}, weapon_s={"sprites/640hud4",0,  135} },
    weapon_shotgun_hl1  = { weapon={"sprites/640hud1",0,  180}, weapon_s={"sprites/640hud4",0,  180} },
    weapon_crossbow_hl1 = { weapon={"sprites/640hud2",0,  0  }, weapon_s={"sprites/640hud5",0,  0  } },
    weapon_rpg_hl1      = { weapon={"sprites/640hud2",0,  45 }, weapon_s={"sprites/640hud5",0,  45 } },
}
local function makeHL1Entry(t)
    return { file=t[1], px=t[2], py=t[3], srcW=170, srcH=45 }
end
local function registerHL1Sprites()
    for cls, data in pairs(HL1_SPRITES) do
        if not HL2Hud.WeaponSprites[cls] then
            HL2Hud.WeaponSprites[cls] = {
                weapon   = makeHL1Entry(data.weapon),
                weapon_s = makeHL1Entry(data.weapon_s),
            }
        end
    end
end

loadWeaponSprites()
registerHL1Sprites()
    HL2Hud.WeaponSprites = {}
    local files = file.Find("scripts/weapon_*.txt", "GAME")
    for _, fname in ipairs(files) do
        -- fname is just "weapon_mp5_hl1.txt" (no path)
        local cls = fname:match("^(.-)%.txt$")
        local raw = file.Read("scripts/" .. fname, "GAME")
        if raw then
            -- util.KeyValuesToTable: WeaponData{} is flattened to top level,
            -- but TextureData{} sub-block is preserved as tbl.texturedata
            -- weapon{} and weapon_s{} live inside tbl.texturedata
            local ok, tbl = pcall(util.KeyValuesToTable, raw)
            if ok and tbl then
                local td = tbl.texturedata
                local sprNormal   = td and parseSpriteEntry(td.weapon)
                local sprSelected = td and (parseSpriteEntry(td.weapon_s) or sprNormal)
                if sprNormal then
                    HL2Hud.WeaponSprites[cls] = {
                        weapon   = sprNormal,
                        weapon_s = sprSelected,
                    }
                end
            end
        end
    end
    -- dev: print loaded count
    local n = 0
    for _ in pairs(HL2Hud.WeaponSprites) do n = n + 1 end
    MsgN("[HL2Hud] Loaded " .. n .. " weapon sprites")
end

-- Hardcoded HL1 weapon sprites (weapon_*_hl1.txt not in GAME search path)
-- All use 170x45 pixel subrects from 640hudN sprite sheets
local HL1_SPRITES = {
    weapon_crowbar_hl1  = { weapon={"sprites/640hud1",0,  0  }, weapon_s={"sprites/640hud4",0,  0  } },
    weapon_glock_hl1    = { weapon={"sprites/640hud1",0,  45 }, weapon_s={"sprites/640hud4",0,  45 } },
    weapon_357_hl1      = { weapon={"sprites/640hud1",0,  90 }, weapon_s={"sprites/640hud4",0,  90 } },
    weapon_mp5_hl1      = { weapon={"sprites/640hud1",0,  135}, weapon_s={"sprites/640hud4",0,  135} },
    weapon_shotgun_hl1  = { weapon={"sprites/640hud1",0,  180}, weapon_s={"sprites/640hud4",0,  180} },
    weapon_crossbow_hl1 = { weapon={"sprites/640hud2",0,  0  }, weapon_s={"sprites/640hud5",0,  0  } },
    weapon_rpg_hl1      = { weapon={"sprites/640hud2",0,  45 }, weapon_s={"sprites/640hud5",0,  45 } },
}
local function makeHL1Entry(t)
    return { file=t[1], px=t[2], py=t[3], srcW=170, srcH=45 }
end
local function registerHL1Sprites()
    for cls, data in pairs(HL1_SPRITES) do
        if not HL2Hud.WeaponSprites[cls] then
            HL2Hud.WeaponSprites[cls] = {
                weapon   = makeHL1Entry(data.weapon),
                weapon_s = makeHL1Entry(data.weapon_s),
            }
        end
    end
end

loadWeaponSprites()
registerHL1Sprites()

-- Draw a weapon sprite icon centred in the given box.
-- bSelected: use weapon_s sprite and apply glow alpha.
-- fgAlpha: 0-255 master alpha from animation system.
-- glowAlpha: 0-1 glow multiplier (animSelAlpha.cur/7) for selected pass.
function HL2Hud.DrawWeaponSprite(cls, bSelected, x, y, boxWide, boxTall, fgAlpha, glowAlpha)
    local sprites = HL2Hud.WeaponSprites[cls]
    if not sprites then return false end

    local spr = resolveSpriteUVs((bSelected and sprites.weapon_s) or sprites.weapon)
    if not spr then return false end  -- material not loaded yet

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
        local sprS = resolveSpriteUVs(sprites.weapon_s or sprites.weapon)
        if sprS then
            surface.SetDrawColor(col.r, col.g, col.b, math.Round(fgAlpha * glowAlpha))
            surface.SetMaterial(sprS.mat)
            surface.DrawTexturedRectUV(dx, dy, dw, dh, sprS.u0, sprS.v0, sprS.u1, sprS.v1)
        end
    end

    return true
end
