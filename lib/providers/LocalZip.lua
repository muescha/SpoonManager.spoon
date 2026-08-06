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
            path = path,
        }
    end

    return LocalZip
end
