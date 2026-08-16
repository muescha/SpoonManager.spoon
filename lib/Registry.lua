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

    function Registry.persistInstall(definition, destination, fingerprints)
        local registry = Registry.read()
        local now = ports.clock.nowIso()
        local task = definition.task
        local name = task.name
        local previous = registry[name] or {}
        local previousMeta = previous.registryMeta or {}
        definition.registryMeta = util.mergeTables(definition.registryMeta or {}, {
            installedAt = previousMeta.installedAt or previous.installedAt or now,
            updatedAt = now,
            path = destination,
            previousFingerprints = (
                previousMeta.persistedFingerprints
                or (previous.result and previous.result.fingerprints)
                or previous.fingerprints
            ),
            persistedFingerprints = {
                stagedSourceHash = fingerprints.stagedSourceHash,
                targetFolderHash = fingerprints.targetFolderHash,
            },
        })

        registry[name] = util.copyTable(definition)

        return Registry.write(registry)
    end

    return Registry
end
