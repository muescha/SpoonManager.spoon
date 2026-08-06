return function(context)
    local util = context.util

    local RemoteZip = {
        name = "remoteZip",
        factoryName = "remoteZip",

        capabilities = {
            useFolder = true,
        },
    }

    function RemoteZip.createSource(url)
        util.requireZipPath(url, "Remote ZIP URL")

        return {
            type = RemoteZip.name,
            url = url,
        }
    end

    function RemoteZip.resolve(config)
        local source = config.source or {}
        local extract = config.extract or {}

        return {
            sourceKind = "zip",
            url = source.url,
            extractFolder = extract.folder,
        }
    end

    return RemoteZip
end
