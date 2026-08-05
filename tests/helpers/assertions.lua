local M = {}

local function sortedKeys(tbl)
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    return keys
end

local function isArray(tbl)
    local count = 0
    local max = 0

    for key in pairs(tbl) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end

        count = count + 1
        if key > max then
            max = key
        end
    end

    return max == count
end

local function encodeString(value)
    value = value:gsub("\\", "\\\\")
    value = value:gsub("\"", "\\\"")
    value = value:gsub("\b", "\\b")
    value = value:gsub("\f", "\\f")
    value = value:gsub("\n", "\\n")
    value = value:gsub("\r", "\\r")
    value = value:gsub("\t", "\\t")
    return "\"" .. value .. "\""
end

local function encodeJson(value, indent)
    indent = indent or 0
    local valueType = type(value)

    if valueType == "nil" then
        return "null"
    end

    if valueType == "boolean" or valueType == "number" then
        return tostring(value)
    end

    if valueType == "string" then
        return encodeString(value)
    end

    if valueType ~= "table" then
        error("Cannot encode value of type " .. valueType)
    end

    local nextIndent = indent + 2
    local prefix = string.rep(" ", nextIndent)
    local suffix = string.rep(" ", indent)
    local parts = {}

    if isArray(value) then
        for index = 1, #value do
            table.insert(parts, prefix .. encodeJson(value[index], nextIndent))
        end
        if #parts == 0 then
            return "[]"
        end
        return "[\n" .. table.concat(parts, ",\n") .. "\n" .. suffix .. "]"
    end

    for _, key in ipairs(sortedKeys(value)) do
        table.insert(parts, prefix .. encodeString(tostring(key)) .. ": " .. encodeJson(value[key], nextIndent))
    end

    if #parts == 0 then
        return "{}"
    end

    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. suffix .. "}"
end

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
        local json = encodeJson(actual)
        local fullPath = api.repoRoot .. "/tests/" .. snapshotPath

        if os.getenv("SPOONMANAGER_UPDATE_SNAPSHOTS") == "1" then
            writeFile(fullPath, json)
            return
        end

        local expected = readFile(fullPath)
        if not expected then
            error("Snapshot missing: " .. fullPath, 2)
        end

        if expected:gsub("%s+$", "") ~= json then
            error("Snapshot mismatch: " .. snapshotPath, 2)
        end
    end

    return api
end

return M
