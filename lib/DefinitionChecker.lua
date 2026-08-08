return function(context)
    local DefinitionChecker = {}
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
        if when.field then
            return readRef(config, when.field) ~= nil
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
    function DefinitionChecker.run(provider, config)
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

    return DefinitionChecker
end
