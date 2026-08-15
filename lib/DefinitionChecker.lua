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

    -- Returns the ref that made the condition hold (truthy), else nil. The matched
    -- ref lets a message reference the triggering field via the {when} placeholder.
    local function whenHolds(config, when)
        if when.field then
            return readRef(config, when.field) ~= nil and when.field or nil
        end

        if when.anyField then
            for _, ref in ipairs(when.anyField) do
                if readRef(config, ref) ~= nil then
                    return ref
                end
            end
            return nil
        end

        if when.isZip then
            return util.isZipPath(readRef(config, when.isZip)) and when.isZip or nil
        end

        if when.notZip then
            return not util.isZipPath(readRef(config, when.notZip)) and when.notZip or nil
        end

        return nil
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

    -- Untrusted inputs sanitized for every provider (blanket policy); covers configs
    -- that bypass the builder setters (from.config / a manifest). Paths may contain
    -- "/" (subpaths) but no "..", a zipFile must be a bare file name (no separators).
    local safeFields = {
        { ref = "source.selection_path", label = "Source path", check = util.requireSafeRelPath },
        { ref = "extract.useFolder", label = "Folder path", check = util.requireSafeRelPath },
        { ref = "source.zipFile", label = "ZIP file", check = util.requireSafeFileName },
        { ref = "source.zipFile", label = "ZIP file", check = util.requireZipPath },
        { ref = "source.excludeFolders", label = "Excluded folder", check = util.requireSafeFileNames },
    }

    -- Expand {ref} placeholders in a check message to a setter label ".m('value')".
    -- {when} resolves to the ref that triggered the check (e.g. the set release field).
    local function expandMessage(message, config, whenRef)
        return (message:gsub("{(.-)}", function(token)
            local ref = token == "when" and whenRef or token
            return util.createLabel(ref, readRef(config, ref))
        end))
    end

    -- Run the blanket input-safety pass plus a provider's declarative resolveChecks
    -- (logical cross-field checks) before handing the config to its resolution rules.
    function DefinitionChecker.run(provider, config)
        for _, entry in ipairs(safeFields) do
            local value = readRef(config, entry.ref)
            if value then
                entry.check(value, entry.label, entry.ref)
            end
        end

        for _, check in ipairs(provider.resolveChecks or {}) do
            local whenRef = whenHolds(config, check.when)
            if whenRef and not checkPasses(config, check) then
                error(expandMessage(check.message, config, whenRef), 0)
            end
        end
    end

    return DefinitionChecker
end
