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

    function Registry.persistInstall(definition, destination, fingerprints)
        local registry = Registry.read()
        fingerprints = fingerprints or {}
        local now = os.date("!%Y-%m-%dT%H:%M:%SZ")
        local execution = definition.execution or {}
        local name = execution.name or definition.name
        local previous = registry[name] or {}

        registry[name] = {
            name = name,
            installedAt = previous.installedAt or now,
            updatedAt = now,
            path = destination,
            checksum = fingerprints.localHash,
            config = definition.config,
            resolved = definition.resolved,
            command = definition.command,
            fingerprints = {
                localHash = fingerprints.localHash,
                sourceHash = fingerprints.sourceHash,
            },
            use = execution.use or definition.use,
        }

        return Registry.write(registry)
    end

    return Registry
end
