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
---     .folder("Source/MySpoon.spoon")
---     .asSpoon("MySpoon")
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
obj.definitions = {}

--- SpoonManager.options
--- Variable
--- Public constants used by the builder API.
---
--- Contains:
---  * `localChanges.abort`
---  * `localChanges.backup`
---  * `localChanges.overwrite`
obj.options = {
    localChanges = {
        abort = "abort",
        backup = "backup",
        overwrite = "overwrite",
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

local Util = loadLib("Util")
local GitHub = loadLib("GitHub")

obj.configDir = Util.pathJoin(hs.configdir, ".config", "SpoonManager")

local context = {
    github = GitHub,
    logger = obj.logger,
    manager = obj,
    util = Util,
}

context.nameResolver = loadLib("NameResolver")(context)
context.paths = loadLib("Paths")(context)
context.registry = loadLib("Registry")(context)
context.archive = loadLib("Archive")(context)
context.installer = loadLib("Installer")(context)
context.definition = loadLib("Definition")(context)

function obj._installDefinition(definition, action)
    return context.installer.installDefinition(definition, action)
end

--- SpoonManager.from.config(config) -> definition
--- Function
--- Create a Spoon definition from a plain Lua table.
function obj.from.config(config)
    return context.definition.fromState(config)
end

--- SpoonManager.from.remoteZip(url) -> definition
--- Function
--- Create a Spoon definition from a remote zip URL.
function obj.from.remoteZip(url)
    Util.requireZipPath(url, "Remote ZIP URL")

    return context.definition.fromState({
        name = context.nameResolver.infer(url, "URL"),
        source = {
            type = "remote-zip",
            url = url,
        },
    })
end

--- SpoonManager.from.localZip(path) -> definition
--- Function
--- Create a Spoon definition from a local zip file.
function obj.from.localZip(path)
    path = Util.localPath(path)
    Util.requireZipPath(path, "Local ZIP path")

    return context.definition.fromState({
        name = context.nameResolver.infer(path, "local zip path"),
        source = {
            type = "local-zip",
            path = path,
        },
    })
end

--- SpoonManager.from.localFolder(path) -> definition
--- Function
--- Create a Spoon definition from a local folder.
function obj.from.localFolder(path)
    path = Util.localPath(path)

    return context.definition.fromState({
        name = context.nameResolver.infer(path, "local folder path"),
        source = {
            type = "local-folder",
            path = path,
        },
    })
end

--- SpoonManager.from.github(repository[, options]) -> definition
--- Function
--- Create a GitHub repository definition.
function obj.from.github(repository, options)
    options = options or {}
    return context.definition.fromState({
        name = context.nameResolver.infer(repository, "repository"),
        source = {
            type = "github-repository",
            provider = "github",
            repository = repository,
            ref = options.ref or options.branch or "main",
            baseUrl = options.baseUrl or "https://github.com",
        },
    })
end

--- SpoonManager.add(...) -> SpoonManager
--- Function
--- Add one or more Spoon definitions to the managed definition list.
function obj.add(...)
    local items = { ... }

    for _, definition in ipairs(items) do
        if definition.toConfig then
            table.insert(obj.definitions, definition.toConfig())
        else
            table.insert(obj.definitions, Util.copyTable(definition))
        end
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
        local installed, err = obj._installDefinition(definition.toConfig and definition.toConfig() or definition, action)
        if installed then
            if installed.skipped then
                table.insert(result.skipped, installed)
            else
                table.insert(result.installed, installed)
            end
        else
            result.success = false
            table.insert(result.errors, {
                name = definition.name,
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

obj.from.default = obj.from.github("Hammerspoon/Spoons", {
    branch = "master",
}).spoonZipPattern("Spoons/{name}.spoon.zip")

return obj
