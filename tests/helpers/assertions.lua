local M = {}

local function readFile(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end

    local value = file:read("*a")
    file:close()
    return value
end

local function writeFile(path, value)
    local dir = path:match("^(.*)/[^/]+$")
    if dir then
        os.execute("/bin/mkdir -p " .. string.format("%q", dir))
    end

    local file, err = io.open(path, "w")
    if not file then
        error(err)
    end

    file:write(value)
    file:write("\n")
    file:close()
end

function M.new(options)
    local json = dofile(options.repoRoot .. "/tests/helpers/json.lua")
    local api = {
        repoRoot = options.repoRoot,
        tests = options.tests,
    }

    function api.test(name, fn)
        table.insert(api.tests, {
            name = name,
            fn = fn,
        })
    end

    function api.assertEqual(actual, expected, message)
        if actual ~= expected then
            error(string.format(
                "%s\nexpected: %s\nactual:   %s",
                message or "assertEqual failed",
                tostring(expected),
                tostring(actual)
            ), 2)
        end
    end

    function api.assertTrue(value, message)
        if not value then
            error(message or "assertTrue failed", 2)
        end
    end

    function api.assertFalse(value, message)
        if value then
            error(message or "assertFalse failed", 2)
        end
    end

    function api.assertError(fn, expectedMessagePattern)
        local ok, err = pcall(fn)
        if ok then
            error("Expected error, but call succeeded", 2)
        end

        if expectedMessagePattern and not tostring(err):match(expectedMessagePattern) then
            error(string.format(
                "Error did not match pattern\npattern: %s\nerror:   %s",
                expectedMessagePattern,
                tostring(err)
            ), 2)
        end
    end

    function api.assertMatchesJson(snapshotPath, actual)
        local encoded = json.encode(actual)
        local fullPath = api.repoRoot .. "/tests/" .. snapshotPath

        if os.getenv("SPOONMANAGER_UPDATE_SNAPSHOTS") == "1" then
            writeFile(fullPath, encoded)
            return
        end

        local expected = readFile(fullPath)
        if not expected then
            error("Snapshot missing: " .. fullPath, 2)
        end

        if expected:gsub("%s+$", "") ~= encoded then
            error("Snapshot mismatch: " .. snapshotPath, 2)
        end
    end

    return api
end

return M
