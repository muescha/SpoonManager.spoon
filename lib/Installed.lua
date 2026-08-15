return function(context)
    local Installed = {}
    local registry = context.registry
    local util = context.util

    local function sortedKeys(map)
        local keys = {}
        for key in pairs(map or {}) do
            keys[#keys + 1] = key
        end
        table.sort(keys)
        return keys
    end

    local function create(selection)
        selection = selection or {}
        local api = {}

        function api.list()
            local installed = registry.read()
            local entries = {}
            local names = selection.names or sortedKeys(installed)

            for _, name in ipairs(names) do
                if installed[name] then
                    entries[#entries + 1] = util.copyTable(installed[name])
                end
            end

            return entries
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
