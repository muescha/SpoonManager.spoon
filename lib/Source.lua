return function(context)
    local Source = {}
    Source.__index = Source

    local definition = context.definition
    local github = context.github
    local manager = context.manager
    local name = context.name
    local util = context.util

    local function substitutePattern(pattern, spoonName)
        return (pattern:gsub("{name}", spoonName))
    end

    local function fromState(state)
        local source = util.copyTable(state)
        local api = {}

        local function rootDefinition()
            return definition.fromState({
                name = name.inferFromSource(source),
                source = util.mergeTables(source, {
                    type = source.type == "github" and "github-repository" or source.type,
                }),
            })
        end

        api.build = function()
            return util.copyTable(source)
        end

        api.branch = function(branchName)
            local nextSource = util.copyTable(source)
            nextSource.ref = branchName
            return fromState(nextSource)
        end

        api.ref = api.branch

        api.spoonZipPattern = function(pattern)
            local nextSource = util.copyTable(source)
            nextSource.spoonZipPattern = pattern
            return fromState(nextSource)
        end

        api.spoonFolderPattern = function(pattern)
            local nextSource = util.copyTable(source)
            nextSource.spoonFolderPattern = pattern
            return fromState(nextSource)
        end

        api.spoon = function(value)
            local spoonName = name.infer(value, "Spoon name")
            assert(spoonName, "Invalid Spoon name")

            if source.spoonZipPattern then
                return definition.fromState({
                    name = spoonName,
                    source = {
                        type = "zip",
                        url = github.rawUrl(source, substitutePattern(source.spoonZipPattern, spoonName)),
                        origin = source,
                    },
                })
            end

            if source.spoonFolderPattern then
                return api.folder(substitutePattern(source.spoonFolderPattern, spoonName)).asSpoon(spoonName)
            end

            return definition.fromState({
                name = spoonName,
                source = util.mergeTables(source, {
                    type = source.type == "github" and "github-repository" or source.type,
                }),
            })
        end

        api.folder = function(path)
            if source.type == "local-folder" then
                return definition.fromState({
                    name = name.infer(path, "local folder path"),
                    source = {
                        type = "local-folder",
                        path = util.pathJoin(source.path, path),
                        origin = source,
                    },
                })
            end

            return definition.fromState({
                name = name.infer(path, "folder path"),
                source = util.mergeTables(source, {
                    type = source.type == "github" and "github-folder" or "folder",
                    path = path,
                }),
            })
        end

        api.releaseLatest = function()
            local nextSource = util.copyTable(source)
            nextSource.type = "github-release"
            nextSource.release = "latest"
            return fromState(nextSource)
        end

        api.release = function(releaseName)
            local nextSource = util.copyTable(source)
            nextSource.type = "github-release"
            nextSource.release = releaseName
            return fromState(nextSource)
        end

        api.asset = function(assetName)
            local nextSource = util.copyTable(source)
            nextSource.asset = assetName
            return definition.fromState({
                name = name.infer(assetName, "asset name"),
                source = nextSource,
            })
        end

        api.asSpoon = function(value)
            local explicitName = name.infer(value, "explicit Spoon name")
            name.logExplicit(explicitName, value)

            return definition.fromState({
                name = explicitName,
                source = util.mergeTables(source, {
                    type = source.type == "github" and "github-repository" or source.type,
                }),
            })
        end

        api.use = function(useOptions)
            return rootDefinition().use(useOptions)
        end

        api.onLocalChanges = function(behavior)
            return rootDefinition().onLocalChanges(behavior)
        end

        api.add = function()
            return rootDefinition().add()
        end

        api.install = function()
            return rootDefinition().install()
        end

        api.update = function()
            return rootDefinition().update()
        end

        return setmetatable(api, Source)
    end

    return {
        fromState = fromState,
    }
end
