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

    return RemoteZip
end
