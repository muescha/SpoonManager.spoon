return function(context)
    local util = context.util

    local function sourceRef(source)
        return source.revision_ref or source.revision_branch or source.defaultBranch or "main"
    end

    local function archiveUrl(source)
        local ref = sourceRef(source)
        return string.format(
            "%s/%s/archive/%s.zip",
            source.baseUrl or "https://github.com",
            source.repository,
            ref
        )
    end

    local function rawUrl(source, path)
        local ref = sourceRef(source)
        return string.format(
            "%s/%s/raw/%s/%s",
            source.baseUrl or "https://github.com",
            source.repository,
            ref,
            path
        )
    end

    local function releaseAssetUrl(source)
        local release = source.release or "latest"

        if release == "latest" then
            return string.format(
                "%s/%s/releases/latest/download/%s",
                source.baseUrl or "https://github.com",
                source.repository,
                source.asset
            )
        end

        return string.format(
            "%s/%s/releases/download/%s/%s",
            source.baseUrl or "https://github.com",
            source.repository,
            release,
            source.asset
        )
    end

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

        builderPresets = {},
    }

    function GitHub.builderPresets.spoonRepo(manager, repository, options)
        return manager.from.github(repository, options)
            .spoonFolderPattern(manager.options.patterns.spoonRepo)
    end

    function GitHub.builderPresets.spoonRepoZip(manager, repository, options)
        return manager.from.github(repository, options)
            .spoonZipPattern(manager.options.patterns.spoonRepoZip)
    end

    function GitHub.createSource(repository, options)
        util.requireString(repository, "GitHub repository")

        options = options or {}
        util.requireStringOptional(options.branch, "GitHub branch")
        util.requireStringOptional(options.ref, "GitHub ref")
        util.requireStringOptional(options.baseUrl, "GitHub base URL")
        util.requireStringOptional(options.defaultBranch, "GitHub default branch")

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
            resolved.sourceKind = "zip"
            resolved.asset = source.zipFile
            resolved.release = release
            resolved.url = releaseAssetUrl({
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
            resolved.sourceKind = "zip"
            resolved.url = rawUrl(source, path)
            resolved.extractFolder = extract.folder
        elseif source.path then
            resolved.sourceKind = "zip"
            resolved.extractFolder = source.path
            resolved.url = archiveUrl(source)
        elseif target.selection_spoon and source.pattern_spoonZipPattern then
            local path = selectedSpoonName and source.pattern_spoonZipPattern:gsub("{name}", selectedSpoonName) or nil
            resolved.sourceKind = "zip"
            if path then
                resolved.url = rawUrl(source, path)
            end
        elseif target.selection_spoon and source.pattern_spoonFolderPattern then
            local path = selectedSpoonName and source.pattern_spoonFolderPattern:gsub("{name}", selectedSpoonName) or nil
            resolved.sourceKind = "zip"
            resolved.extractFolder = path
            resolved.url = archiveUrl(source)
        else
            resolved.sourceKind = "zip"
            resolved.url = archiveUrl(source)
        end

        return resolved
    end

    return GitHub
end
