return function(context)
    local util = context.util

    local LocalFolder = {
        name = "localFolder",
        factoryName = "localFolder",

        capabilities = {
            path = true,
            zipFile = true,
            useFolder = true,
        },
    }

    function LocalFolder.createSource(path)
        util.requireString(path, "Local folder path")

        return {
            type = LocalFolder.name,
            root = path,
        }
    end

    function LocalFolder.resolve(config)
        local source = config.source or {}
        local extract = config.extract or {}

        if source.zipFile then
            local path = source.zipFile
            if source.path_path then
                path = util.pathJoin(source.path_path, source.zipFile)
            end

            return {
                sourceKind = "zip",
                localPath = util.pathJoin(util.localPath(source.root), path),
                extractFolder = extract.folder,
            }
        end

        if source.path_path then
            return {
                sourceKind = "folder",
                localPath = util.pathJoin(util.localPath(source.root), source.path_path),
            }
        end

        return {
            sourceKind = "folder",
            localPath = util.localPath(source.root),
        }
    end

    return LocalFolder
end
