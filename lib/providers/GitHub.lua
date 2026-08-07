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

    local function releaseZipUrl(source)
        local release = source.release or "latest"

        if release == "latest" then
            return string.format(
                "%s/%s/releases/latest/download/%s",
                source.baseUrl or "https://github.com",
                source.repository,
                source.zipFile
            )
        end

        return string.format(
            "%s/%s/releases/download/%s/%s",
            source.baseUrl or "https://github.com",
            source.repository,
            release,
            source.zipFile
        )
    end

    local function resolveRelease(ruleOptions)
        local release = ruleOptions.source.release_release
            or (ruleOptions.source.release_releaseLatest and "latest")

        if not release then
            return nil
        end

        if not ruleOptions.source.zipFile then
            error("GitHub release sources require .zipFile(...).", 2)
        end

        return {
            sourceKind = "zip",
            release = release,
            url = releaseZipUrl({
                baseUrl = ruleOptions.source.baseUrl,
                repository = ruleOptions.source.repository,
                release = release,
                zipFile = ruleOptions.source.zipFile,
            }),
            extractFolder = ruleOptions.extract.folder,
        }
    end

    local function resolveZipFile(ruleOptions)
        if not ruleOptions.source.zipFile then
            return nil
        end

        local path = ruleOptions.source.path
            and util.pathJoin(ruleOptions.source.path, ruleOptions.source.zipFile)
            or ruleOptions.source.zipFile

        return {
            sourceKind = "zip",
            url = rawUrl(ruleOptions.source, path),
            extractFolder = ruleOptions.extract.folder,
        }
    end

    local function resolvePath(ruleOptions)
        if not ruleOptions.source.path then
            return nil
        end

        return {
            sourceKind = "zip",
            extractFolder = ruleOptions.source.path,
            url = archiveUrl(ruleOptions.source),
        }
    end

    local function resolveSpoonZipPattern(ruleOptions)
        if not (
            ruleOptions.target.selection_spoon
            and ruleOptions.source.pattern_spoonZipPattern
        ) then
            return nil
        end

        local path = ruleOptions.selectedSpoonName
            and ruleOptions.source.pattern_spoonZipPattern:gsub(
                "{name}",
                ruleOptions.selectedSpoonName
            )

        return {
            sourceKind = "zip",
            url = path and rawUrl(ruleOptions.source, path),
        }
    end

    local function resolveSpoonFolderPattern(ruleOptions)
        if not (
            ruleOptions.target.selection_spoon
            and ruleOptions.source.pattern_spoonFolderPattern
        ) then
            return nil
        end

        local path = ruleOptions.selectedSpoonName
            and ruleOptions.source.pattern_spoonFolderPattern:gsub(
                "{name}",
                ruleOptions.selectedSpoonName
            )

        return {
            sourceKind = "zip",
            extractFolder = path,
            url = archiveUrl(ruleOptions.source),
        }
    end

    local function resolveArchive(ruleOptions)
        return {
            sourceKind = "zip",
            url = archiveUrl(ruleOptions.source),
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
        local ruleOptions = {
            source = config.source or {},
            extract = config.extract or {},
            target = config.target or {},
            selectedSpoonName = options.selectedSpoonName,
        }

        for _, rule in ipairs(resolutionRules) do
            local resolved = rule(ruleOptions)
            if resolved then
                return resolved
            end
        end
    end

    return GitHub
end
