return function(context)
    local DefinitionResolver = {}
    local manager = context.manager
    local nameResolver = context.nameResolver
    local paths = context.paths
    local util = context.util

    function DefinitionResolver.resolveFromDefinition(definition)
        if definition.resolved then
            return util.copyTable(definition.resolved)
        end

        local config = definition.config or {}
        local source = config.source or {}
        local extract = config.extract or {}
        local target = config.target or {}
        local selectedSpoonName = nameResolver.infer(source.selection_spoon, "selected Spoon name")
        local installName = nameResolver.infer(target.name_withName, "explicit Spoon name")
            or selectedSpoonName
            or nameResolver.infer(extract.folder, "extract folder")
            or nameResolver.infer(source.zipFile, "ZIP file")
            or nameResolver.infer(source.selection_path, "source path")
            or nameResolver.inferFromSource(source)

        local resolved = {
            installName = installName,
        }

        local provider = manager.providers[source.type]
        if not provider or not provider.resolve then
            error("Unsupported source type: " .. tostring(source.type), 2)
        end

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
            source = {
                kind = resolved.sourceKind,
            },
            target = {
                type = "spoon",
                name = resolved.installName,
                path = resolved.installName and paths.targetPath(resolved.installName) or nil,
            },
            options = util.mergeTables(manager.installOptions, config.options or {}),
            use = util.copyTable(config.use),
        }

        if resolved.sourceKind == "zip" then
            command.source.url = resolved.url
            command.source.path = resolved.localPath
            command.source.folder = resolved.extractFolder
        elseif resolved.sourceKind == "folder" then
            command.source.path = resolved.localPath
        end

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
