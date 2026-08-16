return function(context)
    local Paths = {}
    local util = context.util
    local manager = context.manager
    local ports = context.ports

    function Paths.installRoot()
        return util.pathJoin(ports.config.dir(), "Spoons")
    end

    function Paths.targetPath(name)
        return util.pathJoin(Paths.installRoot(), name .. ".spoon")
    end

    function Paths.registryPath()
        return util.pathJoin(manager.configDir, "installed.json")
    end

    return Paths
end
