return function(T)
    -- Demonstrates the Ports & Adapters seam introduced in Phase 1: a module can
    -- run against an in-memory fake ports table, with no Hammerspoon (`hs`)
    -- present at all. Before ports, tests had to monkey-patch the global `hs`.

    local function fakePorts(calls)
        return {
            exec = {
                run = function(command)
                    calls[#calls + 1] = command
                    return "", true
                end,
            },
            fs = {
                attributes = function()
                    return { mode = "directory" }
                end,
                absolute = function(path)
                    return path
                end,
            },
        }
    end

    T.test("ports seam: Util runs on fake ports with no hs global", function()
        local calls = {}
        local util = dofile(T.repoRoot .. "/lib/Util.lua")({
            ports = fakePorts(calls),
        })

        -- Remove hs entirely to prove the module no longer depends on it.
        local savedHs = _G.hs
        _G.hs = nil
        local _, ensured = util.ensureDir("/tmp/example")
        local exists = util.fileExists("/tmp/example")
        _G.hs = savedHs

        T.assertTrue(ensured, "ensureDir should succeed via the fake exec port")
        T.assertTrue(exists, "fileExists should succeed via the fake fs port")
        T.assertEqual(calls[1], "/bin/mkdir -p '/tmp/example'")
    end)

    T.test("ports seam: exec port captures shell commands without running them", function()
        local calls = {}
        local util = dofile(T.repoRoot .. "/lib/Util.lua")({
            ports = fakePorts(calls),
        })

        util.copyPath("/from", "/to")

        -- copyPath removes the destination, then copies; both go through the port,
        -- so no real /bin/rm or /bin/cp is ever spawned.
        T.assertEqual(calls[1], "/bin/rm -rf '/to'")
        T.assertEqual(calls[2], "/bin/cp -R '/from' '/to'")
    end)
end
