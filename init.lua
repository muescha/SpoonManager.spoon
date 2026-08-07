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
---  * `localChanges.abort`
---  * `localChanges.backup`
---  * `localChanges.overwrite`
---  * `patterns.spoonRepo`
---  * `patterns.spoonRepoZip`
obj.options = {
    localChanges = {
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
    onLocalChanges = obj.options.localChanges.abort,
}

function obj._isLocalChangesBehavior(behavior)
    for _, value in pairs(obj.options.localChanges) do
        if behavior == value then
            return true
        end
    end

    return false
end

--- SpoonManager.onLocalChanges(behavior) -> SpoonManager
--- Function
--- Set the default behavior for existing or locally changed Spoons.
function obj.onLocalChanges(behavior)
    assert(obj._isLocalChangesBehavior(behavior), "Invalid local changes behavior: " .. tostring(behavior))

    obj.installOptions.onLocalChanges = behavior
    return obj
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
context.resolver = loadLib("Resolver")(context)
context.archive = loadLib("Archive")(context)
context.installer = loadLib("Installer")(context)
context.definition = loadLib("Definition")(context)

function obj.registerProvider(provider)
    assert(type(provider) == "table", "Provider must be a table")
    assert(type(provider.name) == "string", "Provider requires a name")
    assert(type(provider.createSource) == "function", "Provider requires createSource")

    obj.providers[provider.name] = provider

    local factoryName = provider.factoryName or provider.name
    assert(type(factoryName) == "string", "Provider factory name must be a string")
    assert(obj.from[factoryName] == nil, "Source factory already registered: " .. factoryName)

    obj.from[factoryName] = function(...)
        return context.definition.createDefinition({
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
    local ok, resolved = pcall(context.resolver.resolveFromDefinition, state)
    if ok and resolved then
        return resolved.installName
    end

    return nil
end

function obj._rememberDefinition(definition, installName)
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

function obj._installAndRememberDefinition(definition, action)
    local config = definitionConfig(definition)
    local result, err, prepared = obj._installDefinition(config, action)
    config = prepared or config

    if result then
        obj._rememberDefinition(config, result.name)
    end

    return result, err, config
end

--- SpoonManager.from.config(config) -> definition
--- Function
--- Create a Spoon definition from a plain Lua table.
function obj.from.config(config)
    return context.definition.createDefinition(config)
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
        local installed, err = obj._installAndRememberDefinition(definition, action)
        if installed then
            if installed.skipped then
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
    return runDefinitions("install", ...)
end

--- SpoonManager.update([...]) -> result
--- Function
--- Reinstall managed definitions from their source. Local changes abort by default.
function obj.update(...)
    return runDefinitions("update", ...)
end

return obj
