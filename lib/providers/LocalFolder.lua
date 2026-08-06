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
            path = path,
        }
    end

    return LocalFolder
end
