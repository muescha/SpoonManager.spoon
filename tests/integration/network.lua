local repoRoot = os.getenv("PWD")
local configPath = arg and arg[1]
local runTimestamp = os.date("!%Y-%m-%d-%H-%M-%S")

if not configPath or configPath == "" then
    io.stderr:write("usage: lua tests/integration/network.lua tests/integration/network.local.json\n")
    os.exit(2)
end

local json = dofile(repoRoot .. "/tests/helpers/json.lua")
local config = assert(json.read(configPath))

local function shellQuote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function pathJoin(...)
    local path = table.concat({ ... }, "/")
    return path:gsub("/+", "/")
end

local function parentDir(path)
    return path:match("^(.*)/[^/]*$") or "."
end

local function ensureDir(path)
    os.execute("/bin/mkdir -p " .. shellQuote(path))
end

local function fileExists(path)
    local file = io.open(path, "rb")
    if file then
        file:close()
        return true
    end

    local ok = os.execute("/usr/bin/test -e " .. shellQuote(path))
    return ok == true or ok == 0
end

local function readFile(path, mode)
    local file, err = io.open(path, mode or "r")
    if not file then
        return nil, err
    end

    local content = file:read("*a")
    file:close()
    return content
end

local function runCommand(command)
    local handle = io.popen(command)
    if not handle then
        return nil, false
    end

    local output = handle:read("*a")
    local ok = handle:close()
    return output, ok == true
end

local function safeId(value)
    value = tostring(value or "")
    value = value:gsub("[^%w_.-]+", "-")
    value = value:gsub("^-+", ""):gsub("-+$", "")
    if value == "" then
        return "unnamed"
    end
    return value
end

local function assertString(value, label)
    if type(value) ~= "string" or value == "" then
        error(label .. " must be a non-empty string")
    end
end

local function renderTemplate(template, values)
    return (template:gsub("{([%w_]+)}", function(key)
        if key == "installRoot" then
            return tostring(values[key] or "")
        end
        return safeId(values[key] or "")
    end))
end

local function sourceLabel(test)
    local source = test.source or {}
    return source.type or "unknown"
end

local function targetLabel(test)
    local target = test.target or {}
    return target.name or target.spoon or test.id
end

local function assertSafeTestPath(path, label)
    if path:sub(1, 5) ~= "/tmp/" or not path:match("spoonmanager") then
        error(label .. " must be a /tmp path containing 'spoonmanager': " .. path)
    end
end

local function installRootForRun()
    local installRoot = config.installRoot or "/tmp/spoonmanager-network-test"
    assertString(installRoot, "installRoot")
    assertSafeTestPath(installRoot, "installRoot")
    return installRoot
end

local function installPathFor(test, installRoot)
    local template = test.installPathTemplate
        or config.installPathTemplate
        or "{installRoot}/testinstalls/{timestamp}/{id}"

    assertString(template, "installPathTemplate")

    local installPath = renderTemplate(template, {
        installRoot = installRoot,
        id = test.id,
        sourceType = sourceLabel(test),
        name = targetLabel(test),
        timestamp = runTimestamp,
    })

    assertSafeTestPath(installPath, "installPath")

    return installPath
end

local function cleanupValue(test, section, key, default)
    local testCleanup = test and test.cleanup
    if type(testCleanup) == "table" then
        if type(testCleanup[section]) == "table" and testCleanup[section][key] ~= nil then
            return testCleanup[section][key]
        end
        if testCleanup[key] ~= nil then
            return testCleanup[key]
        end
    end

    local globalCleanup = config.cleanup
    if type(globalCleanup) == "table" then
        if type(globalCleanup[section]) == "table" and globalCleanup[section][key] ~= nil then
            return globalCleanup[section][key]
        end
        if globalCleanup[key] ~= nil then
            return globalCleanup[key]
        end
    end

    return default
end

local function cleanPath(path)
    os.execute("/bin/rm -rf " .. shellQuote(path))
end

local function cleanInstallRootBeforeRun(installRoot)
    if cleanupValue(nil, "allTests", "installRootBeforeAllTests", false) then
        cleanPath(installRoot)
    end
end

local function cleanInstallRootAfterRun(installRoot)
    if cleanupValue(nil, "allTests", "installRootAfterAllTests", false) then
        cleanPath(installRoot)
    end
end

local function cleanInstallPathBeforeTest(test, installPath)
    if cleanupValue(test, "test", "installPathBeforeTest", true) then
        cleanPath(installPath)
    end
end

local function cleanInstallPathAfterTest(test, installPath)
    if cleanupValue(test, "test", "installPathAfterTest", false) then
        cleanPath(installPath)
    end
end

local function stubHammerspoon(installRoot)
    hs = {
        configdir = installRoot,
        logger = {
            new = function()
                return {
                    df = function() end,
                    ef = function(fmt, ...)
                        io.stderr:write(string.format(fmt or "%s", ...) .. "\n")
                    end,
                    i = function() end,
                    w = function() end,
                }
            end,
        },
        spoons = {
            scriptPath = function()
                return repoRoot
            end,
            use = function()
                return true
            end,
        },
        fs = {
            attributes = function(path)
                if fileExists(path) then
                    return {}
                end
                return nil
            end,
            pathToAbsolute = function(path)
                return path:gsub("^~", os.getenv("HOME") or "~")
            end,
        },
        execute = function(command)
            return runCommand(command)
        end,
        http = {
            get = function(url)
                local tmp = os.tmpname()
                local command = table.concat({
                    "/usr/bin/curl",
                    "-L",
                    "-s",
                    "-w",
                    shellQuote("%{http_code}"),
                    "-o",
                    shellQuote(tmp),
                    shellQuote(url),
                }, " ")

                local statusText, ok = runCommand(command)
                local status = tonumber(statusText)
                local body = readFile(tmp, "rb") or ""
                os.remove(tmp)

                if not ok and not status then
                    return 0, body, {}
                end

                return status or 0, body, {}
            end,
        },
        json = {
            encode = function(value)
                return json.encode(value)
            end,
            read = function(path)
                return json.read(path)
            end,
        },
    }
end

local function providerOptions(source)
    local options = {}

    for _, key in ipairs({
        "baseUrl",
        "branch",
        "ref",
        "defaultBranch",
    }) do
        if source[key] ~= nil then
            options[key] = source[key]
        end
    end

    return options
end

local function buildDefinition(SpoonManager, test)
    local source = test.source or {}
    local target = test.target or {}
    local definition

    if source.type == "github-folder" then
        assertString(source.repository, test.id .. ".source.repository")
        assertString(source.folder, test.id .. ".source.folder")
        definition = SpoonManager.from.github(source.repository, providerOptions(source))
            .folder(source.folder)
    elseif source.type == "spoon-repo" then
        assertString(source.repository, test.id .. ".source.repository")
        assertString(target.spoon, test.id .. ".target.spoon")
        definition = SpoonManager.from.spoonRepo(source.repository, providerOptions(source))
            .spoon(target.spoon)
    elseif source.type == "spoon-repo-zip" then
        assertString(source.repository, test.id .. ".source.repository")
        assertString(target.spoon, test.id .. ".target.spoon")
        definition = SpoonManager.from.spoonRepoZip(source.repository, providerOptions(source))
            .spoon(target.spoon)
    elseif source.type == "github-repository" then
        assertString(source.repository, test.id .. ".source.repository")
        definition = SpoonManager.from.github(source.repository, providerOptions(source))
    elseif source.type == "github-release" then
        assertString(source.repository, test.id .. ".source.repository")
        assertString(source.asset, test.id .. ".source.asset")
        definition = SpoonManager.from.github(source.repository, providerOptions(source))
        if source.release == nil or source.release == "latest" then
            definition = definition.releaseLatest()
        else
            assertString(source.release, test.id .. ".source.release")
            definition = definition.release(source.release)
        end
        definition = definition.asset(source.asset)
    elseif source.type == "remote-zip" then
        assertString(source.url, test.id .. ".source.url")
        definition = SpoonManager.from.remoteZip(source.url)
    else
        error("Unsupported network source type: " .. tostring(source.type))
    end

    if target.spoon and source.type ~= "spoon-repo" and source.type ~= "spoon-repo-zip" then
        definition = definition.spoon(target.spoon)
    end

    if target.name then
        definition = definition.withName(target.name)
    end

    return definition
end

local function explainPathFor(test, installRoot, installPath)
    local template = test.explainPathTemplate
        or config.explainPathTemplate
        or "tests/integration/network.test.{timestamp}.{id}.explain.json"

    assertString(template, "explainPathTemplate")

    local explainPath = renderTemplate(template, {
        installRoot = installRoot,
        installPath = installPath,
        id = test.id,
        sourceType = sourceLabel(test),
        name = targetLabel(test),
        timestamp = runTimestamp,
    })

    if explainPath:sub(1, 1) ~= "/" then
        explainPath = pathJoin(repoRoot, explainPath)
    end
    ensureDir(parentDir(explainPath))
    return explainPath
end

local function assertExpectedFiles(test, result)
    local expected = test.expect or {}
    for _, relativePath in ipairs(expected.files or {}) do
        local fullPath = pathJoin(result.path, relativePath)
        if not fileExists(fullPath) then
            error(string.format("%s expected file missing: %s", test.id, fullPath))
        end
    end
end

local enabled = 0
local passed = 0
local installRoot = installRootForRun()

cleanInstallRootBeforeRun(installRoot)

for _, test in ipairs(config.tests or {}) do
    if test.enabled then
        enabled = enabled + 1
        assertString(test.id, "test.id")

        io.write("network test: " .. test.id .. " ... ")
        local installPath

        local ok, err = xpcall(function()
            installPath = installPathFor(test, installRoot)
            cleanInstallPathBeforeTest(test, installPath)
            ensureDir(installPath)

            stubHammerspoon(installPath)
            local SpoonManager = dofile(repoRoot .. "/init.lua")
            local definition = buildDefinition(SpoonManager, test)
            json.write(explainPathFor(test, installRoot, installPath), definition.explain("install"))

            local result, installErr = definition.install()
            if not result then
                error(installErr or "install failed")
            end
            assertExpectedFiles(test, result)

            local skipped, skipErr = definition.install()
            if not skipped then
                error(skipErr or "second install failed")
            end
            if not skipped.skipped then
                error("second install should have skipped an already installed Spoon")
            end
        end, debug.traceback)

        if ok then
            passed = passed + 1
            print("ok (" .. installPath .. ")")
            cleanInstallPathAfterTest(test, installPath)
        else
            print("failed")
            print(err)
            if installPath then
                cleanInstallPathAfterTest(test, installPath)
            end
            cleanInstallRootAfterRun(installRoot)
            os.exit(1)
        end
    end
end

cleanInstallRootAfterRun(installRoot)

if enabled == 0 then
    print("0 network tests enabled")
else
    print(string.format("%d network tests passed", passed))
end
