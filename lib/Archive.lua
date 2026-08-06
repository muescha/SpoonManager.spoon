return function(context)
    local Archive = {}
    local util = context.util
    local logger = context.logger

    function Archive.downloadToFile(url, destination)
        local status, body = hs.http.get(url)
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

    function Archive.validateInstalledFolder(path)
        if not util.fileExists(util.pathJoin(path, "init.lua")) then
            return nil, "Installed folder does not contain init.lua"
        end

        return true
    end

    function Archive.prepareZipSelection(definition)
        local source = definition.command and definition.command.from or {}
        local selection = {}

        if source.type == "github-folder" then
            selection.path = source.folder or source.path
        elseif source.type == "github-repository" then
            selection.path = nil
        end

        return selection
    end

    function Archive.extractZipToSpoon(zipFile, definition, tmpdir)
        local extractDir = util.pathJoin(tmpdir, "extract")
        util.ensureDir(extractDir, logger)

        local selection = Archive.prepareZipSelection(definition)
        local unzipCommand

        if selection.path then
            local pattern = "*/" .. selection.path:gsub("^/+", "") .. "/*"
            unzipCommand = "/usr/bin/unzip -q " .. util.shellQuote(zipFile) .. " " .. util.shellQuote(pattern) .. " -d " .. util.shellQuote(extractDir) .. " 2>&1"
        else
            unzipCommand = "/usr/bin/unzip -q " .. util.shellQuote(zipFile) .. " -d " .. util.shellQuote(extractDir) .. " 2>&1"
        end

        local _, ok = util.execute(unzipCommand, logger, "Could not extract %s", zipFile)
        if not ok then
            return nil, "Could not extract zip"
        end

        local sourceFolder
        if selection.path then
            sourceFolder = util.execute(
                "/usr/bin/find " .. util.shellQuote(extractDir) .. " -type d -path " .. util.shellQuote("*/" .. selection.path) .. " -print -quit",
                logger,
                "Could not locate extracted folder %s",
                selection.path
            )
        else
            sourceFolder = util.execute(
                "/usr/bin/find " .. util.shellQuote(extractDir) .. " -mindepth 1 -maxdepth 2 -type f -name init.lua -print -quit",
                logger,
                "Could not locate init.lua in %s",
                zipFile
            )

            if sourceFolder and sourceFolder ~= "" then
                sourceFolder = sourceFolder:gsub("/init%.lua$", "")
            end
        end

        if not sourceFolder or sourceFolder == "" then
            return nil, "Could not locate Spoon folder in archive"
        end

        local valid, err = Archive.validateInstalledFolder(sourceFolder)
        if not valid then
            return nil, err
        end

        return sourceFolder
    end

    return Archive
end
