return function(context)
    local SourceFetcher = {}
    local spoonExtractor = context.spoonExtractor
    local util = context.util

    function SourceFetcher.fetch(location, stage)
        if location.kind == "path" then
            return {
                kind = "path",
                path = location.path,
            }
        end

        if location.kind == "url" then
            local zipFile = util.pathJoin(stage.root, "download.zip")
            local ok, err = spoonExtractor.downloadToFile(location.url, zipFile)
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
