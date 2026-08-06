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

        local config = definition.config or {}
        local source = config.source or {}
        local extract = config.extract or {}
        local target = config.target or {}
        local selectedSpoonName = nameResolver.infer(target.selection_spoon, "selected Spoon name")
        local release = source.release_release or (source.release_releaseLatest and "latest") or "latest"
        local installName = nameResolver.infer(target.name_withName, "explicit Spoon name")
            or selectedSpoonName
            or nameResolver.infer(extract.folder, "extract folder")
            or nameResolver.infer(source.zipFile, "ZIP file")
            or nameResolver.infer(source.path, "source path")
            or nameResolver.inferFromSource(source)

        local resolved = {
            installName = installName,
        }

        if source.type == "github" then
            if (source.release_release or source.release_releaseLatest) and not source.zipFile then
                error("GitHub release sources require .zipFile(...).", 2)
            end

            if source.zipFile and (source.release_release or source.release_releaseLatest) then
                resolved.sourceType = "github-release"
                resolved.asset = source.zipFile
                resolved.release = release
                resolved.url = github.releaseAssetUrl({
                    baseUrl = source.baseUrl,
                    repository = source.repository,
                    release = release,
                    asset = source.zipFile,
                })
                resolved.extractFolder = extract.folder
            elseif source.zipFile then
                local path = source.zipFile
                if source.path then
                    path = util.pathJoin(source.path, source.zipFile)
                end
                resolved.sourceType = "remoteZip"
                resolved.url = github.rawUrl(source, path)
                resolved.extractFolder = extract.folder
            elseif source.path then
                resolved.sourceType = "github-folder"
                resolved.extractFolder = source.path
                resolved.archiveUrl = github.archiveUrl(source)
            elseif target.selection_spoon and source.pattern_spoonZipPattern then
                local path = selectedSpoonName and source.pattern_spoonZipPattern:gsub("{name}", selectedSpoonName) or nil
                resolved.sourceType = "remoteZip"
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
        elseif source.type == "localFolder" and source.zipFile then
            local path = source.zipFile
            if source.path then
                path = util.pathJoin(source.path, source.zipFile)
            end
            resolved.sourceType = "localZip"
            resolved.localPath = util.pathJoin(util.localPath(source.root), path)
            resolved.extractFolder = extract.folder
        elseif source.type == "localFolder" and source.path then
            resolved.sourceType = "localFolder"
            resolved.localPath = util.pathJoin(util.localPath(source.root), source.path)
        else
            resolved.sourceType = source.type
            if source.type == "remoteZip" then
                resolved.url = source.url
                resolved.extractFolder = extract.folder
            elseif source.type == "localFolder" then
                resolved.localPath = util.localPath(source.root)
            elseif source.type == "localZip" then
                resolved.localPath = util.localPath(source.file)
                if source.type == "localZip" then
                    resolved.extractFolder = extract.folder
                end
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

        local config = definition.config or {}
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
            options = util.mergeTables(manager.installOptions, config.options or {}),
            use = util.copyTable(config.use),
        }

        if resolved.sourceType == "github-folder" or resolved.sourceType == "github-repository" then
            command.from.archiveUrl = resolved.archiveUrl
            command.from.folder = resolved.extractFolder
        elseif resolved.sourceType == "github-release" or resolved.sourceType == "remoteZip" then
            command.from.url = resolved.url
            command.from.folder = resolved.extractFolder
        elseif resolved.sourceType == "localFolder" or resolved.sourceType == "localZip" then
            command.from.path = resolved.localPath
            if resolved.sourceType == "localZip" then
                command.from.folder = resolved.extractFolder
            end
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
