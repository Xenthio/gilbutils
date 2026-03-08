-- gilbutils/vtf_write_test.lua
-- Run via: lua_openscript gilbutils/vtf_write_test.lua
-- Tests whether GMod can load VTF files written to data/ folder
-- Tries multiple path/extension combinations

concommand.Add("vtf_write_test", function()
    print("[VTFTest] Starting...")

    -- Grab any world material that has a readable VTF
    local testMat, tname, vtfData
    local world = Entity(0)
    if world and world.GetMaterials then
        for _, name in ipairs(world:GetMaterials()) do
            local m = Material(name)
            if not m:IsError() then
                local ok, t = pcall(function() return m:GetTexture("$basetexture") end)
                if ok and t and not t:IsError() then
                    local tn = t:GetName()
                    local d = file.Read("materials/" .. tn .. ".vtf", "GAME")
                    if d then
                        testMat, tname, vtfData = m, tn, d
                        break
                    end
                end
            end
        end
    end
    if not testMat then print("[VTFTest] No usable world material found!") return end
    print(string.format("[VTFTest] Using texture: %s (%d bytes)", tname, #vtfData))

    -- Basic sanity: can we write/read anything at all?
    file.CreateDir("vtftest")
    file.Write("vtftest/sanity.txt", "hello")
    local s = file.Read("vtftest/sanity.txt", "DATA")
    print("[VTFTest] Sanity write/read: " .. tostring(s))

    -- Test with a small slice first to rule out size limits
    file.Write("vtftest/small.vtf", vtfData:sub(1, 1024))
    local small = file.Read("vtftest/small.vtf", "DATA")
    print("[VTFTest] Small write (1KB): " .. (small and (#small.." bytes") or "nil"))

    -- Full VTF
    file.Write("vtftest/full.vtf", vtfData)
    local full = file.Read("vtftest/full.vtf", "DATA")
    print("[VTFTest] Full write ("..#vtfData.."B): " .. (full and (#full.." bytes") or "nil"))

    -- Write VTF + companion VMT, load via ../data/ trick
    file.CreateDir("vtftest")
    file.Write("vtftest/test.vtf", vtfData)
    file.Write("vtftest/test.vmt", '"UnlitGeneric"\n{\n\t"$basetexture" "../data/vtftest/test"\n}\n')

    local m = Material("../data/vtftest/test")
    print("[VTFTest] IsError=" .. tostring(m:IsError()))
    if not m:IsError() then
        local ok, t = pcall(function() return m:GetTexture("$basetexture") end)
        print("[VTFTest] $basetexture ok=" .. tostring(ok) .. " tex=" .. tostring(t and not t:IsError() and t:GetName()))
        if ok and t and not t:IsError() then
            local orig = testMat:GetTexture("$basetexture")
            testMat:SetTexture("$basetexture", t)
            print("[VTFTest] Applied! Check world texture. Restoring in 5s...")
            timer.Simple(5, function()
                testMat:SetTexture("$basetexture", orig)
                print("[VTFTest] Restored.")
            end)
        end
    end

    print("\n[VTFTest] Done.")
end)

print("[VTFTest] Loaded. Run: vtf_write_test")
