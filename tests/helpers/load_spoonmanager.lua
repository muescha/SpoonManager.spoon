return function(repoRoot)
    dofile(repoRoot .. "/tests/helpers/hammerspoon_stub.lua")(repoRoot)

    local SpoonManager = dofile(repoRoot .. "/init.lua")
    local util = dofile(repoRoot .. "/lib/Util.lua")

    local context = {
        manager = SpoonManager,
        util = util,
        logger = SpoonManager.logger,
    }

    context.nameResolver = dofile(repoRoot .. "/lib/NameResolver.lua")(context)
    context.paths = dofile(repoRoot .. "/lib/Paths.lua")(context)
    context.resolver = dofile(repoRoot .. "/lib/Resolver.lua")(context)
    context.spoonExtractor = dofile(repoRoot .. "/lib/SpoonExtractor.lua")(context)
    context.registry = dofile(repoRoot .. "/lib/Registry.lua")(context)
    context.installer = dofile(repoRoot .. "/lib/Installer.lua")(context)

    return SpoonManager, context
end
