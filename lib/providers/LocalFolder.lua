return function(context)
    local util = context.util

    local LocalFolder = {
        name = "localFolder",
        factoryName = "localFolder",

        capabilities = {
            path = true,
            zipFile = true,
            useFolder = true,
            excludeFolders = true,
            withName = true,
            conflictStrategy = true,
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
            if source.selection_path then
                path = util.pathJoin(source.selection_path, source.zipFile)
            end

            return {
                source = {
                    kind = "zip",
                    location = {
                        kind = "path",
                        path = util.pathJoin(util.localPath(source.root), path),
                    },
                    selection = {
                        folder = extract.useFolder,
                    },
                },
            }
        end

        if source.selection_path then
            return {
                source = {
                    kind = "folder",
                    location = {
                        kind = "path",
                        path = util.pathJoin(util.localPath(source.root), source.selection_path),
                    },
                },
            }
        end

        return {
            source = {
                kind = "folder",
                location = {
                    kind = "path",
                    path = util.localPath(source.root),
                },
            },
        }
    end

    return LocalFolder
end
