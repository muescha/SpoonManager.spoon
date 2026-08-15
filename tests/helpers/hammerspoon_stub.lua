return function(repoRoot)
    local usedSpoons = {}

    hs = {
        configdir = "/tmp/hammerspoon-test",
        logger = {
            new = function()
                return {
                    df = function() end,
                    ef = function() end,
                    i = function() end,
                    w = function() end,
                }
            end,
        },
        spoons = {
            scriptPath = function()
                return repoRoot
            end,
            use = function(name, options)
                table.insert(usedSpoons, {
                    name = name,
                    options = options,
                })
                return true
            end,
        },
        fs = {
            pathToAbsolute = function(path)
                return path:gsub("^~", "/Users/test")
            end,
            attributes = function()
                return nil
            end,
        },
        execute = function()
            return "", true
        end,
        inspect = function(value)
            return tostring(value)
        end,
        timer = {
            doAfter = function(_, fn)
                return fn()
            end,
        },
        reload = function() end,
    }

    return {
        usedSpoons = usedSpoons,
    }
end
