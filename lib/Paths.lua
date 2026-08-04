return function(context)
    local Paths = {}
    local util = context.util
    local manager = context.manager

    function Paths.installRoot()
        return util.pathJoin(hs.configdir, "Spoons")
    end

    function Paths.targetPath(name)
        return util.pathJoin(Paths.installRoot(), name .. ".spoon")
    end

    function Paths.registryPath()
        return util.pathJoin(manager.configDir, "installed.json")
    end

    return Paths
end
