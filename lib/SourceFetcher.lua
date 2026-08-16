return function(context)
    local SourceFetcher = {}
    local util = context.util
    local ports = context.ports

    function SourceFetcher.downloadToFile(url, destination)
        local status, body = ports.http.get(url)
        if status < 100 or status >= 400 then
            return nil, string.format("Download failed with HTTP status %s for %s", tostring(status), url)
        end

        local file, err = io.open(destination, "wb")
        if not file then
            return nil, err
        end

        file:write(body)
        file:close()
        return true
    end

    function SourceFetcher.fetch(location, stage)
        location = location or {}

        if location.kind == "path" then
            return {
                kind = "path",
                path = location.path,
            }
        end

        if location.kind == "url" then
            local zipFile = util.pathJoin(stage.root, "download.zip")
            local ok, err = SourceFetcher.downloadToFile(location.url, zipFile)
            if not ok then
                return nil, err
            end

            return {
                kind = "path",
                path = zipFile,
            }
        end

        return nil, "Unsupported source location: " .. tostring(location.kind)
    end

    return SourceFetcher
end
