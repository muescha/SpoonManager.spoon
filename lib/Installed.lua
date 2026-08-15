return function(context)
    local Installed = {}
    local manager = context.manager
    local registry = context.registry
    local util = context.util

    local function create(selection)
        selection = selection or {}
        local api = {}

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
