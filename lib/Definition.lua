return function(context)
    local Definition = {}
    Definition.__index = Definition

    local github = context.github
    local manager = context.manager
    local name = context.name
    local util = context.util

    local function substitutePattern(pattern, spoonName)
        return (pattern:gsub("{name}", spoonName))
    end

    local function fromState(state)
        local def = util.copyTable(state)
        local api = {}

        api.toConfig = function()
            return util.copyTable(def)
        end

        api.branch = function(branchName)
            local nextDef = util.copyTable(def)
            nextDef.source = util.copyTable(nextDef.source or {})
            nextDef.source.ref = branchName
            return fromState(nextDef)
        end

        api.ref = api.branch

        api.spoonZipPattern = function(pattern)
            util.requireZipPath(pattern, "Spoon ZIP pattern")

            local nextDef = util.copyTable(def)
            nextDef.source = util.copyTable(nextDef.source or {})
            nextDef.source.spoonZipPattern = pattern
            return fromState(nextDef)
        end

        api.spoonFolderPattern = function(pattern)
            local nextDef = util.copyTable(def)
            nextDef.source = util.copyTable(nextDef.source or {})
            nextDef.source.spoonFolderPattern = pattern
            return fromState(nextDef)
        end

        api.spoon = function(value)
            local spoonName = name.infer(value, "Spoon name")
            assert(spoonName, "Invalid Spoon name")

            local source = def.source or {}

            if source.spoonZipPattern then
                local nextSource = {
                    type = "zip",
                    url = github.rawUrl(source, substitutePattern(source.spoonZipPattern, spoonName)),
                    origin = source,
                }

                return fromState(util.mergeTables(def, {
                    name = spoonName,
                    source = nextSource,
                }))
            end

            if source.spoonFolderPattern then
                return api.folder(substitutePattern(source.spoonFolderPattern, spoonName)).asSpoon(spoonName)
            end

            return fromState(util.mergeTables(def, {
                name = spoonName,
            }))
        end

        api.folder = function(path)
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

            return fromState(util.mergeTables(def, {
                name = name.infer(path, inferredFrom),
                source = nextSource,
            }))
        end

        api.releaseLatest = function()
            local nextDef = util.copyTable(def)
            nextDef.source = util.mergeTables(nextDef.source or {}, {
                type = "github-release",
                release = "latest",
            })
            return fromState(nextDef)
        end

        api.release = function(releaseName)
            local nextDef = util.copyTable(def)
            nextDef.source = util.mergeTables(nextDef.source or {}, {
                type = "github-release",
                release = releaseName,
            })
            return fromState(nextDef)
        end

        api.asset = function(assetName)
            util.requireZipPath(assetName, "Release asset")

            local nextDef = util.copyTable(def)
            nextDef.name = name.infer(assetName, "asset name")
            nextDef.source = util.mergeTables(nextDef.source or {}, {
                asset = assetName,
            })
            return fromState(nextDef)
        end

        api.asSpoon = function(value)
            local nextDef = util.copyTable(def)
            nextDef.name = name.infer(value, "explicit Spoon name")
            name.logExplicit(nextDef.name, value)
            return fromState(nextDef)
        end

        api.use = function(useOptions)
            local nextDef = util.copyTable(def)
            nextDef.use = util.mergeTables(nextDef.use or {}, useOptions or {})
            return fromState(nextDef)
        end

        api.onLocalChanges = function(behavior)
            local nextDef = util.copyTable(def)
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
