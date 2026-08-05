return function(context)
    local Definition = {}
    Definition.__index = Definition

    local github = context.github
    local manager = context.manager
    local nameResolver = context.nameResolver
    local util = context.util

    local function substitutePattern(pattern, spoonName)
        return (pattern:gsub("{name}", spoonName))
    end

    local function ensureBuilder(definition)
        definition._builder = util.mergeTables({
            used = {},
        }, definition._builder or {})

        definition._builder.used = definition._builder.used or {}
        return definition._builder
    end

    local function markUsed(definition, group, method, value)
        local builder = ensureBuilder(definition)
        local nextLabel = util.createLabel(method, value)
        local previousLabel = builder.used[group]

        if previousLabel then
            error(string.format(
                "Cannot call %s; %s was already set by %s. Start from the base definition instead.",
                nextLabel,
                group,
                previousLabel
            ), 3)
        end

        builder.used[group] = nextLabel
    end

    local function setInferredName(definition, inferredName)
        definition.inferredName = inferredName

        if not definition.explicitName then
            definition.name = inferredName
        end
    end

    local function setExplicitName(definition, explicitName)
        definition.explicitName = explicitName
        definition.name = explicitName
    end

    local function inferUsedFromConfig(definition)
        local source = definition.source or {}
        local builder = ensureBuilder(definition)
        local used = builder.used

        if source.branch and not used.revision then
            used.revision = util.createLabel("branch", source.branch)
        elseif source.ref and not used.revision then
            used.revision = util.createLabel("ref", source.ref)
        end

        if source.spoonZipPattern and not used.spoonPattern then
            used.spoonPattern = util.createLabel("spoonZipPattern", source.spoonZipPattern)
        elseif source.spoonFolderPattern and not used.spoonPattern then
            used.spoonPattern = util.createLabel("spoonFolderPattern", source.spoonFolderPattern)
        end

        if source.release and not used.release then
            if source.release == "latest" then
                used.release = util.createLabel("releaseLatest")
            else
                used.release = util.createLabel("release", source.release)
            end
        end

        if source.asset and not used.selection then
            used.selection = util.createLabel("asset", source.asset)
        elseif source.path and not used.selection then
            used.selection = util.createLabel("folder", source.path)
        elseif source.url and not used.selection then
            used.selection = util.createLabel("remoteZip", source.url)
        end

        if definition.explicitName and not used.targetName then
            used.targetName = util.createLabel("withName", definition.explicitName)
        end
    end

    local function fromState(state, inferMissingBuilder)
        local def = util.copyTable(state)
        if inferMissingBuilder and not def._builder then
            inferUsedFromConfig(def)
        else
            ensureBuilder(def)
        end

        local api = {}

        api.toConfig = function()
            return util.copyTable(def)
        end

        api.branch = function(branchName)
            util.requireString(branchName, "Branch name")

            local nextDef = util.copyTable(def)
            nextDef.source = util.copyTable(nextDef.source or {})
            markUsed(nextDef, "revision", "branch", branchName)
            nextDef.source.branch = branchName
            nextDef.source.ref = nil
            return fromState(nextDef)
        end

        api.ref = function(refName)
            util.requireString(refName, "Ref name")

            local nextDef = util.copyTable(def)
            nextDef.source = util.copyTable(nextDef.source or {})
            markUsed(nextDef, "revision", "ref", refName)
            nextDef.source.ref = refName
            nextDef.source.branch = nil
            return fromState(nextDef)
        end

        api.spoonZipPattern = function(pattern)
            util.requireZipPath(pattern, "Spoon ZIP pattern")

            local nextDef = util.copyTable(def)
            nextDef.source = util.copyTable(nextDef.source or {})
            markUsed(nextDef, "spoonPattern", "spoonZipPattern", pattern)
            nextDef.source.spoonZipPattern = pattern
            return fromState(nextDef)
        end

        api.spoonFolderPattern = function(pattern)
            util.requireString(pattern, "Spoon folder pattern")

            local nextDef = util.copyTable(def)
            nextDef.source = util.copyTable(nextDef.source or {})
            markUsed(nextDef, "spoonPattern", "spoonFolderPattern", pattern)
            nextDef.source.spoonFolderPattern = pattern
            return fromState(nextDef)
        end

        api.spoon = function(value)
            util.requireString(value, "Spoon name")

            local spoonName = nameResolver.infer(value, "Spoon name")
            assert(spoonName, "Invalid Spoon name")

            local source = def.source or {}
            local nextDef = util.copyTable(def)
            markUsed(nextDef, "selection", "spoon", value)
            setInferredName(nextDef, spoonName)

            if source.spoonZipPattern then
                local nextSource = {
                    type = "remote-zip",
                    url = github.rawUrl(source, substitutePattern(source.spoonZipPattern, spoonName)),
                    origin = source,
                }

                return fromState(util.mergeTables(nextDef, {
                    source = nextSource,
                }))
            end

            if source.spoonFolderPattern then
                local nextSource = {
                    type = source.provider == "github" and "github-folder" or "folder",
                    path = substitutePattern(source.spoonFolderPattern, spoonName),
                    origin = source,
                }

                return fromState(util.mergeTables(nextDef, {
                    source = nextSource,
                }))
            end

            return fromState(nextDef)
        end

        api.folder = function(path)
            util.requireString(path, "Folder path")

            local source = def.source or {}
            local nextSource
            local inferredFrom

            if source.type == "local-folder" then
                nextSource = {
                    type = "local-folder",
                    path = util.pathJoin(source.path, path),
                    origin = source,
                }
                inferredFrom = "local folder path"
            else
                nextSource = util.mergeTables(source, {
                    type = source.provider == "github" and "github-folder" or "folder",
                    path = path,
                })
                inferredFrom = "folder path"
            end

            local nextDef = util.copyTable(def)
            markUsed(nextDef, "selection", "folder", path)
            setInferredName(nextDef, nameResolver.infer(path, inferredFrom))

            return fromState(util.mergeTables(nextDef, {
                source = nextSource,
            }))
        end

        api.releaseLatest = function()
            local nextDef = util.copyTable(def)
            markUsed(nextDef, "release", "releaseLatest")
            nextDef.source = util.mergeTables(nextDef.source or {}, {
                type = "github-release",
                release = "latest",
            })
            return fromState(nextDef)
        end

        api.release = function(releaseName)
            util.requireString(releaseName, "Release name")

            local nextDef = util.copyTable(def)
            markUsed(nextDef, "release", "release", releaseName)
            nextDef.source = util.mergeTables(nextDef.source or {}, {
                type = "github-release",
                release = releaseName,
            })
            return fromState(nextDef)
        end

        api.asset = function(assetName)
            util.requireZipPath(assetName, "Release asset")

            local nextDef = util.copyTable(def)
            markUsed(nextDef, "selection", "asset", assetName)
            setInferredName(nextDef, nameResolver.infer(assetName, "asset name"))
            nextDef.source = util.mergeTables(nextDef.source or {}, {
                asset = assetName,
            })
            return fromState(nextDef)
        end

        api.withName = function(value)
            util.requireString(value, "Spoon name")

            local nextDef = util.copyTable(def)
            markUsed(nextDef, "targetName", "withName", value)
            setExplicitName(nextDef, nameResolver.infer(value, "explicit Spoon name"))
            nameResolver.logExplicit(nextDef.name, value)
            return fromState(nextDef)
        end

        api.use = function(useOptions)
            local nextDef = util.copyTable(def)
            nextDef.use = util.mergeTables(nextDef.use or {}, useOptions or {})
            return fromState(nextDef)
        end

        api.onLocalChanges = function(behavior)
            assert(manager._isLocalChangesBehavior(behavior), "Invalid local changes behavior: " .. tostring(behavior))

            local nextDef = util.copyTable(def)
            markUsed(nextDef, "localChanges", "onLocalChanges", behavior)
            nextDef.options = util.mergeTables(nextDef.options or {}, { onLocalChanges = behavior })
            return fromState(nextDef)
        end

        api.add = function()
            manager.add(api)
            return api
        end

        api.install = function()
            return manager._installDefinition(def, "install")
        end

        api.update = function()
            return manager._installDefinition(def, "update")
        end

        return setmetatable(api, Definition)
    end

    return {
        fromState = fromState,
    }
end
