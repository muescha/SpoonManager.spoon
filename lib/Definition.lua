return function(context)
    local Definition = {}
    Definition.__index = Definition

    local manager = context.manager
    local nameResolver = context.nameResolver
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

    local function fromState(state)
        local def = util.copyTable(state)

        local api = {}

        api.toConfig = function()
            return util.copyTable(def)
        end

        api.branch = function(branchName)
            util.requireString(branchName, "Branch name")

            local nextDef = util.copyTable(def)
            ensureNotFinalized(nextDef, "branch", branchName)
            setExclusive(ensureSection(nextDef, "source"), "revision", "branch", branchName)
            return fromState(nextDef)
        end

        api.ref = function(refName)
            util.requireString(refName, "Ref name")

            local nextDef = util.copyTable(def)
            ensureNotFinalized(nextDef, "ref", refName)
            setExclusive(ensureSection(nextDef, "source"), "revision", "ref", refName)
            return fromState(nextDef)
        end

        api.spoonZipPattern = function(pattern)
            util.requireZipPath(pattern, "Spoon ZIP pattern")

            local nextDef = util.copyTable(def)
            ensureNotFinalized(nextDef, "spoonZipPattern", pattern)
            setExclusive(ensureSection(nextDef, "source"), "pattern", "spoonZipPattern", pattern)
            return fromState(nextDef)
        end

        api.spoonFolderPattern = function(pattern)
            util.requireString(pattern, "Spoon folder pattern")

            local nextDef = util.copyTable(def)
            ensureNotFinalized(nextDef, "spoonFolderPattern", pattern)
            setExclusive(ensureSection(nextDef, "source"), "pattern", "spoonFolderPattern", pattern)
            return fromState(nextDef)
        end

        api.spoon = function(value)
            util.requireString(value, "Spoon name")

            local spoonName = nameResolver.infer(value, "Spoon name")
            assert(spoonName, "Invalid Spoon name")

            local nextDef = util.copyTable(def)
            setExclusive(ensureSection(nextDef, "target"), "selection", "spoon", spoonName)
            return fromState(nextDef)
        end

        api.folder = function(path)
            util.requireString(path, "Folder path")

            local nextDef = util.copyTable(def)
            setExclusive(ensureSection(nextDef, "target"), "selection", "folder", path)
            return fromState(nextDef)
        end

        api.releaseLatest = function()
            local nextDef = util.copyTable(def)
            ensureNotFinalized(nextDef, "releaseLatest")
            requireNoRelease(nextDef, "releaseLatest")
            ensureSection(nextDef, "source").release = "latest"
            return fromState(nextDef)
        end

        api.release = function(releaseName)
            util.requireString(releaseName, "Release name")

            local nextDef = util.copyTable(def)
            ensureNotFinalized(nextDef, "release", releaseName)
            requireNoRelease(nextDef, "release", releaseName)
            ensureSection(nextDef, "source").release = releaseName
            return fromState(nextDef)
        end

        api.asset = function(assetName)
            util.requireZipPath(assetName, "Release asset")

            local nextDef = util.copyTable(def)
            setExclusive(ensureSection(nextDef, "target"), "selection", "asset", assetName)
            return fromState(nextDef)
        end

        api.withName = function(value)
            util.requireString(value, "Spoon name")

            local explicitName = nameResolver.infer(value, "explicit Spoon name")
            assert(explicitName, "Invalid Spoon name")

            local nextDef = util.copyTable(def)
            setExclusive(ensureSection(nextDef, "target"), "name", "withName", explicitName)
            nameResolver.logExplicit(explicitName, value)
            return fromState(nextDef)
        end

        api.use = function(useOptions)
            local nextDef = util.copyTable(def)
            nextDef.use = util.mergeTables(nextDef.use or {}, useOptions or {})
            return fromState(nextDef)
        end

        api.onLocalChanges = function(behavior)
            assert(manager._isLocalChangesBehavior(behavior), "Invalid local changes behavior: " .. tostring(behavior))

            local nextDef = util.copyTable(def)
            setExclusive(ensureSection(nextDef, "options"), "localChanges", "onLocalChanges", behavior)
            nextDef.options.onLocalChanges = behavior
            return fromState(nextDef)
        end

        api.add = function()
            manager.add(api)
            return api
        end

        api.install = function()
            return manager._installDefinition(def, "install")
        end

        api.update = function()
            return manager._installDefinition(def, "update")
        end

        return setmetatable(api, Definition)
    end

    return {
        findFlatGroupValue = findFlatGroupValue,
        fromState = fromState,
    }
end
