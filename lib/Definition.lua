return function(context)
    local Definition = {}
    Definition.__index = Definition

    local manager = context.manager
    local name = context.name
    local util = context.util

    local function fromState(state)
        local def = util.copyTable(state)
        local api = {}

        api.build = function()
            return util.copyTable(def)
        end

        api.asSpoon = function(value)
            local nextDef = util.copyTable(def)
            nextDef.name = name.infer(value, "explicit Spoon name")
            name.logExplicit(nextDef.name, value)
            return fromState(nextDef)
        end

        api.use = function(useOptions)
            local nextDef = util.copyTable(def)
            nextDef.use = util.mergeTables(nextDef.use or {}, useOptions or {})
            return fromState(nextDef)
        end

        api.onLocalChanges = function(behavior)
            local nextDef = util.copyTable(def)
            nextDef.options = util.mergeTables(nextDef.options or {}, { onLocalChanges = behavior })
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
        fromState = fromState,
    }
end
