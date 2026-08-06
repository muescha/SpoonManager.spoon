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
            folder = true,
            asset = true,
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

    return GitHub
end
