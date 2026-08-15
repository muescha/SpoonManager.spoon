return function(context)
    local util = context.util

    local RemoteZip = {
        name = "remoteZip",
        factoryName = "remoteZip",

        capabilities = {
            path = true,
            zipFile = true,
            useFolder = true,
            excludeFolders = true,
            withName = true,
            conflictStrategy = true,
        },

        -- A remoteZip URL either points directly at a .zip, or it is a base that
        -- addresses the .zip via .path(...)/.zipFile(...). These checks keep the
        -- two shapes from mixing.
        resolveChecks = {
            {
                when = { isZip = "url" },
                forbid = { fields = { "selection_path", "zipFile" } },
                message = "This remoteZip URL already points at a .zip; drop .path(...)/.zipFile(...).",
            },
            {
                when = { notZip = "url" },
                require = { field = "zipFile" },
                message = "remoteZip needs a .zip: point the URL at a .zip or add .zipFile(...).",
            },
        },
    }

    function RemoteZip.createSource(url)
        util.requireString(url, "Remote ZIP URL")

        return {
            type = RemoteZip.name,
            url = url,
        }
    end

    function RemoteZip.resolve(config)
        local source = config.source or {}
        local extract = config.extract or {}

        local url = source.url
        if source.zipFile then
            url = util.joinUrl(source.url, source.selection_path, source.zipFile)
        end

        return {
            source = {
                kind = "zip",
                location = {
                    kind = "url",
                    url = url,
                },
                selection = {
                    folder = extract.useFolder,
                },
            },
        }
    end

    return RemoteZip
end
