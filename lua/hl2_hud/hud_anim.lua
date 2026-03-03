-- hud_anim.lua — Animation state helpers, porting vgui AnimationController
-- Used by all HL2 HUD elements.
-- HL2Hud.Anim.make / set / step

HL2Hud.Anim = {}

local function lerpColor(a,b,t)
    return Color(Lerp(t,a.r,b.r), Lerp(t,a.g,b.g), Lerp(t,a.b,b.b), Lerp(t,a.a,b.a))
end

function HL2Hud.Anim.make(val)
    return { cur=val, tgt=val, startT=0, endT=0, interp="Linear" }
end

-- interp: "Linear" | "Deaccel" | "Accel"
-- delay+dur in seconds
function HL2Hud.Anim.set(anim, tgt, interp, delay, dur)
    anim.tgt    = tgt
    anim.startT = CurTime() + (delay or 0)
    anim.endT   = CurTime() + (delay or 0) + (dur or 0)
    anim.interp = interp or "Linear"
end

function HL2Hud.Anim.step(anim)
    local now = CurTime()
    if now < anim.startT then return anim.cur end
    if now >= anim.endT  then anim.cur = anim.tgt return anim.cur end
    local t = (now - anim.startT) / (anim.endT - anim.startT)
    if     anim.interp == "Deaccel" then t = 1-(1-t)^2
    elseif anim.interp == "Accel"   then t = t*t end
    if type(anim.tgt) == "number" then
        anim.cur = Lerp(t, anim.cur, anim.tgt)
    else
        anim.cur = lerpColor(anim.cur, anim.tgt, t)
    end
    return anim.cur
end
