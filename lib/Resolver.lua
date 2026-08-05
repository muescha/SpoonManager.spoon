return function(context)
    local Resolver = {}
    local github = context.github
    local nameResolver = context.nameResolver
    local paths = context.paths
    local util = context.util

    function Resolver.resolveDefinition(definition)
        local source = definition.source or {}
        local target = definition.target or {}
        local installName = nameResolver.infer(target.name_withName, "explicit Spoon name")
            or nameResolver.inferFromTarget(target)
            or nameResolver.inferFromSource(source)

        local resolved = {
            installName = installName,
        }

        if source.type == "github" then
            if target.selection_asset then
                resolved.sourceType = "github-release"
                resolved.asset = target.selection_asset
                resolved.release = source.release or "latest"
                resolved.url = github.releaseAssetUrl({
                    baseUrl = source.baseUrl,
                    repository = source.repository,
                    release = source.release or "latest",
                    asset = target.selection_asset,
                })
            elseif target.selection_folder then
                resolved.sourceType = "github-folder"
                resolved.extractFolder = target.selection_folder
                resolved.archiveUrl = github.archiveUrl(source)
            elseif target.selection_spoon and source.pattern_spoonZipPattern then
                local path = source.pattern_spoonZipPattern:gsub("{name}", target.selection_spoon)
                resolved.sourceType = "remote-zip"
                resolved.url = github.rawUrl(source, path)
            elseif target.selection_spoon and source.pattern_spoonFolderPattern then
                local path = source.pattern_spoonFolderPattern:gsub("{name}", target.selection_spoon)
                resolved.sourceType = "github-folder"
                resolved.extractFolder = path
                resolved.archiveUrl = github.archiveUrl(source)
            else
                resolved.sourceType = "github-repository"
                resolved.archiveUrl = github.archiveUrl(source)
            end
        elseif source.type == "local-folder" and target.selection_folder then
            resolved.sourceType = "local-folder"
            resolved.localPath = util.pathJoin(source.path, target.selection_folder)
        else
            resolved.sourceType = source.type
            if source.type == "remote-zip" then
                resolved.url = source.url
            elseif source.type == "local-folder" or source.type == "local-zip" then
                resolved.localPath = source.path
            end
        end

        return resolved
    end

    function Resolver.toCommand(definition, action)
        local resolved = Resolver.resolveDefinition(definition)
        local command = {
            action = action or "install",
            from = {
                type = resolved.sourceType,
            },
            to = {
                type = "spoon",
                name = resolved.installName,
                path = resolved.installName and paths.targetPath(resolved.installName) or nil,
            },
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

    function Resolver.explain(definition, action)
        return {
            definition = util.copyTable(definition),
            resolved = Resolver.resolveDefinition(definition),
            command = Resolver.toCommand(definition, action),
        }
    end

    return Resolver
end
