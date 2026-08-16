return function(context)
    local Registry = {}
    local util = context.util
    local paths = context.paths
    local logger = context.logger
    local ports = context.ports

    function Registry.read()
        local path = paths.registryPath()
        if not util.fileExists(path) then
            return {}
        end

        return ports.json.read(path) or {}
    end

    function Registry.write(registry)
        local path = paths.registryPath()
        util.ensureDir(path:match("^(.*)/[^/]+$"), logger)

        local file, err = io.open(path, "w")
        if not file then
            return nil, err
        end

        file:write(ports.json.encode(registry, true))
        file:close()
        return true
    end

    -- Narrow, versioned record for one installed Spoon. Only the fields needed to
    -- reproduce (config) and to detect change (fingerprints), plus identity and
    -- timestamps — never a dump of the runtime definition.
    function Registry.persistInstall(definition, destination, fingerprints)
        local registry = Registry.read()
        local now = ports.clock.nowIso()
        local name = definition.task.name
        local previous = registry[name] or {}

        registry[name] = {
            schemaVersion = 1,
            name = name,
            path = destination,
            config = util.copyTable(definition.config or {}),
            fingerprints = {
                stagedSourceHash = fingerprints.stagedSourceHash,
                targetFolderHash = fingerprints.targetFolderHash,
            },
            installedAt = previous.installedAt or now,
            updatedAt = now,
        }

        return Registry.write(registry)
    end

    return Registry
end
