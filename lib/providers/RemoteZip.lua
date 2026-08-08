return function(context)
    local util = context.util

    -- Join URL segments without collapsing the "https://" scheme slashes.
    -- Uses select so nil segments (e.g. an unset path) are skipped, not truncated.
    local function joinUrl(...)
        local url = ""
        for i = 1, select("#", ...) do
            local part = select(i, ...)
            if part and part ~= "" then
                if url == "" then
                    url = part
                else
                    url = url:gsub("/+$", "") .. "/" .. part:gsub("^/+", "")
                end
            end
        end
        return url
    end

    local RemoteZip = {
        name = "remoteZip",
        factoryName = "remoteZip",

        capabilities = {
            path = true,
            zipFile = true,
            useFolder = true,
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
            url = joinUrl(source.url, source.selection_path, source.zipFile)
        end

        return {
            sourceKind = "zip",
            url = url,
            extractFolder = extract.useFolder,
        }
    end

    return RemoteZip
end
