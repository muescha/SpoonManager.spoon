local repoRoot = os.getenv("PWD")
local configPath = arg and arg[1]
local runTimestamp = os.date("%Y-%m-%d-%H-%M-%S")

if not configPath or configPath == "" then
    io.stderr:write("usage: lua tests/integration/network.lua tests/integration/network.local.json [test-id|--prefix prefix|--match pattern]\n")
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

local function wildcardToPattern(value)
    local parts = { "^" }
    for index = 1, #value do
        local char = value:sub(index, index)
        if char == "*" then
            table.insert(parts, ".*")
        elseif char:match("[%w_]") then
            table.insert(parts, char)
        else
            table.insert(parts, "%" .. char)
        end
    end
    table.insert(parts, "$")
    return table.concat(parts)
end

local function parseFilters()
    local filters = {}
    local index = 2

    local function addFilter(kind, value)
        assertString(value, "network test filter")
        table.insert(filters, {
            kind = kind,
            value = value,
            pattern = kind == "match" and wildcardToPattern(value) or nil,
        })
    end

    while arg and index <= #arg do
        local item = arg[index]

        if item == "--id" or item == "--only" then
            index = index + 1
            addFilter("id", arg[index])
        elseif item == "--prefix" then
            index = index + 1
            addFilter("prefix", arg[index])
        elseif item == "--match" then
            index = index + 1
            addFilter("match", arg[index])
        elseif item:match("^%-%-id=") or item:match("^%-%-only=") then
            addFilter("id", item:match("^[^=]+=(.*)$"))
        elseif item:match("^%-%-prefix=") then
            addFilter("prefix", item:match("^[^=]+=(.*)$"))
        elseif item:match("^%-%-match=") then
            addFilter("match", item:match("^[^=]+=(.*)$"))
        elseif item:find("*", 1, true) then
            addFilter("match", item)
        else
            addFilter("id", item)
        end

        index = index + 1
    end

    return filters
end

local filters = parseFilters()

local function testMatchesFilters(test)
    if #filters == 0 then
        return true
    end

    local id = test.id or ""
    for _, filter in ipairs(filters) do
        if filter.kind == "id" and id == filter.value then
            return true
        end
        if filter.kind == "prefix" and id:sub(1, #filter.value) == filter.value then
            return true
        end
        if filter.kind == "match" and id:match(filter.pattern) then
            return true
        end
    end

    return false
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
    if test.definition then
        return SpoonManager.from.config(test.definition)
    end

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

local function expectedFilesCheck(test, result)
    local expected = test.expect or {}
    local files = expected.files or {}

    assertExpectedFiles(test, result)

    return {
        success = true,
        files = files,
    }
end

local function compactRunResult(result)
    if not result then
        return nil
    end

    return {
        action = result.action,
        name = result.name,
        path = result.path,
        skipped = result.skipped or nil,
        reason = result.reason,
    }
end

local function buildRunnerResult(test, paths)
    return {
        success = false,
        timestamp = runTimestamp,
        test = {
            id = test.id,
            description = test.description,
            source = test.source,
            target = test.target,
            definition = test.definition,
            expect = test.expect,
        },
        paths = paths,
        spoonExplain = nil,
        runs = {},
        checks = {},
    }
end

local function errorBlock(message, trace)
    return {
        message = message,
        trace = trace,
    }
end

local function expectedFailure(test)
    local expect = test.expect or {}
    if type(expect.failure) == "table" then
        return expect.failure
    end
    return nil
end

local function failureMatches(expectation, trace)
    if not expectation then
        return false
    end

    local messageContains = expectation.messageContains
    if messageContains ~= nil then
        assertString(messageContains, "expect.failure.messageContains")
        return tostring(trace or ""):find(messageContains, 1, true) ~= nil
    end

    return true
end

local enabled = 0
local passed = 0
local failed = 0
local failures = {}
local rootPath = rootPathForRun()

cleanRootBeforeRun(rootPath)

for _, test in ipairs(config.tests or {}) do
    if test.enabled and testMatchesFilters(test) then
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
            runnerResult = buildRunnerResult(test, {
                root = rootPath,
                install = installPath,
                explain = explainPath,
                result = runnerPath,
                log = logPath,
            })

            cleanInstallPathBeforeTest(test, installPath)
            ensureDir(installPath)

            stubHammerspoon(installPath, logs)
            local SpoonManager = dofile(repoRoot .. "/init.lua")
            local definition = buildDefinition(SpoonManager, test)
            definition.command("install")
            runnerResult.spoonExplain = definition.explain()
            json.write(explainPath, runnerResult.spoonExplain)

            local result, installErr = definition.install()
            if not result then
                runnerResult.runs.install = {
                    success = false,
                    error = errorBlock(installErr or "install failed", installErr),
                }
                error(installErr or "install failed")
            end
            runnerResult.runs.install = {
                success = true,
                result = compactRunResult(result),
            }
            runnerResult.checks.expectedFiles = expectedFilesCheck(test, result)

            local skipped, skipErr = definition.install()
            if not skipped then
                runnerResult.checks.alreadyInstalledSkip = {
                    success = false,
                    error = errorBlock(skipErr or "second install failed", skipErr),
                }
                error(skipErr or "second install failed")
            end
            if not skipped.skipped then
                runnerResult.checks.alreadyInstalledSkip = {
                    success = false,
                    result = compactRunResult(skipped),
                    error = errorBlock("second install should have skipped an already installed Spoon"),
                }
                error("second install should have skipped an already installed Spoon")
            end

            runnerResult.checks.alreadyInstalledSkip = {
                success = true,
                result = {
                    skipped = skipped.skipped,
                    reason = skipped.reason,
                },
            }
            if expectedFailure(test) then
                runnerResult.checks.expectedFailure = {
                    success = false,
                    error = errorBlock("expected failure but install succeeded"),
                }
                error("expected failure but install succeeded")
            end
            runnerResult.success = true
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
            local failureMessage = tostring(err):match("^[^\n]+") or tostring(err)
            local expected = expectedFailure(test)
            local matchedExpectedFailure = expected and failureMatches(expected, err)

            if matchedExpectedFailure then
                passed = passed + 1
                print("ok (expected failure)")
            else
                failed = failed + 1
                table.insert(failures, {
                    id = test.id,
                    message = failureMessage,
                })
                print("failed")
                print(err)
            end

            if runnerPath then
                runnerResult = runnerResult or buildRunnerResult(test, {
                    root = rootPath,
                    install = installPath,
                    explain = explainPath,
                    result = runnerPath,
                    log = logPath,
                })
                if matchedExpectedFailure then
                    runnerResult.success = true
                    runnerResult.checks.expectedFailure = {
                        success = true,
                        messageContains = expected.messageContains,
                    }
                    runnerResult.error = nil
                else
                    runnerResult.success = false
                    runnerResult.error = errorBlock(failureMessage, err)
                end
                json.write(runnerPath, runnerResult)
            end
            if logPath then
                json.write(logPath, {
                    id = test.id,
                    success = matchedExpectedFailure or false,
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
