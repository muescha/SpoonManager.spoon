--- === SpoonManager ===
---
--- Install and manage Spoons from explicit sources.
---
--- The public builder API uses dot notation:
---
--- ```
--- SpoonManager.from.default
---     .spoon("Emojis")
---     .install()
---
--- SpoonManager.from.github("owner/repo")
---     .path("Source/MySpoon.spoon")
---     .withName("MySpoon")
---     .install()
--- ```

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "SpoonManager"
obj.version = "0.1"
obj.author = "muescha"
obj.homepage = "https://github.com/muescha/SpoonManager.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- SpoonManager.logger
--- Variable
--- Logger object used within the Spoon.
obj.logger = hs.logger.new("SpoonManager")

obj.from = {}
obj.providers = {}
obj.definitions = {}

--- SpoonManager.options
--- Variable
--- Public constants used by the builder API.
---
--- Contains:
---  * `conflictStrategy.abort`
---  * `conflictStrategy.backup`
---  * `conflictStrategy.overwrite`
---  * `patterns.spoonRepo`
---  * `patterns.spoonRepoZip`
obj.options = {
    conflictStrategy = {
        abort = "abort",
        backup = "backup",
        overwrite = "overwrite",
    },
    patterns = {
        spoonRepo = "Source/{name}.spoon",
        spoonRepoZip = "Spoons/{name}.spoon.zip",
    },
}

obj.installOptions = {
    conflictStrategy = obj.options.conflictStrategy.abort,
}

obj._reloadController = nil

function obj._isConflictStrategy(behavior)
    for _, value in pairs(obj.options.conflictStrategy) do
        if behavior == value then
            return true
        end
    end

    return false
end

--- SpoonManager.conflictStrategy(behavior) -> SpoonManager
--- Function
--- Set the default behavior for existing or locally changed Spoons.
function obj.conflictStrategy(behavior)
    assert(obj._isConflictStrategy(behavior), "Invalid conflict strategy: " .. tostring(behavior))

    obj.installOptions.conflictStrategy = behavior
    return obj
end

--- SpoonManager.reloadController(controller) -> SpoonManager
--- Function
--- Set a reload controller used to pause config reload watchers during installs or updates.
---
--- The controller may be an object with `start`/`stop` methods, such as an
--- `hs.pathwatcher`, or a table with `start`, `stop`, and optional `reload`
--- functions. If `reload` is omitted, SpoonManager uses `hs.reload`.
function obj.reloadController(controller)
    if controller == nil or controller == false then
        obj._reloadController = nil
        return obj
    end

    assert(type(controller) == "table", "Reload controller must be a table")
    assert(controller.stop == nil or type(controller.stop) == "function", "Reload controller stop must be a function")
    assert(controller.start == nil or type(controller.start) == "function", "Reload controller start must be a function")
    assert(controller.reload == nil or type(controller.reload) == "function", "Reload controller reload must be a function")

    obj._reloadController = controller
    return obj
end

local function callReloadController(method)
    local controller = obj._reloadController
    if not controller then
        return true
    end

    local fn = controller[method]
    if fn then
        return fn(controller)
    end

    if method == "reload" and hs.reload then
        return hs.reload()
    end

    return true
end

local function scheduleReload()
    if hs.timer and hs.timer.doAfter then
        hs.timer.doAfter(0, function()
            callReloadController("reload")
        end)
    else
        callReloadController("reload")
    end
end

local function withReloadController(fn, changed)
    if not obj._reloadController then
        return fn()
    end

    callReloadController("stop")
    local ok, result, err, extra = xpcall(fn, debug.traceback)
    callReloadController("start")

    if not ok then
        error(result, 0)
    end

    if changed(result, err, extra) then
        scheduleReload()
    end

    return result, err, extra
end

local spoonPath = hs.spoons.scriptPath()
local function loadLib(name)
    return dofile(spoonPath .. "/lib/" .. name .. ".lua")
end

local function loadProvider(name)
    return dofile(spoonPath .. "/lib/providers/" .. name .. ".lua")
end

local Util = loadLib("Util")

obj.configDir = Util.pathJoin(hs.configdir, ".config", "SpoonManager")

local context = {
    logger = obj.logger,
    manager = obj,
    util = Util,
}

context.nameResolver = loadLib("NameResolver")(context)
context.paths = loadLib("Paths")(context)
context.registry = loadLib("Registry")(context)
context.definitionChecker = loadLib("DefinitionChecker")(context)
context.definitionResolver = loadLib("DefinitionResolver")(context)
context.spoonExtractor = loadLib("SpoonExtractor")(context)
context.sourceFetcher = loadLib("SourceFetcher")(context)
context.sourceStage = loadLib("SourceStage")(context)
context.installer = loadLib("Installer")(context)
context.definitionBuilder = loadLib("DefinitionBuilder")(context)

function obj.registerProvider(provider)
    assert(type(provider) == "table", "Provider must be a table")
    assert(type(provider.name) == "string", "Provider requires a name")
    assert(type(provider.createSource) == "function", "Provider requires createSource")

    obj.providers[provider.name] = provider

    local factoryName = provider.factoryName or provider.name
    assert(type(factoryName) == "string", "Provider factory name must be a string")
    assert(obj.from[factoryName] == nil, "Source factory already registered: " .. factoryName)

    obj.from[factoryName] = function(...)
        return context.definitionBuilder.createDefinition({
            source = provider.createSource(...),
        })
    end

    for presetName, presetFactory in pairs(provider.builderPresets or {}) do
        assert(type(presetName) == "string", "Provider builder preset name must be a string")
        assert(type(presetFactory) == "function", "Provider builder preset must be a function")
        assert(obj.from[presetName] == nil, "Source factory already registered: " .. presetName)

        obj.from[presetName] = function(...)
            return presetFactory(obj, ...)
        end
    end

    return provider
end

obj.registerProvider(loadProvider("GitHub")(context))
obj.registerProvider(loadProvider("RemoteZip")(context))
obj.registerProvider(loadProvider("LocalZip")(context))
obj.registerProvider(loadProvider("LocalFolder")(context))

function obj._installDefinition(definition, action)
    return context.installer.installDefinition(definition, action)
end

local function debugInfo(message, definition)
    obj.logger.df(
        "%s: toConfig=%s config=%s resolved=%s command=%s task=%s name=%s\nStacktrace:\n%s",
        message,
        tostring(type(definition) == "table" and definition.toConfig ~= nil),
        tostring(type(definition) == "table" and definition.config ~= nil),
        tostring(type(definition) == "table" and definition.resolved ~= nil),
        tostring(type(definition) == "table" and definition.command ~= nil),
        tostring(type(definition) == "table" and definition.task ~= nil),
        tostring(type(definition) == "table" and definition.name or nil),
        debug.traceback("", 3)
    )
end

local function definitionConfig(definition)
    if definition.toConfig then
        return definition.toConfig()
    end

    if definition.config then
        return Util.copyTable(definition.config)
    end

    return Util.copyTable(definition)
end

local function definitionInstallName(definition)
    if definition.name then
        return definition.name
    end

    if definition.resolved and definition.resolved.installName then
        return definition.resolved.installName
    end

    local state = definition.config and definition or {
        config = definitionConfig(definition),
    }
    local ok, resolved = pcall(context.definitionResolver.resolveFromDefinition, state)
    if ok and resolved then
        return resolved.installName
    end

    return nil
end

function obj._rememberDefinition(definition, installName)
    debugInfo("_rememberDefinition stores config-only definition", definition)
    local config = definitionConfig(definition)
    installName = installName or definitionInstallName(config)

    if installName then
        for index, existing in ipairs(obj.definitions) do
            if definitionInstallName(existing) == installName then
                obj.definitions[index] = config
                return obj
            end
        end
    end

    table.insert(obj.definitions, config)
    return obj
end

local function installAndRememberDefinition(definition, action)
    debugInfo("installAndRememberDefinition passes config-only definition into installer", definition)
    local config = definitionConfig(definition)
    local result, err, prepared = obj._installDefinition(config, action)
    config = prepared or config

    if result then
        obj._rememberDefinition(config, config.task and config.task.name)
    end

    return result, err, config
end

function obj._installAndRememberDefinition(definition, action)
    return withReloadController(
        function()
            return installAndRememberDefinition(definition, action)
        end,
        function(result)
            return result and result.result and not result.result.skipped
        end
    )
end

--- SpoonManager.from.config(config) -> definition
--- Function
--- Create a Spoon definition from a plain Lua table.
function obj.from.config(config)
    return context.definitionBuilder.createDefinition(config)
end

obj.from.default = obj.from.spoonRepoZip("Hammerspoon/Spoons", {
    defaultBranch = "master",
})

--- SpoonManager.add(...) -> SpoonManager
--- Function
--- Add one or more Spoon definitions to the managed definition list.
function obj.add(...)
    local items = { ... }

    for _, definition in ipairs(items) do
        obj._rememberDefinition(definition)
    end

    return obj
end

--- SpoonManager.clear() -> SpoonManager
--- Function
--- Remove all managed definitions.
function obj.clear()
    obj.definitions = {}
    return obj
end

--- SpoonManager.install([...]) -> result
--- Function
--- Install the passed definitions, or all definitions added with `.add()`.
local function runDefinitions(action, ...)
    local passed = { ... }
    local definitions = #passed > 0 and passed or obj.definitions
    local result = {
        success = true,
        action = action,
        installed = {},
        skipped = {},
        errors = {},
    }

    for _, definition in ipairs(definitions) do
        local installed, err = installAndRememberDefinition(definition, action)
        if installed then
            if installed.result and installed.result.skipped then
                table.insert(result.skipped, installed)
            else
                table.insert(result.installed, installed)
            end
        else
            result.success = false
            table.insert(result.errors, {
                name = definitionInstallName(definition),
                error = err,
                definition = definition,
            })
        end
    end

    return result
end

function obj.install(...)
    local definitions = { ... }
    return withReloadController(
        function()
            return runDefinitions("install", table.unpack(definitions))
        end,
        function(result)
            return result and #result.installed > 0
        end
    )
end

--- SpoonManager.update([...]) -> result
--- Function
--- Reinstall managed definitions from their source. Local changes abort by default.
function obj.update(...)
    local definitions = { ... }
    return withReloadController(
        function()
            return runDefinitions("update", table.unpack(definitions))
        end,
        function(result)
            return result and #result.installed > 0
        end
    )
end

local function providerCount()
    local count = 0
    for _ in pairs(obj.providers) do
        count = count + 1
    end

    return count
end

obj.logger.i(string.format("Loaded %s %s with %d source providers", obj.name, obj.version, providerCount()))

return obj
