return function(context)
    local Definition = {}
    Definition.__index = Definition

    local manager = context.manager
    local resolver = context.resolver
    local util = context.util

    local function ensureSection(config, sectionName)
        config[sectionName] = util.copyTable(config[sectionName] or {})
        return config[sectionName]
    end

    local function findFlatGroupValue(container, group)
        local prefix = group .. "_"

        for key, value in pairs(container or {}) do
            if type(key) == "string" and key:sub(1, #prefix) == prefix then
                return key:sub(#prefix + 1), value, key
            end
        end

        return nil, nil, nil
    end

    local function setExclusive(container, group, method, value)
        local existingMethod, existingValue = findFlatGroupValue(container, group)

        if existingMethod then
            error(string.format(
                "%s already set; cannot call %s.",
                util.createLabel(existingMethod, existingValue),
                util.createLabel(method, value)
            ), 3)
        end

        container[group .. "_" .. method] = value
    end

    local function ensureNotFinalized(definition, method, value)
        local selectedMethod, selectedValue = findFlatGroupValue(definition.config.target, "selection")

        if selectedMethod then
            error(string.format(
                "%s already selected; cannot call %s. Start from the base definition instead.",
                util.createLabel(selectedMethod, selectedValue),
                util.createLabel(method, value)
            ), 3)
        end
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

        if value:find("[/\\]") then
            error(string.format("%s must be a file name, not a path: %s", label, tostring(value)), 3)
        end
    end

    local function requireSpoonPattern(definition)
        local source = definition.config.source or {}

        if source.pattern_spoonZipPattern or source.pattern_spoonFolderPattern then
            return
        end

        error(".spoon() requires .spoonZipPattern(...) or .spoonFolderPattern(...) on this source.", 3)
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

        local api = {}

        api.toConfig = function()
            return util.copyTable(def.config)
        end

        api.explain = function()
            return resolver.explain(def)
        end

        api.resolve = function()
            def = resolver.withResolved(def)
            def.state = computeState(def)
            return api
        end

        api.command = function(action)
            def = resolver.withCommand(def, action)
            def.state = computeState(def)
            return api
        end

        api.branch = function(branchName)
            util.requireString(branchName, "Branch name")

            local nextDef = util.copyTable(def)
            ensureState(nextDef, "config", "branch", branchName)
            requireCapability(nextDef, "branch", "branch", branchName)
            ensureNotFinalized(nextDef, "branch", branchName)
            setExclusive(ensureSection(nextDef.config, "source"), "revision", "branch", branchName)
            return createDefinition(nextDef)
        end

        api.ref = function(refName)
            util.requireString(refName, "Ref name")

            local nextDef = util.copyTable(def)
            ensureState(nextDef, "config", "ref", refName)
            requireCapability(nextDef, "ref", "ref", refName)
            ensureNotFinalized(nextDef, "ref", refName)
            setExclusive(ensureSection(nextDef.config, "source"), "revision", "ref", refName)
            return createDefinition(nextDef)
        end

        api.spoonZipPattern = function(pattern)
            util.requireZipPath(pattern, "Spoon ZIP pattern")

            local nextDef = util.copyTable(def)
            ensureState(nextDef, "config", "spoonZipPattern", pattern)
            requireCapability(nextDef, "spoonZipPattern", "spoonZipPattern", pattern)
            ensureNotFinalized(nextDef, "spoonZipPattern", pattern)
            setExclusive(ensureSection(nextDef.config, "source"), "pattern", "spoonZipPattern", pattern)
            return createDefinition(nextDef)
        end

        api.spoonFolderPattern = function(pattern)
            util.requireString(pattern, "Spoon folder pattern")

            local nextDef = util.copyTable(def)
            ensureState(nextDef, "config", "spoonFolderPattern", pattern)
            requireCapability(nextDef, "spoonFolderPattern", "spoonFolderPattern", pattern)
            ensureNotFinalized(nextDef, "spoonFolderPattern", pattern)
            setExclusive(ensureSection(nextDef.config, "source"), "pattern", "spoonFolderPattern", pattern)
            return createDefinition(nextDef)
        end

        api.spoon = function(value)
            util.requireString(value, "Spoon name")
            ensureState(def, "config", "spoon", value)
            requireSpoonPattern(def)

            local nextDef = util.copyTable(def)
            setExclusive(ensureSection(nextDef.config, "target"), "selection", "spoon", value)
            return createDefinition(nextDef)
        end

        api.path = function(path)
            util.requireString(path, "Source path")

            local nextDef = util.copyTable(def)
            ensureState(nextDef, "config", "path", path)
            requireCapability(nextDef, "path", "path", path)
            ensureNotFinalized(nextDef, "path", path)

            local source = ensureSection(nextDef.config, "source")
            local releaseMethod, releaseValue = findFlatGroupValue(source, "release")
            if releaseMethod then
                error(string.format(
                    ".%s already set; cannot call %s.",
                    util.createLabel(releaseMethod, releaseValue):sub(2),
                    util.createLabel("path", path)
                ), 3)
            end

            local patternMethod, patternValue = findFlatGroupValue(source, "pattern")
            if patternMethod then
                error(string.format(
                    ".%s already set; cannot call %s.",
                    util.createLabel(patternMethod, patternValue):sub(2),
                    util.createLabel("path", path)
                ), 3)
            end

            if source.path then
                error(string.format(
                    "%s already set; cannot call %s.",
                    util.createLabel("path", source.path),
                    util.createLabel("path", path)
                ), 3)
            end

            source.path = path
            return createDefinition(nextDef)
        end

        api.useFolder = function(path)
            util.requireString(path, "Folder path")

            local nextDef = util.copyTable(def)
            ensureState(nextDef, "config", "useFolder", path)
            requireCapability(nextDef, "useFolder", "useFolder", path)

            local extract = ensureSection(nextDef.config, "extract")
            if extract.folder then
                error(string.format(
                    "%s already set; cannot call %s.",
                    util.createLabel("useFolder", extract.folder),
                    util.createLabel("useFolder", path)
                ), 3)
            end

            extract.folder = path
            return createDefinition(nextDef)
        end

        api.releaseLatest = function()
            local nextDef = util.copyTable(def)
            ensureState(nextDef, "config", "releaseLatest")
            requireCapability(nextDef, "release", "releaseLatest")
            if nextDef.config.source and nextDef.config.source.path then
                error(string.format(
                    "%s already set; cannot call %s.",
                    util.createLabel("path", nextDef.config.source.path),
                    util.createLabel("releaseLatest")
                ), 3)
            end
            ensureNotFinalized(nextDef, "releaseLatest")
            setExclusive(ensureSection(nextDef.config, "source"), "release", "releaseLatest", true)
            return createDefinition(nextDef)
        end

        api.release = function(releaseName)
            util.requireString(releaseName, "Release name")

            local nextDef = util.copyTable(def)
            ensureState(nextDef, "config", "release", releaseName)
            requireCapability(nextDef, "release", "release", releaseName)
            if nextDef.config.source and nextDef.config.source.path then
                error(string.format(
                    "%s already set; cannot call %s.",
                    util.createLabel("path", nextDef.config.source.path),
                    util.createLabel("release", releaseName)
                ), 3)
            end
            ensureNotFinalized(nextDef, "release", releaseName)
            setExclusive(ensureSection(nextDef.config, "source"), "release", "release", releaseName)
            return createDefinition(nextDef)
        end

        api.zipFile = function(fileName)
            requireFileName(fileName, "ZIP file")

            local nextDef = util.copyTable(def)
            ensureState(nextDef, "config", "zipFile", fileName)
            requireCapability(nextDef, "zipFile", "zipFile", fileName)

            local source = ensureSection(nextDef.config, "source")
            if source.zipFile then
                error(string.format(
                    "%s already set; cannot call %s.",
                    util.createLabel("zipFile", source.zipFile),
                    util.createLabel("zipFile", fileName)
                ), 3)
            end

            source.zipFile = fileName
            return createDefinition(nextDef)
        end

        api.withName = function(value)
            util.requireString(value, "Spoon name")
            ensureState(def, "config", "withName", value)

            local nextDef = util.copyTable(def)
            setExclusive(ensureSection(nextDef.config, "target"), "name", "withName", value)
            return createDefinition(nextDef)
        end

        api.use = function(useOptions)
            local nextDef = util.copyTable(def)
            ensureState(nextDef, "config", "use")
            nextDef.config.use = util.mergeTables(nextDef.config.use or {}, useOptions or {})
            return createDefinition(nextDef)
        end

        api.onLocalChanges = function(behavior)
            assert(manager._isLocalChangesBehavior(behavior), "Invalid local changes behavior: " .. tostring(behavior))

            local nextDef = util.copyTable(def)
            ensureState(nextDef, "config", "onLocalChanges", behavior)
            setExclusive(ensureSection(nextDef.config, "options"), "localChanges", "onLocalChanges", behavior)
            nextDef.config.options.onLocalChanges = behavior
            return createDefinition(nextDef)
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

        return setmetatable(api, Definition)
    end

    return {
        findFlatGroupValue = findFlatGroupValue,
        createDefinition = createDefinition,
    }
end
