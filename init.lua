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

local function shellQuote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function pathJoin(...)
    local parts = { ... }
    local path = table.concat(parts, "/")
    path = path:gsub("/+", "/")
    return path
end

local function localPath(path)
    if hs.fs.pathToAbsolute then
        return hs.fs.pathToAbsolute(path) or path
    end

    return path
end

local function copyTable(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}
    for key, child in pairs(value) do
        result[key] = copyTable(child)
    end
    return result
end

local function mergeTables(base, extra)
    local result = copyTable(base or {})
    for key, value in pairs(extra or {}) do
        result[key] = copyTable(value)
    end
    return result
end

local function execute(command, errfmt, ...)
    local output, ok = hs.execute(command)
    if ok then
        return trim(output), true
    end

    obj.logger.ef(errfmt or "Command failed: %s", ...)
    if output and output ~= "" then
        obj.logger.ef("%s", output)
    end
    return nil, false
end

local function ensureDir(path)
    return execute(
        "/bin/mkdir -p " .. shellQuote(path),
        "Could not create directory %s",
        path
    )
end

local function removePath(path)
    return execute(
        "/bin/rm -rf " .. shellQuote(path),
        "Could not remove %s",
        path
    )
end

local function copyPath(source, destination)
    removePath(destination)
    return execute(
        "/bin/cp -R " .. shellQuote(source) .. " " .. shellQuote(destination),
        "Could not copy %s to %s",
        source,
        destination
    )
end

local function movePath(source, destination)
    removePath(destination)
    return execute(
        "/bin/mv " .. shellQuote(source) .. " " .. shellQuote(destination),
        "Could not move %s to %s",
        source,
        destination
    )
end

local function fileExists(path)
    return hs.fs.attributes(path) ~= nil
end

local function safeName(name)
    if not name or name == "" then
        return nil
    end

    name = tostring(name):gsub("%.spoon$", "")
    if name:find("[/\\]") or name:find("%.%.", 1, true) then
        return nil
    end

    return name
end

local function inferSpoonNameFromPath(path)
    if not path then
        return nil
    end

    local last = path:gsub("/+$", ""):match("([^/]+)$")
    return safeName(last)
end

local function substitutePattern(pattern, name)
    return (pattern:gsub("{name}", name))
end

local function githubArchiveUrl(source)
    local ref = source.ref or "main"
    return string.format(
        "%s/%s/archive/refs/heads/%s.zip",
        source.baseUrl or "https://github.com",
        source.repository,
        ref
    )
end

local function githubRawUrl(source, path)
    local ref = source.ref or "main"
    return string.format(
        "%s/%s/raw/%s/%s",
        source.baseUrl or "https://github.com",
        source.repository,
        ref,
        path
    )
end

local function githubReleaseAssetUrl(source)
    local release = source.release or "latest"
    local releasePath = release == "latest" and "latest" or "download/" .. release

    if release == "latest" then
        return string.format(
            "%s/%s/releases/latest/download/%s",
            source.baseUrl or "https://github.com",
            source.repository,
            source.asset
        )
    end

    return string.format(
        "%s/%s/releases/%s/%s",
        source.baseUrl or "https://github.com",
        source.repository,
        releasePath,
        source.asset
    )
end

local function downloadToFile(url, destination)
    local status, body = hs.http.get(url)
    if status < 100 or status >= 400 then
        return nil, string.format("Download failed with HTTP status %s for %s", tostring(status), url)
    end

    local file, err = io.open(destination, "wb")
    if not file then
        return nil, err
    end

    file:write(body)
    file:close()
    return true
end

local function checksumDirectory(path)
    if not fileExists(path) then
        return nil
    end

    local command = table.concat({
        "/usr/bin/find",
        shellQuote(path),
        "-type f",
        "! -name .DS_Store",
        "-print0",
        "|",
        "/usr/bin/xargs -0 /usr/bin/shasum -a 256",
        "|",
        "/usr/bin/shasum -a 256",
        "|",
        "/usr/bin/awk '{ print $1 }'",
    }, " ")

    return execute(command, "Could not checksum %s", path)
end

local function registryPath()
    return pathJoin(hs.configdir, "SpoonManager", "installed.json")
end

local function readRegistry()
    local path = registryPath()
    if not fileExists(path) then
        return {}
    end

    return hs.json.read(path) or {}
end

local function writeRegistry(registry)
    local path = registryPath()
    ensureDir(path:match("^(.*)/[^/]+$"))

    local file, err = io.open(path, "w")
    if not file then
        return nil, err
    end

    file:write(hs.json.encode(registry, true))
    file:close()
    return true
end

local function installRoot()
    return pathJoin(hs.configdir, "Spoons")
end

local function targetPath(name)
    return pathJoin(installRoot(), name .. ".spoon")
end

local function normalizeDefinition(definition)
    local def = copyTable(definition)
    def.options = mergeTables(obj.installOptions, def.options or {})
    def.name = safeName(def.name or inferSpoonNameFromPath(def.source and def.source.path))
    return def
end

local function validateDefinition(definition)
    if type(definition) ~= "table" then
        return nil, "Spoon definition must be a table"
    end

    if not definition.source or not definition.source.type then
        return nil, "Spoon definition requires a source"
    end

    if not definition.name then
        return nil, "Spoon definition requires a Spoon name. Add .asSpoon(\"Name\")."
    end

    return true
end

local function validateInstalledFolder(path)
    if not fileExists(pathJoin(path, "init.lua")) then
        return nil, "Installed folder does not contain init.lua"
    end

    return true
end

local function prepareZipSelection(definition)
    local source = definition.source
    local selection = {}

    if source.type == "github-folder" then
        selection.path = source.path
    elseif source.type == "github-repository" then
        selection.path = nil
    end

    return selection
end

local function extractZipToSpoon(zipFile, definition, tmpdir)
    local extractDir = pathJoin(tmpdir, "extract")
    ensureDir(extractDir)

    local source = definition.source
    local selection = prepareZipSelection(definition)
    local unzipCommand

    if selection.path then
        local pattern = "*/" .. selection.path:gsub("^/+", "") .. "/*"
        unzipCommand = "/usr/bin/unzip -q " .. shellQuote(zipFile) .. " " .. shellQuote(pattern) .. " -d " .. shellQuote(extractDir) .. " 2>&1"
    else
        unzipCommand = "/usr/bin/unzip -q " .. shellQuote(zipFile) .. " -d " .. shellQuote(extractDir) .. " 2>&1"
    end

    local _, ok = execute(unzipCommand, "Could not extract %s", zipFile)
    if not ok then
        return nil, "Could not extract zip"
    end

    local sourceFolder
    if selection.path then
        sourceFolder = execute(
            "/usr/bin/find " .. shellQuote(extractDir) .. " -type d -path " .. shellQuote("*/" .. selection.path) .. " -print -quit",
            "Could not locate extracted folder %s",
            selection.path
        )
    else
        sourceFolder = execute(
            "/usr/bin/find " .. shellQuote(extractDir) .. " -mindepth 1 -maxdepth 2 -type f -name init.lua -print -quit",
            "Could not locate init.lua in %s",
            zipFile
        )

        if sourceFolder and sourceFolder ~= "" then
            sourceFolder = sourceFolder:gsub("/init%.lua$", "")
        end
    end

    if not sourceFolder or sourceFolder == "" then
        return nil, "Could not locate Spoon folder in archive"
    end

    local okInstall, err = validateInstalledFolder(sourceFolder)
    if not okInstall then
        return nil, err
    end

    return sourceFolder
end

local function checkLocalChanges(definition, destination)
    local registry = readRegistry()
    local installed = registry[definition.name]

    if not fileExists(destination) then
        return true
    end

    local behavior = definition.options.onLocalChanges or "abort"

    if not installed or not installed.checksum then
        if behavior == "overwrite" then
            return true
        end

        if behavior == "backup" then
            local backupPath = destination .. ".backup-" .. os.date("!%Y%m%dT%H%M%SZ")
            local _, ok = movePath(destination, backupPath)
            if ok then
                return true
            end
            return nil, "Could not backup existing unmanaged Spoon"
        end

        return nil, "Spoon already exists but is not managed by SpoonManager. Use .onLocalChanges(\"backup\") or .onLocalChanges(\"overwrite\") to install anyway."
    end

    local currentChecksum = checksumDirectory(destination)
    if currentChecksum == installed.checksum then
        return true
    end

    if behavior == "overwrite" then
        return true
    end

    if behavior == "backup" then
        local backupPath = destination .. ".backup-" .. os.date("!%Y%m%dT%H%M%SZ")
        local _, ok = movePath(destination, backupPath)
        if ok then
            return true
        end
        return nil, "Could not backup locally changed Spoon"
    end

    return nil, "Local changes detected. Use .onLocalChanges(\"backup\") or .onLocalChanges(\"overwrite\") to update anyway."
end

local function persistInstall(definition, destination)
    local registry = readRegistry()
    registry[definition.name] = {
        name = definition.name,
        installedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        path = destination,
        checksum = checksumDirectory(destination),
        source = definition.source,
        use = definition.use,
    }

    return writeRegistry(registry)
end

local function applyUse(definition)
    if not definition.use then
        return true
    end

    local arg = copyTable(definition.use)
    arg.disable = nil
    return hs.spoons.use(definition.name, arg, false)
end

local function installFromFolder(definition, sourceFolder)
    local destination = targetPath(definition.name)
    ensureDir(installRoot())

    local ok, err = checkLocalChanges(definition, destination)
    if not ok then
        return nil, err
    end

    local valid, validationError = validateInstalledFolder(sourceFolder)
    if not valid then
        return nil, validationError
    end

    local _, copied = copyPath(sourceFolder, destination)
    if not copied then
        return nil, "Could not install Spoon folder"
    end

    persistInstall(definition, destination)
    applyUse(definition)

    return {
        success = true,
        name = definition.name,
        path = destination,
        source = definition.source,
        use = definition.use,
    }
end

local function installFromZipFile(definition, zipFile, tmpdir)
    local sourceFolder, err = extractZipToSpoon(zipFile, definition, tmpdir)
    if not sourceFolder then
        return nil, err
    end

    return installFromFolder(definition, sourceFolder)
end

local function installFromRemoteZip(definition, url)
    local tmpdir = trim(hs.execute("/usr/bin/mktemp -d"))
    if not tmpdir or tmpdir == "" then
        return nil, "Could not create temporary directory"
    end

    local zipFile = pathJoin(tmpdir, "download.zip")
    local ok, err = downloadToFile(url, zipFile)
    if not ok then
        removePath(tmpdir)
        return nil, err
    end

    local result, installErr = installFromZipFile(definition, zipFile, tmpdir)
    removePath(tmpdir)
    return result, installErr
end

function obj._installDefinition(definition)
    local def = normalizeDefinition(definition)
    local valid, validationError = validateDefinition(def)
    if not valid then
        return nil, validationError
    end

    local source = def.source

    if source.type == "local-folder" then
        return installFromFolder(def, source.path)
    end

    if source.type == "local-zip" then
        local tmpdir = trim(hs.execute("/usr/bin/mktemp -d"))
        local result, err = installFromZipFile(def, source.path, tmpdir)
        removePath(tmpdir)
        return result, err
    end

    if source.type == "zip" then
        return installFromRemoteZip(def, source.url)
    end

    if source.type == "github-release" then
        return installFromRemoteZip(def, githubReleaseAssetUrl(source))
    end

    if source.type == "github-folder" or source.type == "github-repository" then
        return installFromRemoteZip(def, githubArchiveUrl(source))
    end

    return nil, "Unsupported source type: " .. tostring(source.type)
end

local Definition = {}
Definition.__index = Definition

local function definitionFromState(state)
    local def = copyTable(state)
    local api = {}

    api.build = function()
        return copyTable(def)
    end

    api.asSpoon = function(name)
        local nextDef = copyTable(def)
        nextDef.name = safeName(name)
        return definitionFromState(nextDef)
    end

    api.use = function(useOptions)
        local nextDef = copyTable(def)
        nextDef.use = mergeTables(nextDef.use or {}, useOptions or {})
        return definitionFromState(nextDef)
    end

    api.onLocalChanges = function(behavior)
        local nextDef = copyTable(def)
        nextDef.options = mergeTables(nextDef.options or {}, { onLocalChanges = behavior })
        return definitionFromState(nextDef)
    end

    api.add = function()
        obj.add(api)
        return api
    end

    api.install = function()
        return obj._installDefinition(def)
    end

    return setmetatable(api, Definition)
end

local Source = {}
Source.__index = Source

local function sourceFromState(state)
    local source = copyTable(state)
    local api = {}

    api.build = function()
        return copyTable(source)
    end

    api.branch = function(branchName)
        local nextSource = copyTable(source)
        nextSource.ref = branchName
        return sourceFromState(nextSource)
    end

    api.ref = api.branch

    api.spoonZipPattern = function(pattern)
        local nextSource = copyTable(source)
        nextSource.spoonZipPattern = pattern
        return sourceFromState(nextSource)
    end

    api.spoonFolderPattern = function(pattern)
        local nextSource = copyTable(source)
        nextSource.spoonFolderPattern = pattern
        return sourceFromState(nextSource)
    end

    api.spoon = function(name)
        local spoonName = safeName(name)
        assert(spoonName, "Invalid Spoon name")

        if source.spoonZipPattern then
            return definitionFromState({
                name = spoonName,
                source = {
                    type = "zip",
                    url = githubRawUrl(source, substitutePattern(source.spoonZipPattern, spoonName)),
                    origin = source,
                },
            })
        end

        if source.spoonFolderPattern then
            return api.folder(substitutePattern(source.spoonFolderPattern, spoonName)).asSpoon(spoonName)
        end

        return definitionFromState({
            name = spoonName,
            source = mergeTables(source, {
                type = source.type == "github" and "github-repository" or source.type,
            }),
        })
    end

    api.folder = function(path)
        if source.type == "local-folder" then
            return definitionFromState({
                name = inferSpoonNameFromPath(path),
                source = {
                    type = "local-folder",
                    path = pathJoin(source.path, path),
                    origin = source,
                },
            })
        end

        return definitionFromState({
            name = inferSpoonNameFromPath(path),
            source = mergeTables(source, {
                type = source.type == "github" and "github-folder" or "folder",
                path = path,
            }),
        })
    end

    api.releaseLatest = function()
        local nextSource = copyTable(source)
        nextSource.type = "github-release"
        nextSource.release = "latest"
        return sourceFromState(nextSource)
    end

    api.release = function(releaseName)
        local nextSource = copyTable(source)
        nextSource.type = "github-release"
        nextSource.release = releaseName
        return sourceFromState(nextSource)
    end

    api.asset = function(assetName)
        local nextSource = copyTable(source)
        nextSource.asset = assetName
        return definitionFromState({
            name = inferSpoonNameFromPath(assetName),
            source = nextSource,
        })
    end

    api.asSpoon = function(name)
        return definitionFromState({
            name = safeName(name),
            source = mergeTables(source, {
                type = source.type == "github" and "github-repository" or source.type,
            }),
        })
    end

    return setmetatable(api, Source)
end

--- SpoonManager.from.zip(url) -> definition
--- Function
--- Create a Spoon definition from a remote zip URL.
function obj.from.zip(url)
    return definitionFromState({
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
    return definitionFromState({
        source = {
            type = "local-zip",
            path = localPath(path),
        },
    })
end

--- SpoonManager.from.localFolder(path) -> definition
--- Function
--- Create a Spoon definition from a local folder.
function obj.from.localFolder(path)
    path = localPath(path)

    return definitionFromState({
        name = inferSpoonNameFromPath(path),
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
    return sourceFromState({
        type = "github",
        provider = "github",
        repository = repository,
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
            table.insert(obj.definitions, copyTable(definition))
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
function obj.install(...)
    local passed = { ... }
    local definitions = #passed > 0 and passed or obj.definitions
    local result = {
        success = true,
        installed = {},
        errors = {},
    }

    for _, definition in ipairs(definitions) do
        local installed, err = obj._installDefinition(definition.build and definition.build() or definition)
        if installed then
            table.insert(result.installed, installed)
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

--- SpoonManager.update([...]) -> result
--- Function
--- Reinstall managed definitions using their stored source. Local changes abort by default.
function obj.update(...)
    return obj.install(...)
end

obj.from.internal = obj.from.github("Hammerspoon/Spoons", {
    branch = "master",
}).spoonZipPattern("Spoons/{name}.spoon.zip")

obj.from.default = obj.from.internal

return obj
