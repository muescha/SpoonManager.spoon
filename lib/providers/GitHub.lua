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

    local function resolveRelease(source, extract)
        local release = source.release_release
            or (source.release_releaseLatest and "latest")

        if not release then
            return nil
        end

        if not source.zipFile then
            error("GitHub release sources require .zipFile(...).", 2)
        end

        return {
            sourceKind = "zip",
            asset = source.zipFile,
            release = release,
            url = releaseAssetUrl({
                baseUrl = source.baseUrl,
                repository = source.repository,
                release = release,
                asset = source.zipFile,
            }),
            extractFolder = extract.folder,
        }
    end

    local function resolveZipFile(source, extract)
        if not source.zipFile then
            return nil
        end

        local path = source.path and util.pathJoin(source.path, source.zipFile) or source.zipFile

        return {
            sourceKind = "zip",
            url = rawUrl(source, path),
            extractFolder = extract.folder,
        }
    end

    local function resolvePath(source, extract)
        if not source.path then
            return nil
        end

        return {
            sourceKind = "zip",
            extractFolder = source.path,
            url = archiveUrl(source),
        }
    end

    local function resolveSpoonZipPattern(source, extract, target, selectedSpoonName)
        if not (target.selection_spoon and source.pattern_spoonZipPattern) then
            return nil
        end

        local path = selectedSpoonName
            and source.pattern_spoonZipPattern:gsub("{name}", selectedSpoonName)

        return {
            sourceKind = "zip",
            url = path and rawUrl(source, path),
        }
    end

    local function resolveSpoonFolderPattern(source, extract, target, selectedSpoonName)
        if not (target.selection_spoon and source.pattern_spoonFolderPattern) then
            return nil
        end

        local path = selectedSpoonName
            and source.pattern_spoonFolderPattern:gsub("{name}", selectedSpoonName)

        return {
            sourceKind = "zip",
            extractFolder = path,
            url = archiveUrl(source),
        }
    end

    local function resolveArchive(source)
        return {
            sourceKind = "zip",
            url = archiveUrl(source),
        }
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

    local resolutionRules = {
        resolveRelease,
        resolveZipFile,
        resolvePath,
        resolveSpoonZipPattern,
        resolveSpoonFolderPattern,
        resolveArchive,
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

        for _, rule in ipairs(resolutionRules) do
            local resolved = rule(source, extract, target, selectedSpoonName)
            if resolved then
                return resolved
            end
        end
    end

    return GitHub
end
