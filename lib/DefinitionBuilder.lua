return function(context)
    local DefinitionBuilder = {}
    DefinitionBuilder.__index = DefinitionBuilder

    local manager = context.manager
    local definitionResolver = context.definitionResolver
    local util = context.util

    local function ensureSection(config, sectionName)
        config[sectionName] = util.copyTable(config[sectionName] or {})
        return config[sectionName]
    end

    local function setExclusive(container, group, method, value)
        local containerKey = group == nil and method or group .. "_" .. method
        local existingMethod, existingValue
        if group == nil then
            if container[containerKey] ~= nil then
                existingMethod, existingValue = method, container[containerKey]
            end
        else
            existingMethod, existingValue = util.findFlatGroupValue(container, group)
        end

        if existingMethod then
            error(string.format(
                "%s already set; cannot call %s.",
                util.createLabel(existingMethod, existingValue),
                util.createLabel(method, value)
            ), 3)
        end

        container[containerKey] = value
    end

    local function computeState(definition)
        if definition.command then
            return "command"
        end

        if definition.resolved then
            return "resolved"
        end

        return "config"
    end

    local function ensureState(definition, required, method, value)
        local state = definition.state or computeState(definition)

        if state ~= required then
            error(string.format(
                "definition already has %s values; cannot call %s. Start from the base definition instead.",
                state,
                util.createLabel(method, value)
            ), 3)
        end
    end

    local function requireCapability(definition, capability, method, value)
        local source = definition.config.source or {}
        local provider = manager.providers[source.type]

        if not provider then
            error("Unsupported source type: " .. tostring(source.type), 3)
        end

        if not provider.capabilities or not provider.capabilities[capability] then
            error(string.format(
                "%s source does not support %s.",
                tostring(source.type),
                util.createLabel(method, value)
            ), 3)
        end
    end

    local function requireFileName(value, label)
        util.requireZipPath(value, label)
        util.requireSafeFileName(value, label)
    end

    -- Declarative specs for the near-identical builder setters. Each stores a value
    -- into a config section with a validator, an optional capability check, and an
    -- exclusivity group (nil = single-field guard). `fixedValue` is for no-arg calls.
    local setterSpecs = {
        {
            method = "branch",
            validate = util.requireString,
            label = "Branch name",
            section = "source",
            group = "revision",
        },
        {
            method = "ref",
            validate = util.requireString,
            label = "Ref name",
            section = "source",
            group = "revision",
        },
        {
            method = "spoonZipPattern",
            validate = util.requireZipPath,
            label = "Spoon ZIP pattern",
            section = "source",
            group = "pattern",
        },
        {
            method = "spoonFolderPattern",
            validate = util.requireString,
            label = "Spoon folder pattern",
            section = "source",
            group = "pattern",
        },
        {
            method = "spoon",
            validate = util.requireString,
            label = "Spoon name",
            section = "source",
            group = "selection",
        },
        {
            method = "release",
            validate = util.requireString,
            label = "Release name",
            section = "source",
            group = "selection",
        },
        {
            method = "releaseLatest",
            fixedValue = true,
            section = "source",
            group = "selection",
        },
        {
            method = "zipFile",
            validate = requireFileName,
            label = "ZIP file",
            section = "source",
        },
        {
            method = "useFolder",
            validate = util.requireSafeRelPath,
            label = "Folder path",
            section = "extract",
        },
        {
            method = "excludeFolders",
            collect = function(...)
                return { ... }
            end,
            validate = function(value)
                util.requireSafeFileNames(value, "Excluded folder", "source.excludeFolders")
            end,
            section = "source",
        },
        {
            method = "withName",
            validate = util.requireString,
            label = "Spoon name",
            section = "naming",
        },
        {
            method = "conflictStrategy",
            section = "installOptions",
            validate = function(value)
                assert(manager._isConflictStrategy(value), "Invalid conflict strategy: " .. tostring(value))
            end,
        },
    }

    local function createBuilder(def)
        local api = {}

        api.toConfig = function()
            return util.copyTable(def.config)
        end

        api.explain = function()
            return definitionResolver.explain(def)
        end

        for _, spec in ipairs(setterSpecs) do
            api[spec.method] = function(...)
                local value = spec.collect and spec.collect(...) or select(1, ...)
                if spec.fixedValue ~= nil then
                    value = spec.fixedValue
                elseif spec.validate then
                    spec.validate(value, spec.label)
                end

                local nextDef = util.copyTable(def)
                ensureState(nextDef, "config", spec.method, value)
                requireCapability(nextDef, spec.method, spec.method, value)
                setExclusive(ensureSection(nextDef.config, spec.section), spec.group, spec.method, value)
                return createBuilder(nextDef)
            end
        end

        api.path = function(path)
            util.requireSafeRelPath(path, "Source path")

            local nextDef = util.copyTable(def)
            ensureState(nextDef, "config", "path", path)
            requireCapability(nextDef, "path", "path", path)

            local source = ensureSection(nextDef.config, "source")
            setExclusive(source, "selection", "path", path)

            local patternMethod, patternValue = util.findFlatGroupValue(source, "pattern")
            if patternMethod then
                error(string.format(
                    ".%s already set; cannot call %s.",
                    util.createLabel(patternMethod, patternValue):sub(2),
                    util.createLabel("path", path)
                ), 3)
            end

            return createBuilder(nextDef)
        end

        api.use = function(useOptions)
            local nextDef = util.copyTable(def)
            ensureState(nextDef, "config", "use")
            nextDef.config.use = util.mergeTables(nextDef.config.use or {}, useOptions or {})
            return createBuilder(nextDef)
        end

        api.add = function()
            manager.add(api)
            return api
        end

        api.install = function()
            local result, err, nextDef = manager._installAndRememberDefinition(def, "install")
            if nextDef then
                def = nextDef.config and nextDef or {
                    config = nextDef,
                }
            end
            return result, err
        end

        api.update = function()
            local result, err, nextDef = manager._installAndRememberDefinition(def, "update")
            if nextDef then
                def = nextDef.config and nextDef or {
                    config = nextDef,
                }
            end
            return result, err
        end

        return setmetatable(api, DefinitionBuilder)
    end

    local function createDefinition(input)
        local def

        if input and input.config then
            def = util.copyTable(input)
        else
            def = {
                config = util.copyTable(input or {}),
            }
        end

        def.state = computeState(def)
        return createBuilder(def)
    end

    return {
        createDefinition = createDefinition,
    }
end
