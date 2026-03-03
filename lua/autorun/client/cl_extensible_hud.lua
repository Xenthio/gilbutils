if SERVER then return end

-- ============================================================================
-- ExtensibleHUD Framework
-- A lightweight layout manager for HL2-style HUD elements.
--
-- SLOTS:
--   Left HStack  (bottom-left, growing left→right, above native health/suit)
--   Right HStack (bottom-right, growing right→left, above native ammo)
--   Center VStack (bottom-center)
--   TopLeft VStack (top-left, growing downward)
--   TopRight VStack (top-right, growing downward)
--
-- USAGE — register from any client autorun file:
--
--   -- Reserve a left column (e.g. for a ping display):
--   EHUD.RegisterLeftColumn("ping", 102, nil, 30)
--   EHUD.GetColumn("ping").base_element = myElement
--
--   -- Stack something above a column (e.g. sprint meter above health):
--   EHUD.AddToColumn("health", "sprint_meter", myElement, 10)
--
--   -- Add to a named zone:
--   EHUD.AddToZone("center", "stamina_bar", myElement, 10)
--   EHUD.AddToZone("topleft", "server_info", myElement, 10)
--   EHUD.AddToZone("topright", "ping_graph", myElement, 10)
--
-- ELEMENT INTERFACE:
--   element:GetSize() -> width, height   (called every frame for animation)
--   element:Draw(x, y, clip_h)           (clip_h is the scissored draw height)
-- ============================================================================

EHUD = EHUD or {}
EHUD.VERSION = 2

-- ---- Style constants (all in unscaled units, multiply by EHUD.Scale()) ----
EHUD.MARGIN       = 16
EHUD.COL_GAP      = 22
EHUD.STACK_GAP    = 6
EHUD.CORNER       = 8
EHUD.ANIM_TIME    = 0.4   -- seconds to slide in/out

-- ---- Colors ----------------------------------------------------------------
EHUD.COL = {
    Yellow      = Color(255, 220, 0, 255),
    Red         = Color(255, 0,   0, 255),
    GlowYellow  = Color(255, 220, 0, 128),
    GlowRed     = Color(255, 0,   0, 128),
    Bg          = Color(0,   0,   0, 72),
    BgDark      = Color(0,   0,   0, 76),
    PulseBg     = Color(100, 0,   0, 80),
    PulseText   = Color(255, 80,  0, 255),
    DisabledHi  = Color(255, 220, 0, 70),
    DisabledLo  = Color(255, 0,   0, 70),
}

-- ---- Font setup ------------------------------------------------------------
function EHUD.Scale() return ScrH() / 480 end

function EHUD.UpdateFonts()
    local s = EHUD.Scale()
    surface.CreateFont("EHUD_Num",      { font="Halflife2", size=math.Round(32*s), antialias=true, additive=true })
    surface.CreateFont("EHUD_NumGlow",  { font="Halflife2", size=math.Round(32*s), blursize=math.Round(4*s), scanlines=math.Round(2*s), antialias=true, additive=true })
    surface.CreateFont("EHUD_NumSmall", { font="Halflife2", size=math.Round(16*s), weight=1000, antialias=true, additive=true })
    surface.CreateFont("EHUD_Text",     { font="Verdana",   size=math.Round(8*s),  weight=900,  antialias=true, additive=true })
    surface.CreateFont("EHUD_Small",    { font="Verdana",   size=math.Round(6*s),  weight=700,  antialias=true, additive=true })
end
hook.Add("OnScreenSizeChanged", "EHUD_Fonts", EHUD.UpdateFonts)
EHUD.UpdateFonts()

-- ============================================================================
-- INTERPOLATION HELPERS
-- ============================================================================
function EHUD.Lerp01(t)   return t end
function EHUD.EaseIn(t)   return t * t end
function EHUD.EaseOut(t)  return 1 - (1 - t) * (1 - t) end

-- ============================================================================
-- INTERNAL STRUCTURES
-- ============================================================================

-- Each "column" in a HStack:
-- { id, width_base, check_visible(), priority, base_element,
--   vstack = [{id, obj, priority, anim={cur,tgt,spd}}],
--   vstack_map = {id -> item},
--   anim_aux = {cur, tgt, spd}  -- for native aux space reservation
-- }

EHUD._left     = {}   -- left HStack columns
EHUD._leftMap  = {}
EHUD._right    = {}   -- right HStack columns
EHUD._rightMap = {}

-- Named zones: center / topleft / topright
-- Each zone is a list of {id, obj, priority, anim}
EHUD._zones = {
    center   = { list = {}, map = {} },
    topleft  = { list = {}, map = {} },
    topright = { list = {}, map = {} },
}

-- ============================================================================
-- REGISTRATION API
-- ============================================================================

local function makeAnim() return { cur = 0, tgt = 0, spd = 0 } end

local function makeColumn(id, width_base, check_visible, priority)
    return {
        id            = id,
        width_base    = width_base,
        check_visible = check_visible or function() return true end,
        priority      = priority or 100,
        base_element  = nil,
        vstack        = {},
        vstack_map    = {},
        anim_aux      = makeAnim(),
        anim_width    = makeAnim(),
    }
end

local function insertSorted(t, item)
    table.insert(t, item)
    table.sort(t, function(a,b) return a.priority < b.priority end)
end

function EHUD.RegisterLeftColumn(id, width_base, check_visible, priority)
    if EHUD._leftMap[id] then return end
    local col = makeColumn(id, width_base, check_visible, priority)
    insertSorted(EHUD._left, col)
    EHUD._leftMap[id] = col
end

function EHUD.RegisterRightColumn(id, width_base, check_visible, priority)
    if EHUD._rightMap[id] then return end
    local col = makeColumn(id, width_base, check_visible, priority)
    insertSorted(EHUD._right, col)
    EHUD._rightMap[id] = col
end

function EHUD.GetColumn(id)
    return EHUD._leftMap[id] or EHUD._rightMap[id]
end

-- Add/update a vstack element above a named column
function EHUD.AddToColumn(col_id, elem_id, obj, priority)
    local col = EHUD._leftMap[col_id] or EHUD._rightMap[col_id]
    if not col then return end
    if col.vstack_map[elem_id] then
        col.vstack_map[elem_id].obj      = obj
        col.vstack_map[elem_id].priority = priority or col.vstack_map[elem_id].priority
        table.sort(col.vstack, function(a,b) return a.priority < b.priority end)
        return
    end
    local item = { id = elem_id, obj = obj, priority = priority or 100, anim = makeAnim() }
    insertSorted(col.vstack, item)
    col.vstack_map[elem_id] = item
end

function EHUD.RemoveFromColumn(col_id, elem_id)
    local col = EHUD._leftMap[col_id] or EHUD._rightMap[col_id]
    if not col or not col.vstack_map[elem_id] then return end
    col.vstack_map[elem_id] = nil
    for k, v in ipairs(col.vstack) do
        if v.id == elem_id then table.remove(col.vstack, k) break end
    end
end

-- Add/update a named zone element
function EHUD.AddToZone(zone, elem_id, obj, priority)
    local z = EHUD._zones[zone]
    if not z then return end
    if z.map[elem_id] then
        z.map[elem_id].obj      = obj
        z.map[elem_id].priority = priority or z.map[elem_id].priority
        table.sort(z.list, function(a,b) return a.priority < b.priority end)
        return
    end
    local item = { id = elem_id, obj = obj, priority = priority or 100, anim = makeAnim() }
    insertSorted(z.list, item)
    z.map[elem_id] = item
end

function EHUD.RemoveFromZone(zone, elem_id)
    local z = EHUD._zones[zone]
    if not z or not z.map[elem_id] then return end
    z.map[elem_id] = nil
    for k, v in ipairs(z.list) do
        if v.id == elem_id then table.remove(z.list, k) break end
    end
end

-- ============================================================================
-- ANIMATION HELPER
-- ============================================================================
local function animStep(anim, target, dt)
    if target ~= anim.tgt then
        anim.tgt = target
        anim.spd = math.abs(target - anim.cur) / EHUD.ANIM_TIME
    end
    anim.cur = math.Approach(anim.cur, anim.tgt, anim.spd * dt)
    return anim.cur
end

-- ============================================================================
-- NATIVE HUD SPACE DETECTION
-- Computes how much vertical space the native HL2 aux bar occupies above
-- the health column, so we can slide our vstack items out of the way.
-- ============================================================================
function EHUD.GetNativeAuxHeight()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return 0 end
    local s = EHUD.Scale()
    -- Active items: sprint, flashlight, oxygen each add a row
    local sprinting = ply:IsSprinting() and ply:GetVelocity():Length2D() > 1
    local flash     = ply:FlashlightIsOn()
    local oxygen    = ply:WaterLevel() == 3
    local itemCount = (sprinting and 1 or 0) + (flash and 1 or 0) + (oxygen and 1 or 0)
    -- Native aux bar appears when suit power is below 100 OR any item is active.
    -- Does NOT require armor > 0 — sprint/flashlight trigger it too.
    local suitPower = ply:GetSuitPower()
    local auxVisible = suitPower < 100 or itemCount > 0
    if not auxVisible then return 0 end
    -- Base bar: 26 units tall. Each active item row: +10 units.
    local h = (26 + itemCount * 10) * s
    return h + EHUD.STACK_GAP * s
end

-- ============================================================================
-- NATIVE AMMO WIDTH DETECTION
-- Returns how far from the right edge the native ammo display extends.
-- ============================================================================
function EHUD.GetNativeAmmoWidth()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return 0 end
    local wpn = ply:GetActiveWeapon()
    if not IsValid(wpn) then return 0 end
    if wpn:GetPrimaryAmmoType() == -1 then return 0 end
    local hasSec = wpn:GetSecondaryAmmoType() ~= -1
    local hasClip = wpn:GetMaxClip1() ~= -1
    if hasSec then return 222
    elseif hasClip then return 150
    else return 118 end
end

-- ============================================================================
-- DRAW SCISSORED ITEM
-- ============================================================================
local function drawClipped(obj, x, y, clip_h)
    local w, _ = obj:GetSize()
    render.SetScissorRect(x, y, x + w, y + clip_h, true)
    obj:Draw(x, y, clip_h)
    render.SetScissorRect(0, 0, 0, 0, false)
end

-- ============================================================================
-- MAIN RENDER
-- ============================================================================
hook.Add("HUDPaint", "EHUD_Render", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local s    = EHUD.Scale()
    local dt   = FrameTime()
    local scrW = ScrW()
    local scrH = ScrH()
    local baseY = scrH - (48 * s)   -- top of the standard 36-unit row
    local margin = EHUD.MARGIN * s
    local gap    = EHUD.COL_GAP * s
    local stackGap = EHUD.STACK_GAP * s

    -- ------------------------------------------------------------------
    -- LEFT HSTACK
    -- ------------------------------------------------------------------
    local cx = margin
    for _, col in ipairs(EHUD._left) do
        if col.check_visible() then
            local colW = col.width_base * s

            -- Draw base element
            if col.base_element then
                local w, h = col.base_element:GetSize()
                colW = w
                local drawY = baseY + (36 * s - h)  -- bottom-align to standard row
                col.base_element:Draw(cx, drawY, h)
            end

            -- Compute vstack start: above base element, accounting for
            -- animated native aux space (only for "health" column)
            local stackTopY = baseY - stackGap
            if col.id == "health" then
                local auxTarget = EHUD.GetNativeAuxHeight()
                stackTopY = stackTopY - animStep(col.anim_aux, auxTarget, dt)
            end

            -- Render vstack items bottom-up
            local cy = stackTopY
            for _, item in ipairs(col.vstack) do
                local _, tgtH = item.obj:GetSize()
                local curH = animStep(item.anim, tgtH, dt)
                if curH > 1 then
                    local iy = cy - curH
                    drawClipped(item.obj, cx, iy, curH)
                    cy = iy - stackGap
                end
            end

            cx = cx + colW + gap
        end
    end

    -- ------------------------------------------------------------------
    -- RIGHT HSTACK
    -- ------------------------------------------------------------------
    local rx = scrW - margin
    for _, col in ipairs(EHUD._right) do
        if col.check_visible() then
            local colW = col.width_base * s

            -- Special: reserve space for native ammo
            if col.id == "ammo" then
                local nativeW = EHUD.GetNativeAmmoWidth() * s
                local target = nativeW > 0 and (nativeW - margin + gap) or 0
                local animated = animStep(col.anim_width, target, dt)
                colW = animated - gap
            elseif col.base_element then
                local w, h = col.base_element:GetSize()
                colW = w
                col.base_element:Draw(rx - w, baseY + (36 * s - h), h)
            end

            local stackTopY = baseY - stackGap
            local cy = stackTopY
            for _, item in ipairs(col.vstack) do
                local w, tgtH = item.obj:GetSize()
                local curH = animStep(item.anim, tgtH, dt)
                if curH > 1 then
                    local iy = cy - curH
                    drawClipped(item.obj, rx - w, iy, curH)
                    cy = iy - stackGap
                end
            end

            rx = rx - colW - gap
        end
    end

    -- ------------------------------------------------------------------
    -- CENTER ZONE
    -- ------------------------------------------------------------------
    local cy_center = baseY
    for _, item in ipairs(EHUD._zones.center.list) do
        local w, tgtH = item.obj:GetSize()
        local curH = animStep(item.anim, tgtH, dt)
        if curH > 1 then
            local ix = (scrW / 2) - (w / 2)
            local iy = cy_center - curH
            drawClipped(item.obj, ix, iy, curH)
            cy_center = iy - stackGap
        end
    end

    -- ------------------------------------------------------------------
    -- TOP-LEFT ZONE
    -- ------------------------------------------------------------------
    local tly = margin
    for _, item in ipairs(EHUD._zones.topleft.list) do
        local w, tgtH = item.obj:GetSize()
        local curH = animStep(item.anim, tgtH, dt)
        if curH > 1 then
            drawClipped(item.obj, margin, tly, curH)
            tly = tly + curH + stackGap
        end
    end

    -- ------------------------------------------------------------------
    -- TOP-RIGHT ZONE
    -- ------------------------------------------------------------------
    local try = margin
    for _, item in ipairs(EHUD._zones.topright.list) do
        local w, tgtH = item.obj:GetSize()
        local curH = animStep(item.anim, tgtH, dt)
        if curH > 1 then
            drawClipped(item.obj, scrW - margin - w, try, curH)
            try = try + curH + stackGap
        end
    end
end)

-- ============================================================================
-- REGISTER BUILT-IN COLUMNS (mirror native HL2 layout)
-- "health" = leftmost column (priority 10)
-- "suit"   = second column, only when player has armor (priority 20)
-- "ammo"   = rightmost column, reserves native ammo space (priority 10)
-- ============================================================================
EHUD.RegisterLeftColumn("health", 102, nil, 10)
EHUD.RegisterLeftColumn("suit", 108, function()
    local ply = LocalPlayer()
    return IsValid(ply) and ply:Armor() > 0
end, 20)
EHUD.RegisterRightColumn("ammo", 102, nil, 10)

print("[EHUD] ExtensibleHUD framework loaded (v" .. EHUD.VERSION .. ")")
