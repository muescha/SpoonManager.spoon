return function(context)
    local Installed = {}
    local manager = context.manager
    local registry = context.registry
    local util = context.util

    local function entryPath(entry)
        if entry.registryMeta and entry.registryMeta.path then
            return entry.registryMeta.path
        end

        if entry.result and entry.result.path then
            return entry.result.path
        end

        if entry.command and entry.command.target and entry.command.target.path then
            return entry.command.target.path
        end

        return nil
    end

    local function create(selection)
        selection = selection or {}
        local installed = registry.read()
        local names = selection.names or util.sortedKeys(installed)
        local api = {
            kind = "installed",
            scope = selection.names and "spoon" or "all",
            name = selection.names and selection.names[1] or nil,
        }
        if selection.names then
            api.registered = installed[api.name] ~= nil
        else
            api.count = #names
            api.names = util.copyTable(names)
        end

        function api.list()
            local installed = registry.read()
            local entries = {}
            local names = selection.names or util.sortedKeys(installed)

            for _, name in ipairs(names) do
                if installed[name] then
                    entries[#entries + 1] = util.copyTable(installed[name])
                end
            end

            return entries
        end

        function api.update()
            local installed = registry.read()
            local definitions = {}
            local names = selection.names or util.sortedKeys(installed)

            for _, name in ipairs(names) do
                local entry = installed[name]
                if not entry then
                    error("Installed Spoon not found: " .. name, 2)
                end

                if not entry.config then
                    error("Installed Spoon has no config: " .. name, 2)
                end

                definitions[#definitions + 1] = util.copyTable(entry.config)
            end

            if #definitions == 0 then
                return {
                    success = true,
                    action = "update",
                    runs = {},
                }
            end

            return manager.update(definitions)
        end

        function api.doctor()
            local installed = registry.read()
            local result = {
                success = true,
                checks = {},
            }
            local names = selection.names or util.sortedKeys(installed)

            for _, name in ipairs(names) do
                local entry = installed[name]
                if not entry then
                    result.success = false
                    result.checks[#result.checks + 1] = {
                        name = name,
                        installed = false,
                        reason = "missing-registry-entry",
                    }
                else
                    local path = entryPath(entry)
                    local check = {
                        name = name,
                        path = path,
                        installed = path and util.fileExists(path) or false,
                        definition = util.copyTable(entry),
                    }

                    if not path then
                        check.reason = "missing-path"
                        result.success = false
                    elseif not check.installed then
                        check.reason = "missing-folder"
                        result.success = false
                    end

                    result.checks[#result.checks + 1] = check
                end
            end

            return result
        end

        function api.spoon(name)
            assert(type(name) == "string", "Installed Spoon name must be a string")
            return create({
                names = {
                    name,
                },
            })
        end

        return api
    end

    return {
        create = create,
    }
end
