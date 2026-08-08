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
        local release = ruleOptions.source.selection_release
            or (ruleOptions.source.selection_releaseLatest and "latest")

        if not release then
            return nil
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
            extractFolder = ruleOptions.extract.useFolder,
        }
    end

    local function resolveZipFile(ruleOptions)
        if not ruleOptions.source.zipFile then
            return nil
        end

        local path = ruleOptions.source.selection_path
            and util.pathJoin(ruleOptions.source.selection_path, ruleOptions.source.zipFile)
            or ruleOptions.source.zipFile

        return {
            sourceKind = "zip",
            url = rawUrl(ruleOptions.source, path),
            extractFolder = ruleOptions.extract.useFolder,
        }
    end

    local function resolvePath(ruleOptions)
        if not ruleOptions.source.selection_path then
            return nil
        end

        return {
            sourceKind = "zip",
            extractFolder = ruleOptions.source.selection_path,
            url = archiveUrl(ruleOptions.source),
        }
    end

    -- Substitute {name} in a pattern. The replacement is escaped so a Spoon name
    -- containing "%" is not treated as a gsub replacement reference.
    local function expandName(pattern, name)
        return (pattern:gsub("{name}", (name:gsub("%%", "%%%%"))))
    end

    local function resolveSpoonZipPattern(ruleOptions)
        if not (
            ruleOptions.source.selection_spoon
            and ruleOptions.source.pattern_spoonZipPattern
        ) then
            return nil
        end

        local path = ruleOptions.selectedSpoonName
            and expandName(ruleOptions.source.pattern_spoonZipPattern, ruleOptions.selectedSpoonName)

        return {
            sourceKind = "zip",
            url = path and rawUrl(ruleOptions.source, path),
        }
    end

    local function resolveSpoonFolderPattern(ruleOptions)
        if not (
            ruleOptions.source.selection_spoon
            and ruleOptions.source.pattern_spoonFolderPattern
        ) then
            return nil
        end

        local path = ruleOptions.selectedSpoonName
            and expandName(ruleOptions.source.pattern_spoonFolderPattern, ruleOptions.selectedSpoonName)

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

        -- Logical (cross-field) checks, run by the resolver before GitHub.resolve.
        -- Step 2's exclusive "selection" group already keeps spoon/path/release/
        -- releaseLatest mutually exclusive; the only free modifier left is zipFile,
        -- so the residual ambiguity (spoon + zipFile) is covered here too.
        resolveChecks = {
            {
                when = { field = "selection_spoon" },
                forbid = { field = "zipFile" },
                message = "GitHub spoon selection conflicts with .zipFile(...); "
                    .. "use a Spoon pattern (.spoonZipPattern/.spoonFolderPattern) instead of .zipFile(...).",
            },
            {
                when = { field = "selection_spoon" },
                require = { group = "pattern" },
                message = "GitHub spoon selection requires .spoonZipPattern(...) or .spoonFolderPattern(...); "
                    .. "or use from.spoonRepo(...)/from.spoonRepoZip(...).",
            },
            {
                when = { anyField = { "selection_release", "selection_releaseLatest" } },
                require = { field = "zipFile" },
                message = "GitHub release sources require .zipFile(...).",
            },
            {
                -- .path() alone selects the folder to extract (extractFolder), so a
                -- separate .useFolder() would be silently ignored. With .zipFile(...)
                -- the path is only a directory prefix and .useFolder() is valid.
                when = { allOf = { { field = "selection_path" }, { absentField = "zipFile" } } },
                forbid = { field = "extract.useFolder" },
                message = "GitHub .path(...) already selects the folder; drop .useFolder(...) "
                    .. "-- or add .zipFile(...) to make .path(...) a directory prefix.",
            },
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
