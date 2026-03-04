-- hud_quickinfo.lua — Port of CHUDQuickInfo (hl2/hud_quickinfo.cpp)
-- Draws health/ammo arc brackets around the crosshair.
-- Textures are font glyphs from the native "QuickInfo" font (HL2cross, 28px, additive).
--   left bracket normal:   "("    crosshair_left
--   right bracket normal:  ")"    crosshair_right
--   left bracket full:     "["    crosshair_left_full
--   right bracket full:    "]"    crosshair_right_full
--   left bracket empty:    "{"    crosshair_left_empty
--   right bracket empty:   "}"    crosshair_right_empty
-- DrawIconProgressBar HUDPB_VERTICAL: fill from bottom, 0=full (perc = amount empty).
-- Health warn threshold: <= 25 HP
-- Ammo warn threshold:   clip <= 25% of max (CLIP_PERC_THRESHOLD 0.75 → ammoPerc <= 0.25)
-- Alpha: full=255, dim=64. Fade in=0.5s, fade out=2.0s. Dim after 1.0s idle.

local A = HL2Hud.Anim

local HEALTH_WARN  = 25
local AMMO_WARN    = 0.25   -- fraction of max clip (source: 1 - CLIP_PERC_THRESHOLD)
local EVENT_DUR    = 1.0
local ALPHA_FULL   = 255
local ALPHA_DIM    = 64
local FADE_IN      = 0.5
local FADE_OUT     = 2.0
local SCALAR       = 138 / 255   -- normal draw alpha multiplier

local state = {
    alpha       = A.make(ALPHA_FULL),
    warnHealth  = false,
    warnAmmo    = false,
    healthFade  = 0,    -- blink countdown (like source's m_healthFade / frametime*200)
    ammoFade    = 0,
    lastHealth  = 100,
    lastAmmo    = -1,
    lastEventT  = 0,
    dimmed      = false,
    fadedOut    = false,
}

local function eventUpdate()
    state.lastEventT = CurTime()
end

local function eventElapsed()
    return (CurTime() - state.lastEventT) > EVENT_DUR
end

-- DrawIconProgressBar HUDPB_VERTICAL: draws `full` glyph clipped, then `empty` for the rest.
-- perc = fraction that is EMPTY (0 = show full bracket, 1 = show empty bracket).
-- We approximate by drawing the full glyph with a clipping rect (scissor) and the empty glyph underneath.
local function drawProgressBracket(x, y, charFull, charEmpty, perc, col, font, glyphW, glyphH)
    -- draw empty glyph as base
    surface.SetFont(font)
    surface.SetTextColor(col.r, col.g, col.b, col.a)
    surface.SetTextPos(x, y)
    surface.DrawText(charEmpty)

    -- draw full glyph clipped from top by perc (vertical fill from bottom = HL2 HUDPB_VERTICAL)
    local fillH = math.Round(glyphH * (1 - perc))
    if fillH > 0 then
        local clipY = y + (glyphH - fillH)
        render.SetScissorRect(x, clipY, x + glyphW, y + glyphH, true)
        surface.SetTextPos(x, y)
        surface.SetTextColor(col.r, col.g, col.b, col.a)
        surface.DrawText(charFull)
        render.SetScissorRect(0, 0, 0, 0, false)
    end
end

-- DrawWarning: source caution[3] = int(abs(sin(t*8))*128) * 255 → byte overflow = strobe
local function drawWarning(x, y, charFull, fadeRef, col, font, masterAlpha)
    local scale     = math.floor(math.abs(math.sin(CurTime() * 8)) * 128)
    local warnA     = (scale * 255) % 256
    local a         = math.Round(warnA * masterAlpha / 255)
    surface.SetFont(font)
    surface.SetTextColor(col.r, col.g, col.b, a)
    surface.SetTextPos(x, y)
    surface.DrawText(charFull)
end

hook.Add("HUDPaint", "HL2Hud_QuickInfo", function()
    if not HL2Hud.enabled then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local wep = ply:GetActiveWeapon()

    -- Zoom fade
    local zoomed = ply:GetFOV() < 70
    if zoomed ~= state.fadedOut then
        state.fadedOut = zoomed
        state.dimmed   = false
        if zoomed then
            A.set(state.alpha, 0,          "Linear", 0, 0.25)
        else
            A.set(state.alpha, ALPHA_FULL, "Linear", 0, FADE_IN)
        end
    elseif not state.fadedOut then
        if eventElapsed() then
            if not state.dimmed then
                state.dimmed = true
                A.set(state.alpha, ALPHA_DIM, "Linear", 0, FADE_OUT)
            end
        elseif state.dimmed then
            state.dimmed = false
            A.set(state.alpha, ALPHA_FULL, "Linear", 0, FADE_IN)
        end
    end
    A.step(state.alpha)
    local masterAlpha = math.Round(state.alpha.cur)
    if masterAlpha <= 0 then return end

    -- Health change detection
    local hp = ply:Health()
    if hp ~= state.lastHealth then
        eventUpdate()
        state.lastHealth = hp
        if hp <= HEALTH_WARN and hp > 0 then
            if not state.warnHealth then
                state.warnHealth = true
                state.healthFade = 255
                surface.PlaySound("HUDQuickInfo.LowHealth")
            end
        else
            state.warnHealth = false
        end
    end

    -- Ammo change detection
    local clip, maxClip = -1, 0
    if IsValid(wep) then
        clip    = wep:Clip1()
        maxClip = wep:GetMaxClip1()
    end
    if clip ~= state.lastAmmo then
        eventUpdate()
        state.lastAmmo = clip
        if maxClip > 1 then
            local ammoPerc = clip / maxClip
            if ammoPerc <= AMMO_WARN then
                if not state.warnAmmo then
                    state.warnAmmo = true
                    state.ammoFade = 255
                    surface.PlaySound("HUDQuickInfo.LowAmmo")
                end
            else
                state.warnAmmo = false
            end
        end
    end

    -- Tick blink fades (source: time -= frametime * 200)
    local dt = FrameTime()
    state.healthFade = math.max(0, state.healthFade - dt * 200)
    state.ammoFade   = math.max(0, state.ammoFade   - dt * 200)

    -- Crosshair position
    local cx = ScrW() / 2
    local cy = ScrH() / 2

    local font = "HL2Hud_QuickInfo"

    -- Measure glyph size using the full bracket char
    surface.SetFont(font)
    local gW, gH = surface.GetTextSize("]")
    -- source: yCenter = crosshair_y - icon_lb->Height()/2
    local lx = cx - gW * 2
    local rx = cx + gW
    local gy = cy - gH / 2

    local function mc(r, g, b, a)
        return Color(r, g, b, math.Round(a * masterAlpha / 255))
    end

    local clrNormal  = mc(255, 208, 64, 255 * SCALAR)   -- ClientScheme "Normal"
    local clrCaution = Color(255, 48, 0, 255)            -- ClientScheme "Caution"

    local sinScale = math.abs(math.sin(CurTime() * 8)) * 128  -- 0..128 (int in source)
    -- Source: healthColor[3] = 255 * sinScale where sinScale is 0..128 int → byte overflow
    -- Result: alpha = (255 * sinScale) % 256 → strobes near-full with brief dark dips
    local warnAlpha = (255 * math.floor(sinScale)) % 256

    -- === LEFT (health) ===
    if state.healthFade > 0 then
        drawWarning(lx, gy, "[", state.healthFade, clrCaution, font, masterAlpha)
    else
        local healthPerc = math.Clamp(hp / 100, 0, 1)
        local col
        if state.warnHealth then
            col = mc(clrCaution.r, clrCaution.g, clrCaution.b, warnAlpha)
        else
            col = clrNormal
        end
        drawProgressBracket(lx, gy, "[", "{", 1 - healthPerc, col, font, gW, gH)
    end

    -- === RIGHT (ammo) ===
    if state.ammoFade > 0 then
        drawWarning(rx, gy, "]", state.ammoFade, clrCaution, font, masterAlpha)
    else
        local ammoPerc = 0
        if IsValid(wep) and maxClip > 0 then
            ammoPerc = math.Clamp(clip / maxClip, 0, 1)
        end
        local col
        if state.warnAmmo then
            col = mc(clrCaution.r, clrCaution.g, clrCaution.b, warnAlpha)
        else
            col = clrNormal
        end
        -- ammoPerc here is fraction USED (empty), source: perc = 1 - (clip/maxClip)
        drawProgressBracket(rx, gy, "]", "}", 1 - ammoPerc, col, font, gW, gH)
    end
end)

hook.Add("HUDShouldDraw", "HL2Hud_QuickInfo_Hide", function(name)
    if name == "CHUDQuickInfo" and HL2Hud.enabled then return false end
end)
