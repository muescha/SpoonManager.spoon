return function(context)
    local Resolver = {}
    local github = context.github
    local manager = context.manager
    local nameResolver = context.nameResolver
    local paths = context.paths
    local util = context.util

    function Resolver.resolveFromDefinition(definition)
        if definition.resolved then
            return util.copyTable(definition.resolved)
        end

        local source = definition.source or {}
        local target = definition.target or {}
        local selectedSpoonName = nameResolver.infer(target.selection_spoon, "selected Spoon name")
        local release = source.release_release or (source.release_releaseLatest and "latest") or "latest"
        local installName = nameResolver.infer(target.name_withName, "explicit Spoon name")
            or selectedSpoonName
            or nameResolver.infer(target.selection_folder, "selected folder")
            or nameResolver.infer(target.selection_asset, "selected asset")
            or nameResolver.inferFromSource(source)

        local resolved = {
            installName = installName,
        }

        if source.type == "github" then
            if target.selection_asset then
                resolved.sourceType = "github-release"
                resolved.asset = target.selection_asset
                resolved.release = release
                resolved.url = github.releaseAssetUrl({
                    baseUrl = source.baseUrl,
                    repository = source.repository,
                    release = release,
                    asset = target.selection_asset,
                })
            elseif target.selection_folder then
                resolved.sourceType = "github-folder"
                resolved.extractFolder = target.selection_folder
                resolved.archiveUrl = github.archiveUrl(source)
            elseif target.selection_spoon and source.pattern_spoonZipPattern then
                local path = selectedSpoonName and source.pattern_spoonZipPattern:gsub("{name}", selectedSpoonName) or nil
                resolved.sourceType = "remote-zip"
                if path then
                    resolved.url = github.rawUrl(source, path)
                end
            elseif target.selection_spoon and source.pattern_spoonFolderPattern then
                local path = selectedSpoonName and source.pattern_spoonFolderPattern:gsub("{name}", selectedSpoonName) or nil
                resolved.sourceType = "github-folder"
                resolved.extractFolder = path
                resolved.archiveUrl = github.archiveUrl(source)
            else
                resolved.sourceType = "github-repository"
                resolved.archiveUrl = github.archiveUrl(source)
            end
        elseif source.type == "local-folder" and target.selection_folder then
            resolved.sourceType = "local-folder"
            resolved.localPath = util.pathJoin(util.localPath(source.path), target.selection_folder)
        else
            resolved.sourceType = source.type
            if source.type == "remote-zip" then
                resolved.url = source.url
            elseif source.type == "local-folder" or source.type == "local-zip" then
                resolved.localPath = util.localPath(source.path)
            end
        end

        return resolved
    end

    function Resolver.withResolved(definition)
        local def = util.copyTable(definition)
        if not def.resolved then
            def.resolved = Resolver.resolveFromDefinition(def)
        end
        return def
    end

    function Resolver.commandFromResolved(definition, action, resolved)
        if definition.command and (not action or definition.command.action == action) then
            return util.copyTable(definition.command)
        end

        resolved = resolved or Resolver.resolveFromDefinition(definition)
        local command = {
            action = action or "install",
            name = resolved.installName,
            from = {
                type = resolved.sourceType,
            },
            to = {
                type = "spoon",
                name = resolved.installName,
                path = resolved.installName and paths.targetPath(resolved.installName) or nil,
            },
            options = util.mergeTables(manager.installOptions, definition.options or {}),
            use = util.copyTable(definition.use),
        }

        if resolved.sourceType == "github-folder" or resolved.sourceType == "github-repository" then
            command.from.archiveUrl = resolved.archiveUrl
            command.from.folder = resolved.extractFolder
        elseif resolved.sourceType == "github-release" or resolved.sourceType == "remote-zip" then
            command.from.url = resolved.url
        elseif resolved.sourceType == "local-folder" or resolved.sourceType == "local-zip" then
            command.from.path = resolved.localPath
        end

        return command
    end

    function Resolver.withCommand(definition, action)
        local def = Resolver.withResolved(definition)
        action = action or "install"

        if def.command then
            if def.command.action ~= action then
                error(string.format(
                    "definition already has command values for %s; cannot build command for %s.",
                    tostring(def.command.action),
                    tostring(action)
                ), 2)
            end

            return def
        end

        def.command = Resolver.commandFromResolved(def, action, def.resolved)
        return def
    end

    function Resolver.explain(definition)
        return util.copyTable(definition)
    end

    return Resolver
end
