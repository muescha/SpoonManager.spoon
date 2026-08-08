return function(context)
    local DefinitionResolver = {}
    local manager = context.manager
    local nameResolver = context.nameResolver
    local paths = context.paths
    local util = context.util

    -- Read a "section.field" reference from a config (bare name defaults to source).
    local function readRef(config, ref)
        local section, field = ref:match("^(.-)%.(.+)$")
        if not section then
            section, field = "source", ref
        end
        return (config[section] or {})[field]
    end

    local function groupIsSet(config, ref)
        local section, group = ref:match("^(.-)%.(.+)$")
        if not section then
            section, group = "source", ref
        end
        return util.findFlatGroupValue(config[section] or {}, group) ~= nil
    end

    local function whenHolds(config, when)
        if when.allOf then
            for _, sub in ipairs(when.allOf) do
                if not whenHolds(config, sub) then
                    return false
                end
            end
            return true
        end

        if when.field then
            return readRef(config, when.field) ~= nil
        end

        if when.absentField then
            return readRef(config, when.absentField) == nil
        end

        if when.anyField then
            for _, ref in ipairs(when.anyField) do
                if readRef(config, ref) ~= nil then
                    return true
                end
            end
        end

        if when.isZip then
            return util.isZipPath(readRef(config, when.isZip))
        end

        if when.notZip then
            return not util.isZipPath(readRef(config, when.notZip))
        end

        return false
    end

    local function checkPasses(config, check)
        if check.require then
            if check.require.field then
                return readRef(config, check.require.field) ~= nil
            end
            if check.require.group then
                return groupIsSet(config, check.require.group)
            end
        end

        if check.forbid then
            if check.forbid.field then
                return readRef(config, check.forbid.field) == nil
            end
            if check.forbid.fields then
                for _, ref in ipairs(check.forbid.fields) do
                    if readRef(config, ref) ~= nil then
                        return false
                    end
                end
                return true
            end
        end

        return true
    end

    -- Untrusted path-ish fields sanitized for every provider (blanket policy);
    -- covers configs that bypass the builder setters (from.config / a manifest).
    local safePathFields = {
        { ref = "source.selection_path", label = "Source path" },
        { ref = "extract.useFolder", label = "Folder path" },
    }

    -- Run the blanket path-safety pass plus a provider's declarative resolveChecks
    -- (logical cross-field checks) before handing the config to its resolution rules.
    local function runResolveChecks(provider, config)
        for _, entry in ipairs(safePathFields) do
            local value = readRef(config, entry.ref)
            if value then
                util.requireSafeRelPath(value, entry.label)
            end
        end

        for _, check in ipairs(provider.resolveChecks or {}) do
            if whenHolds(config, check.when) and not checkPasses(config, check) then
                error(check.message, 0)
            end
        end
    end

    function DefinitionResolver.resolveFromDefinition(definition)
        if definition.resolved then
            return util.copyTable(definition.resolved)
        end

        local config = definition.config or {}
        local source = config.source or {}
        local extract = config.extract or {}
        local naming = config.naming or {}
        local selectedSpoonName = nameResolver.infer(source.selection_spoon, "selected Spoon name")
        local installName = nameResolver.infer(naming.withName, "explicit Spoon name")
            or selectedSpoonName
            or nameResolver.infer(extract.useFolder, "extract folder")
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

        runResolveChecks(provider, config)

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
            options = util.mergeTables(manager.installOptions, config.installOptions or {}),
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
