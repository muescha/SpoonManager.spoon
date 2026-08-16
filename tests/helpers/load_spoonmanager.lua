return function(repoRoot)
    dofile(repoRoot .. "/tests/helpers/hammerspoon_stub.lua")(repoRoot)

    local SpoonManager = dofile(repoRoot .. "/init.lua")
    local util = dofile(repoRoot .. "/lib/Util.lua")

    local context = {
        manager = SpoonManager,
        util = util,
        logger = SpoonManager.logger,
        ports = dofile(repoRoot .. "/lib/Ports.lua"),
    }

    context.nameResolver = dofile(repoRoot .. "/lib/NameResolver.lua")(context)
    context.paths = dofile(repoRoot .. "/lib/Paths.lua")(context)
    context.definitionChecker = dofile(repoRoot .. "/lib/DefinitionChecker.lua")(context)
    context.definitionResolver = dofile(repoRoot .. "/lib/DefinitionResolver.lua")(context)
    context.spoonExtractor = dofile(repoRoot .. "/lib/SpoonExtractor.lua")(context)
    context.sourceFetcher = dofile(repoRoot .. "/lib/SourceFetcher.lua")(context)
    context.sourceStage = dofile(repoRoot .. "/lib/SourceStage.lua")(context)
    context.registry = dofile(repoRoot .. "/lib/Registry.lua")(context)
    context.installer = dofile(repoRoot .. "/lib/Installer.lua")(context)
    context.installed = dofile(repoRoot .. "/lib/Installed.lua")(context)

    return SpoonManager, context
end
