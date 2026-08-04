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

obj.installOptions = {
    onLocalChanges = "abort",
}

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

context.name = loadLib("Name")(context)
context.paths = loadLib("Paths")(context)
context.registry = loadLib("Registry")(context)
context.archive = loadLib("Archive")(context)
context.installer = loadLib("Installer")(context)
context.definition = loadLib("Definition")(context)
context.source = loadLib("Source")(context)

function obj._installDefinition(definition, action)
    return context.installer.installDefinition(definition, action)
end

--- SpoonManager.from.zip(url) -> definition
--- Function
--- Create a Spoon definition from a remote zip URL.
function obj.from.zip(url)
    return context.definition.fromState({
        name = context.name.infer(url, "URL"),
        source = {
            type = "zip",
            url = url,
        },
    })
end

--- SpoonManager.from.localZip(path) -> definition
--- Function
--- Create a Spoon definition from a local zip file.
function obj.from.localZip(path)
    path = Util.localPath(path)

    return context.definition.fromState({
        name = context.name.infer(path, "local zip path"),
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
        name = context.name.infer(path, "local folder path"),
        source = {
            type = "local-folder",
            path = path,
        },
    })
end

--- SpoonManager.from.github(repository[, options]) -> source
--- Function
--- Create a GitHub source.
function obj.from.github(repository, options)
    options = options or {}
    return context.source.fromState({
        type = "github",
        provider = "github",
        repository = repository,
        name = context.name.infer(repository, "repository"),
        ref = options.ref or options.branch or "main",
        baseUrl = options.baseUrl or "https://github.com",
    })
end

--- SpoonManager.add(...) -> SpoonManager
--- Function
--- Add one or more Spoon definitions to the managed definition list.
function obj.add(...)
    local definitions = { ... }

    for _, definition in ipairs(definitions) do
        if definition.build then
            table.insert(obj.definitions, definition.build())
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
        local installed, err = obj._installDefinition(definition.build and definition.build() or definition, action)
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
