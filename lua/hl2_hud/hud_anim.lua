-- hud_anim.lua — Animation state helpers, porting vgui AnimationController
-- Supports chained animations on the same property (queue by absolute startT).
-- HL2Hud.Anim.make(val)                        → anim state
-- HL2Hud.Anim.set(anim, tgt, interp, delay, dur) → schedule/queue a segment
-- HL2Hud.Anim.step(anim)                       → advance and return current value
-- HL2Hud.Anim.snap(anim, val)                  → immediately set cur+tgt, clear queue

HL2Hud.Anim = {}

local function lerpColor(a, b, t)
    return Color(Lerp(t,a.r,b.r), Lerp(t,a.g,b.g), Lerp(t,a.b,b.b), Lerp(t,a.a,b.a))
end

local function lerp(a, b, t)
    if type(a) == "number" then return a + (b-a)*t end
    return lerpColor(a, b, t)
end

local function ease(t, interp)
    if interp == "Deaccel" then return 1-(1-t)^2
    elseif interp == "Accel" then return t*t end
    return t  -- Linear
end

-- Create a new animated value. val = Color or number.
function HL2Hud.Anim.make(val)
    return {
        cur    = val,   -- current live value (read this for rendering)
        _queue = {},    -- list of { from, tgt, interp, startT, endT, fromCaptured }
    }
end

-- Snap immediately, clearing any in-progress or queued animations.
function HL2Hud.Anim.snap(anim, val)
    anim.cur    = val
    anim._queue = {}
end

-- Schedule an animation segment. delay and dur are in seconds from NOW.
-- Multiple calls with increasing delays chain correctly.
function HL2Hud.Anim.set(anim, tgt, interp, delay, dur)
    local now    = CurTime()
    local startT = now + (delay or 0)
    local endT   = startT + (dur or 0)

    -- Remove any queued segments that start at or after this one's startT
    -- (later set() calls in the same event always supersede earlier ones for
    --  the same time window — matches source AnimationController behaviour)
    local q = anim._queue
    for i = #q, 1, -1 do
        if q[i].startT >= startT then
            table.remove(q, i)
        end
    end

    table.insert(q, {
        tgt           = tgt,
        interp        = interp or "Linear",
        startT        = startT,
        endT          = endT,
        fromCaptured  = false,
        from          = nil,
    })

    -- Keep sorted by startT
    table.sort(q, function(a,b) return a.startT < b.startT end)
end

-- Advance animation state. Call once per Draw(). Returns current value.
function HL2Hud.Anim.step(anim)
    local now = CurTime()
    local q   = anim._queue
    if #q == 0 then return anim.cur end

    -- Find the active segment: last one whose startT <= now
    local active = nil
    local activeIdx = nil
    for i = 1, #q do
        if q[i].startT <= now then
            active    = q[i]
            activeIdx = i
        else
            break
        end
    end

    if not active then return anim.cur end  -- all segments still in the future

    -- Capture 'from' the first time we enter this segment
    if not active.fromCaptured then
        active.from          = anim.cur
        active.fromCaptured  = true
    end

    -- Prune completed segments before the active one
    for i = activeIdx-1, 1, -1 do
        table.remove(q, 1)
        activeIdx = activeIdx - 1
    end

    -- Compute interpolated value
    local seg = q[1]  -- active is now q[1]
    if now >= seg.endT then
        -- Segment complete: snap to target, remove from queue
        anim.cur = seg.tgt
        table.remove(q, 1)
    else
        local t = (now - seg.startT) / (seg.endT - seg.startT)
        anim.cur = lerp(seg.from, seg.tgt, ease(t, seg.interp))
    end

    return anim.cur
end
