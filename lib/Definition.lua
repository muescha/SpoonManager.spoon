return function(context)
    local Definition = {}
    Definition.__index = Definition

    local manager = context.manager
    local resolver = context.resolver
    local util = context.util

    local function ensureSection(definition, sectionName)
        definition[sectionName] = util.copyTable(definition[sectionName] or {})
        return definition[sectionName]
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
        local selectedMethod, selectedValue = findFlatGroupValue(definition.target, "selection")

        if selectedMethod then
            error(string.format(
                "%s already selected; cannot call %s. Start from the base definition instead.",
                util.createLabel(selectedMethod, selectedValue),
                util.createLabel(method, value)
            ), 3)
        end
    end

    local function computedStage(definition)
        if definition.command then
            return "command"
        end

        if definition.resolved then
            return "resolved"
        end

        return nil
    end

    local function ensureNotComputed(definition, method, value)
        local stage = computedStage(definition)

        if stage then
            error(string.format(
                "definition already has %s values; cannot call %s. Start from the base definition instead.",
                stage,
                util.createLabel(method, value)
            ), 3)
        end
    end

    local function requireNoRelease(definition, method, value)
        local source = definition.source or {}

        if source.release then
            local existingMethod = source.release == "latest" and "releaseLatest" or "release"
            local existingValue = source.release == "latest" and nil or source.release

            error(string.format(
                "%s already set; cannot call %s.",
                util.createLabel(existingMethod, existingValue),
                util.createLabel(method, value)
            ), 3)
        end
    end

    local function requireSpoonPattern(definition)
        local source = definition.source or {}

        if source.pattern_spoonZipPattern or source.pattern_spoonFolderPattern then
            return
        end

        error(".spoon() requires .spoonZipPattern(...) or .spoonFolderPattern(...) on this source.", 3)
    end

    local function fromState(state)
        local def = util.copyTable(state)

        local api = {}

        api.toConfig = function()
            return util.copyTable(def)
        end

        api.explain = function()
            return resolver.explain(def)
        end

        api.resolve = function()
            def = resolver.withResolved(def)
            return api
        end

        api.command = function(action)
            def = resolver.withCommand(def, action)
            return api
        end

        api.branch = function(branchName)
            util.requireString(branchName, "Branch name")

            local nextDef = util.copyTable(def)
            ensureNotComputed(nextDef, "branch", branchName)
            ensureNotFinalized(nextDef, "branch", branchName)
            setExclusive(ensureSection(nextDef, "source"), "revision", "branch", branchName)
            return fromState(nextDef)
        end

        api.ref = function(refName)
            util.requireString(refName, "Ref name")

            local nextDef = util.copyTable(def)
            ensureNotComputed(nextDef, "ref", refName)
            ensureNotFinalized(nextDef, "ref", refName)
            setExclusive(ensureSection(nextDef, "source"), "revision", "ref", refName)
            return fromState(nextDef)
        end

        api.spoonZipPattern = function(pattern)
            util.requireZipPath(pattern, "Spoon ZIP pattern")

            local nextDef = util.copyTable(def)
            ensureNotComputed(nextDef, "spoonZipPattern", pattern)
            ensureNotFinalized(nextDef, "spoonZipPattern", pattern)
            setExclusive(ensureSection(nextDef, "source"), "pattern", "spoonZipPattern", pattern)
            return fromState(nextDef)
        end

        api.spoonFolderPattern = function(pattern)
            util.requireString(pattern, "Spoon folder pattern")

            local nextDef = util.copyTable(def)
            ensureNotComputed(nextDef, "spoonFolderPattern", pattern)
            ensureNotFinalized(nextDef, "spoonFolderPattern", pattern)
            setExclusive(ensureSection(nextDef, "source"), "pattern", "spoonFolderPattern", pattern)
            return fromState(nextDef)
        end

        api.spoon = function(value)
            util.requireString(value, "Spoon name")
            ensureNotComputed(def, "spoon", value)
            requireSpoonPattern(def)

            local nextDef = util.copyTable(def)
            setExclusive(ensureSection(nextDef, "target"), "selection", "spoon", value)
            return fromState(nextDef)
        end

        api.folder = function(path)
            util.requireString(path, "Folder path")

            local nextDef = util.copyTable(def)
            ensureNotComputed(nextDef, "folder", path)
            setExclusive(ensureSection(nextDef, "target"), "selection", "folder", path)
            return fromState(nextDef)
        end

        api.releaseLatest = function()
            local nextDef = util.copyTable(def)
            ensureNotComputed(nextDef, "releaseLatest")
            ensureNotFinalized(nextDef, "releaseLatest")
            requireNoRelease(nextDef, "releaseLatest")
            ensureSection(nextDef, "source").release = "latest"
            return fromState(nextDef)
        end

        api.release = function(releaseName)
            util.requireString(releaseName, "Release name")

            local nextDef = util.copyTable(def)
            ensureNotComputed(nextDef, "release", releaseName)
            ensureNotFinalized(nextDef, "release", releaseName)
            requireNoRelease(nextDef, "release", releaseName)
            ensureSection(nextDef, "source").release = releaseName
            return fromState(nextDef)
        end

        api.asset = function(assetName)
            util.requireZipPath(assetName, "Release asset")

            local nextDef = util.copyTable(def)
            ensureNotComputed(nextDef, "asset", assetName)
            setExclusive(ensureSection(nextDef, "target"), "selection", "asset", assetName)
            return fromState(nextDef)
        end

        api.withName = function(value)
            util.requireString(value, "Spoon name")
            ensureNotComputed(def, "withName", value)

            local nextDef = util.copyTable(def)
            setExclusive(ensureSection(nextDef, "target"), "name", "withName", value)
            return fromState(nextDef)
        end

        api.use = function(useOptions)
            local nextDef = util.copyTable(def)
            ensureNotComputed(nextDef, "use")
            nextDef.use = util.mergeTables(nextDef.use or {}, useOptions or {})
            return fromState(nextDef)
        end

        api.onLocalChanges = function(behavior)
            assert(manager._isLocalChangesBehavior(behavior), "Invalid local changes behavior: " .. tostring(behavior))

            local nextDef = util.copyTable(def)
            ensureNotComputed(nextDef, "onLocalChanges", behavior)
            setExclusive(ensureSection(nextDef, "options"), "localChanges", "onLocalChanges", behavior)
            nextDef.options.onLocalChanges = behavior
            return fromState(nextDef)
        end

        api.add = function()
            manager.add(api)
            return api
        end

        api.install = function()
            local result, err, nextDef = manager._installAndRememberDefinition(def, "install")
            def = nextDef or def
            return result, err
        end

        api.update = function()
            local result, err, nextDef = manager._installAndRememberDefinition(def, "update")
            def = nextDef or def
            return result, err
        end

        return setmetatable(api, Definition)
    end

    return {
        findFlatGroupValue = findFlatGroupValue,
        fromState = fromState,
    }
end
