concommand.Add("hl2hud_sprite_debug", function()
    -- Test files known to have TextureData
    local tests = {"weapon_egon.txt", "weapon_gauss.txt", "weapon_hornetgun.txt", "weapon_snark.txt", "weapon_mp5.txt"}
    for _, fname in ipairs(tests) do
        local raw = file.Read("scripts/" .. fname, "GAME")
        MsgN("--- " .. fname .. " read=" .. tostring(raw ~= nil))
        if raw then
            local tbl = util.KeyValuesToTable(raw)
            -- print top-level keys
            for k, v in pairs(tbl) do
                MsgN("  key: [" .. tostring(k) .. "] type=" .. type(v))
                if type(v) == "table" then
                    for k2, v2 in pairs(v) do
                        MsgN("    key: [" .. tostring(k2) .. "] type=" .. type(v2))
                        if type(v2) == "table" then
                            for k3 in pairs(v2) do
                                MsgN("      key: [" .. tostring(k3) .. "]")
                            end
                        end
                    end
                end
            end
        end
    end
end)
