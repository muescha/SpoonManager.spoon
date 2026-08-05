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

        local executionSource = util.copyTable(source)
        local resolved = {
            installName = installName,
        }

        if source.type == "github" then
            executionSource.type = "github-repository"

            if target.selection_asset then
                executionSource.type = "github-release"
                executionSource.release = source.release or "latest"
                executionSource.asset = target.selection_asset
                resolved.sourceType = "github-release"
                resolved.asset = target.selection_asset
            elseif target.selection_folder then
                executionSource.type = "github-folder"
                executionSource.path = target.selection_folder
                resolved.sourceType = "github-folder"
                resolved.extractFolder = target.selection_folder
            elseif target.selection_spoon and source.pattern_spoonZipPattern then
                local path = source.pattern_spoonZipPattern:gsub("{name}", target.selection_spoon)
                executionSource = {
                    type = "remote-zip",
                    url = github.rawUrl(source, path),
                }
                resolved.sourceType = "remote-zip"
                resolved.url = executionSource.url
            elseif target.selection_spoon and source.pattern_spoonFolderPattern then
                local path = source.pattern_spoonFolderPattern:gsub("{name}", target.selection_spoon)
                executionSource.type = "github-folder"
                executionSource.path = path
                resolved.sourceType = "github-folder"
                resolved.extractFolder = path
            else
                resolved.sourceType = "github-repository"
            end
        elseif source.type == "local-folder" and target.selection_folder then
            executionSource.path = util.pathJoin(source.path, target.selection_folder)
            resolved.sourceType = "local-folder"
            resolved.localPath = executionSource.path
        else
            resolved.sourceType = source.type
        end

        if executionSource.type == "github-folder" or executionSource.type == "github-repository" then
            resolved.archiveUrl = github.archiveUrl(executionSource)
        elseif executionSource.type == "github-release" then
            resolved.url = github.releaseAssetUrl(executionSource)
        elseif executionSource.type == "remote-zip" then
            resolved.url = executionSource.url
        elseif executionSource.type == "local-folder" or executionSource.type == "local-zip" then
            resolved.localPath = executionSource.path
        end

        resolved.executionSource = executionSource
        return resolved
    end

    function Resolver.toCommand(definition, action)
        local resolved = Resolver.resolveDefinition(definition)
        local source = resolved.executionSource
        local command = {
            action = action or "install",
            definition = util.copyTable(definition),
            resolved = util.copyTable(resolved),
            from = {
                type = source.type,
            },
            to = {
                type = "spoon",
                name = resolved.installName,
                path = resolved.installName and paths.targetPath(resolved.installName) or nil,
            },
        }

        if source.type == "github-folder" or source.type == "github-repository" then
            command.from.archiveUrl = resolved.archiveUrl
            command.from.folder = source.path
        elseif source.type == "github-release" or source.type == "remote-zip" then
            command.from.url = resolved.url
        elseif source.type == "local-folder" or source.type == "local-zip" then
            command.from.path = source.path
        end

        return command
    end

    return Resolver
end
