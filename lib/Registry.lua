return function(context)
    local Registry = {}
    local util = context.util
    local paths = context.paths
    local logger = context.logger

    function Registry.read()
        local path = paths.registryPath()
        if not util.fileExists(path) then
            return {}
        end

        return hs.json.read(path) or {}
    end

    function Registry.write(registry)
        local path = paths.registryPath()
        util.ensureDir(path:match("^(.*)/[^/]+$"), logger)

        local file, err = io.open(path, "w")
        if not file then
            return nil, err
        end

        file:write(hs.json.encode(registry, true))
        file:close()
        return true
    end

    function Registry.persistInstall(definition, destination, checksum)
        local registry = Registry.read()
        registry[definition.name] = {
            name = definition.name,
            installedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            path = destination,
            checksum = checksum(destination),
            source = definition.source,
            use = definition.use,
        }

        return Registry.write(registry)
    end

    return Registry
end
