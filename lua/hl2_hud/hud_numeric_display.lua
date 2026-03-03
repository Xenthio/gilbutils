-- hud_numeric_display.lua — Port of CHudNumericDisplay::Paint() + PaintLabel()
-- PaintLabel uses GetFgColor() — same color as the number, no separate textColor.
-- HL2Hud.DrawNumericDisplay(x, y, label, value, state, opts)
--   state: { fgColor, bgColor, blur } — anim objects (.cur = live value)
--   opts:  { wide, tall, digit_xpos, digit_ypos, text_xpos, text_ypos }
--          (hudlayout.res units, scaled internally by ScrH/480)

function HL2Hud.DrawNumericDisplay(x, y, label, value, state, opts)
    local s  = ScrH() / 480
    opts = opts or {}
    local w  = (opts.wide       or 102) * s
    local h  = (opts.tall       or  36) * s
    local dx = (opts.digit_xpos or  50) * s
    local dy = (opts.digit_ypos or   2) * s
    local tx = (opts.text_xpos  or   8) * s
    local ty = (opts.text_ypos  or  20) * s
    local C  = HL2Hud.Colors

    -- Background
    local bg = state.bgColor.cur
    draw.RoundedBox(8, x, y, w, h, (bg.a > 0) and bg or C.BgColor)

    -- Label — uses fgColor (same as number, per CHudNumericDisplay::PaintLabel)
    surface.SetFont("HL2Hud_Text")
    surface.SetTextColor(state.fgColor.cur)
    surface.SetTextPos(x + tx, y + ty)
    surface.DrawText(label)

    -- Number + glow (blur 0-5 → glow alpha 0-255)
    local valStr = tostring(value)
    local blur   = state.blur.cur
    if blur > 0 then
        local ga = math.Clamp(blur / 5 * 255, 0, 255)
        local fc = state.fgColor.cur
        surface.SetFont("HL2Hud_NumbersGlow")
        surface.SetTextColor(Color(fc.r, fc.g, fc.b, ga))
        surface.SetTextPos(x + dx, y + dy)
        surface.DrawText(valStr)
    end
    surface.SetFont("HL2Hud_Numbers")
    surface.SetTextColor(state.fgColor.cur)
    surface.SetTextPos(x + dx, y + dy)
    surface.DrawText(valStr)

    return w, h
end
