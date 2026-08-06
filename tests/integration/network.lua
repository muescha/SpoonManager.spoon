local repoRoot = os.getenv("PWD")
local configPath = arg and arg[1]
local runTimestamp = os.date("%Y-%m-%d-%H-%M-%S")

if not configPath or configPath == "" then
    io.stderr:write("usage: lua tests/integration/network.lua tests/integration/network.local.json\n")
    os.exit(2)
end

local json = dofile(repoRoot .. "/tests/helpers/json.lua")
local config = assert(json.read(configPath))

local function pathJoin(...)
    local path = table.concat({ ... }, "/")
    return path:gsub("/+", "/")
end

local function isAbsolutePath(path)
    return type(path) == "string" and path:sub(1, 1) == "/"
end

local absoluteConfigPath = isAbsolutePath(configPath) and configPath or pathJoin(repoRoot, configPath)

local function shellQuote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function parentDir(path)
    return path:match("^(.*)/[^/]*$") or "."
end

local configDir = parentDir(absoluteConfigPath)

local function resolveConfiguredPath(path)
    if isAbsolutePath(path) then
        return path
    end

    return pathJoin(configDir, path)
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

    local ok = os.execute("/bin/test -e " .. shellQuote(path))
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
        if key == "root" then
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
    if not isAbsolutePath(path) then
        error(label .. " must resolve to an absolute path: " .. tostring(path))
    end

    if path:match("(^|/)%.%.(/|$)") then
        error(label .. " must not contain '..': " .. path)
    end

    if path == configDir then
        error(label .. " must not be the network config directory itself: " .. path)
    end

    if path:sub(1, 5) == "/tmp/" then
        return
    end

    if path:sub(1, #configDir + 1) == configDir .. "/" then
        return
    end

    error(label .. " must be inside /tmp or the network config directory: " .. path)
end

local function pathTemplateFor(test, templateName, defaultTemplate)
    local testPathTemplates = test and test.pathTemplates or {}
    local configPathTemplates = config.pathTemplates or {}
    local template = testPathTemplates[templateName]
        or configPathTemplates[templateName]
        or defaultTemplate

    assertString(template, "pathTemplates." .. templateName)
    return template
end

local function rootPathForRun()
    local template = pathTemplateFor(nil, "root", "/tmp/spoonmanager-network-test")
    local rootPath = renderTemplate(template, {
        timestamp = runTimestamp,
    })

    rootPath = resolveConfiguredPath(rootPath)
    assertSafeTestPath(rootPath, "pathTemplates.root")
    return rootPath
end

local function installPathFor(test, rootPath)
    local template = pathTemplateFor(test, "install", "{root}/testinstalls/{timestamp}/{id}")

    local installPath = renderTemplate(template, {
        root = rootPath,
        id = test.id,
        sourceType = sourceLabel(test),
        name = targetLabel(test),
        timestamp = runTimestamp,
    })

    installPath = resolveConfiguredPath(installPath)
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

local function cleanRootBeforeRun(rootPath)
    if cleanupValue(nil, "allTests", "rootBeforeAllTests", false) then
        cleanPath(rootPath)
    end
end

local function cleanRootAfterRun(rootPath)
    if cleanupValue(nil, "allTests", "rootAfterAllTests", false) then
        cleanPath(rootPath)
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

local function artifactPathFor(test, rootPath, installPath, templateName, defaultTemplate)
    local template = pathTemplateFor(test, templateName, defaultTemplate)

    local artifactPath = renderTemplate(template, {
        root = rootPath,
        id = test.id,
        sourceType = sourceLabel(test),
        name = targetLabel(test),
        timestamp = runTimestamp,
    })

    artifactPath = resolveConfiguredPath(artifactPath)
    ensureDir(parentDir(artifactPath))
    return artifactPath
end

local function stubHammerspoon(configRoot, logs)
    local function logMessage(level, fmt, ...)
        local message = string.format(fmt or "%s", ...)
        table.insert(logs, {
            level = level,
            message = message,
        })
        if level == "error" then
            io.stderr:write(message .. "\n")
        end
    end

    hs = {
        configdir = configRoot,
        logger = {
            new = function()
                return {
                    d = function(message)
                        logMessage("debug", "%s", message)
                    end,
                    df = function(fmt, ...)
                        logMessage("debug", fmt, ...)
                    end,
                    e = function(message)
                        logMessage("error", "%s", message)
                    end,
                    ef = function(fmt, ...)
                        logMessage("error", fmt, ...)
                    end,
                    i = function(message)
                        logMessage("info", "%s", message)
                    end,
                    w = function(message)
                        logMessage("warn", "%s", message)
                    end,
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

local function explainPathFor(test, rootPath, installPath)
    return artifactPathFor(
        test,
        rootPath,
        installPath,
        "explain",
        "{root}/network.test.{timestamp}.{id}.explain.json"
    )
end

local function runnerPathFor(test, rootPath, installPath)
    return artifactPathFor(
        test,
        rootPath,
        installPath,
        "result",
        "{root}/network.test.{timestamp}.{id}.result.json"
    )
end

local function logPathFor(test, rootPath, installPath)
    return artifactPathFor(
        test,
        rootPath,
        installPath,
        "log",
        "{root}/network.test.{timestamp}.{id}.log.json"
    )
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
local failed = 0
local failures = {}
local rootPath = rootPathForRun()

cleanRootBeforeRun(rootPath)

for _, test in ipairs(config.tests or {}) do
    if test.enabled then
        enabled = enabled + 1
        assertString(test.id, "test.id")

        io.write("network test: " .. test.id .. " ... ")
        local installPath
        local explainPath
        local runnerPath
        local logPath
        local logs = {}
        local runnerResult

        local ok, err = xpcall(function()
            installPath = installPathFor(test, rootPath)
            explainPath = explainPathFor(test, rootPath, installPath)
            runnerPath = runnerPathFor(test, rootPath, installPath)
            logPath = logPathFor(test, rootPath, installPath)

            cleanInstallPathBeforeTest(test, installPath)
            ensureDir(installPath)

            stubHammerspoon(installPath, logs)
            local SpoonManager = dofile(repoRoot .. "/init.lua")
            local definition = buildDefinition(SpoonManager, test)
            definition.command("install")
            json.write(explainPath, definition.explain())

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

            runnerResult = {
                id = test.id,
                description = test.description,
                success = true,
                timestamp = runTimestamp,
                root = rootPath,
                installPath = installPath,
                explainPath = explainPath,
                runnerPath = runnerPath,
                logPath = logPath,
                source = test.source,
                target = test.target,
                install = result,
                secondInstall = skipped,
            }
        end, debug.traceback)

        if ok then
            passed = passed + 1
            json.write(runnerPath, runnerResult)
            json.write(logPath, {
                id = test.id,
                success = true,
                timestamp = runTimestamp,
                logs = logs,
            })
            print("ok (" .. installPath .. ")")
            cleanInstallPathAfterTest(test, installPath)
        else
            failed = failed + 1
            local failureMessage = tostring(err):match("^[^\n]+") or tostring(err)
            table.insert(failures, {
                id = test.id,
                message = failureMessage,
            })

            print("failed")
            print(err)
            if runnerPath then
                json.write(runnerPath, {
                    id = test.id,
                    description = test.description,
                    success = false,
                    timestamp = runTimestamp,
                    root = rootPath,
                    installPath = installPath,
                    explainPath = explainPath,
                    runnerPath = runnerPath,
                    logPath = logPath,
                    source = test.source,
                    target = test.target,
                    error = err,
                })
            end
            if logPath then
                json.write(logPath, {
                    id = test.id,
                    success = false,
                    timestamp = runTimestamp,
                    error = err,
                    logs = logs,
                })
            end
            if installPath then
                cleanInstallPathAfterTest(test, installPath)
            end
        end
    end
end

cleanRootAfterRun(rootPath)

if enabled == 0 then
    print("0 network tests enabled")
elseif failed > 0 then
    print(string.format("%d network tests passed, %d failed", passed, failed))
    print("Failures:")
    for _, failure in ipairs(failures) do
        print(" - " .. failure.id .. ": " .. failure.message)
    end
    os.exit(1)
else
    print(string.format("%d network tests passed", passed))
end
