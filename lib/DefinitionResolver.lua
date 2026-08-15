return function(context)
    local DefinitionResolver = {}
    local manager = context.manager
    local nameResolver = context.nameResolver
    local definitionChecker = context.definitionChecker
    local paths = context.paths
    local util = context.util

    function DefinitionResolver.resolveFromDefinition(definition)
        if definition.resolved then
            return util.copyTable(definition.resolved)
        end

        local config = definition.config or {}
        local source = config.source or {}
        local installName, selectedSpoonName = nameResolver.inferNames(config)

        local resolved = {
            installName = installName,
        }

        local provider = manager.providers[source.type]
        if not provider or not provider.resolve then
            error("Unsupported source type: " .. tostring(source.type), 2)
        end

        definitionChecker.run(provider, config)

        resolved = util.mergeTables(resolved, provider.resolve(config, {
            selectedSpoonName = selectedSpoonName,
        }))

        return resolved
    end

    function DefinitionResolver.withResolved(definition)
        local def = util.copyTable(definition)
        if not def.resolved then
            def.resolved = DefinitionResolver.resolveFromDefinition(def)
        end
        return def
    end

    function DefinitionResolver.commandFromResolved(definition, action, resolved)
        if definition.command and (not action or definition.command.action == action) then
            return util.copyTable(definition.command)
        end

        local config = definition.config or {}
        resolved = resolved or DefinitionResolver.resolveFromDefinition(definition)
        local command = {
            action = action or "install",
            name = resolved.installName,
            source = util.copyTable(resolved.source),
            target = {
                type = "spoon",
                name = resolved.installName,
                path = resolved.installName and paths.targetPath(resolved.installName) or nil,
            },
            options = util.mergeTables(manager.installOptions, config.installOptions or {}),
            use = util.copyTable(config.use),
        }

        return command
    end

    function DefinitionResolver.withCommand(definition, action)
        local def = DefinitionResolver.withResolved(definition)
        action = action or "install"

        if def.command then
            if def.command.action ~= action then
                error(string.format(
                    "definition already has command values for %s; cannot build command for %s.",
                    tostring(def.command.action),
                    tostring(action)
                ), 2)
            end

            return def
        end

        def.command = DefinitionResolver.commandFromResolved(def, action, def.resolved)
        return def
    end

    function DefinitionResolver.explain(definition)
        return util.copyTable(definition)
    end

    return DefinitionResolver
end
