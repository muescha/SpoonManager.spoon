return function(repoRoot)
    dofile(repoRoot .. "/tests/helpers/hammerspoon_stub.lua")(repoRoot)

    local SpoonManager = dofile(repoRoot .. "/init.lua")
    local util = dofile(repoRoot .. "/lib/Util.lua")

    local context = {
        manager = SpoonManager,
        util = util,
        logger = SpoonManager.logger,
    }

    context.github = dofile(repoRoot .. "/lib/GitHub.lua")
    context.nameResolver = dofile(repoRoot .. "/lib/NameResolver.lua")(context)
    context.paths = dofile(repoRoot .. "/lib/Paths.lua")(context)
    context.resolver = dofile(repoRoot .. "/lib/Resolver.lua")(context)

    return SpoonManager, context
end
