return function(context)
    local util = context.util

    local LocalZip = {
        name = "localZip",
        factoryName = "localZip",

        capabilities = {
            useFolder = true,
        },
    }

    function LocalZip.createSource(path)
        util.requireZipPath(path, "Local ZIP path")

        return {
            type = LocalZip.name,
            file = path,
        }
    end

    function LocalZip.resolve(config)
        local source = config.source or {}
        local extract = config.extract or {}

        return {
            sourceType = "zip",
            localPath = util.localPath(source.file),
            extractFolder = extract.folder,
        }
    end

    return LocalZip
end
