return function(context)
    local util = context.util

    local GitHub = {
        name = "github",
        factoryName = "github",

        capabilities = {
            branch = true,
            ref = true,
            path = true,
            zipFile = true,
            release = true,
            useFolder = true,
            spoonZipPattern = true,
            spoonFolderPattern = true,
        },

        defaults = {
            baseUrl = "https://github.com",
        },
    }

    function GitHub.createSource(repository, options)
        util.requireString(repository, "GitHub repository")

        options = options or {}
        if options.branch then
            util.requireString(options.branch, "GitHub branch")
        end
        if options.ref then
            util.requireString(options.ref, "GitHub ref")
        end
        if options.baseUrl then
            util.requireString(options.baseUrl, "GitHub base URL")
        end
        if options.defaultBranch then
            util.requireString(options.defaultBranch, "GitHub default branch")
        end

        local source = {
            type = GitHub.name,
            provider = GitHub.name,
            repository = repository,
            baseUrl = options.baseUrl or GitHub.defaults.baseUrl,
        }

        if options.defaultBranch then
            source.defaultBranch = options.defaultBranch
        end

        if options.ref then
            source.revision_ref = options.ref
        elseif options.branch then
            source.revision_branch = options.branch
        end

        return source
    end

    function GitHub.resolve(config, options)
        local github = context.github
        local source = config.source or {}
        local extract = config.extract or {}
        local target = config.target or {}
        local selectedSpoonName = options.selectedSpoonName
        local release = source.release_release or (source.release_releaseLatest and "latest") or "latest"
        local resolved = {}

        if (source.release_release or source.release_releaseLatest) and not source.zipFile then
            error("GitHub release sources require .zipFile(...).", 2)
        end

        if source.zipFile and (source.release_release or source.release_releaseLatest) then
            resolved.sourceType = "zip"
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
            resolved.sourceType = "zip"
            resolved.url = github.rawUrl(source, path)
            resolved.extractFolder = extract.folder
        elseif source.path then
            resolved.sourceType = "zip"
            resolved.extractFolder = source.path
            resolved.url = github.archiveUrl(source)
        elseif target.selection_spoon and source.pattern_spoonZipPattern then
            local path = selectedSpoonName and source.pattern_spoonZipPattern:gsub("{name}", selectedSpoonName) or nil
            resolved.sourceType = "zip"
            if path then
                resolved.url = github.rawUrl(source, path)
            end
        elseif target.selection_spoon and source.pattern_spoonFolderPattern then
            local path = selectedSpoonName and source.pattern_spoonFolderPattern:gsub("{name}", selectedSpoonName) or nil
            resolved.sourceType = "zip"
            resolved.extractFolder = path
            resolved.url = github.archiveUrl(source)
        else
            resolved.sourceType = "zip"
            resolved.url = github.archiveUrl(source)
        end

        return resolved
    end

    return GitHub
end
