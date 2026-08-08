return function(context)
    local util = context.util

    local LocalZip = {
        name = "localZip",
        factoryName = "localZip",

        capabilities = {
            path = true,
            zipFile = true,
            useFolder = true,
            withName = true,
            conflictStrategy = true,
        },

        -- A localZip path either points directly at a .zip, or it is a base folder
        -- that addresses the .zip via .path(...)/.zipFile(...). These checks keep the
        -- two shapes from mixing.
        resolveChecks = {
            {
                when = { isZip = "file" },
                forbid = { fields = { "selection_path", "zipFile" } },
                message = "This localZip path already points at a .zip; drop .path(...)/.zipFile(...).",
            },
            {
                when = { notZip = "file" },
                require = { field = "zipFile" },
                message = "localZip needs a .zip: point the path at a .zip or add .zipFile(...).",
            },
        },
    }

    function LocalZip.createSource(path)
        util.requireString(path, "Local ZIP path")

        return {
            type = LocalZip.name,
            file = path,
        }
    end

    function LocalZip.resolve(config)
        local source = config.source or {}
        local extract = config.extract or {}

        local file = source.file
        if source.zipFile then
            file = source.selection_path
                and util.pathJoin(source.file, source.selection_path, source.zipFile)
                or util.pathJoin(source.file, source.zipFile)
        end

        return {
            sourceKind = "zip",
            localPath = util.localPath(file),
            extractFolder = extract.useFolder,
        }
    end

    return LocalZip
end
