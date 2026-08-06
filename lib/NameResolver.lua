return function(context)
    local NameResolver = {}
    local logger = context.logger

    function NameResolver.safe(name)
        if not name or name == "" then
            return nil
        end

        name = tostring(name)
        if name:find("[/\\]") or name:find("%.%.", 1, true) then
            return nil
        end

        return name
    end

    function NameResolver.logInferred(name, kind, value)
        if name then
            logger.df("Inferred Spoon name '%s' from %s '%s'", name, kind or "value", tostring(value))
        else
            logger.df("Could not infer Spoon name from %s '%s'", kind or "value", tostring(value))
        end
    end

    function NameResolver.logExplicit(name, value)
        if name then
            logger.df("Using explicit Spoon name '%s' from '%s'", name, tostring(value))
        end
    end

    function NameResolver.infer(value, kind)
        if not value then
            return nil
        end

        local cleaned = tostring(value)
        cleaned = cleaned:gsub("[?#].*$", "")
        cleaned = cleaned:gsub("/+$", "")

        local last = cleaned:match("([^/]+)$") or cleaned
        last = last:gsub("%.zip$", "")
        last = last:gsub("%.spoon$", "")

        local inferred = NameResolver.safe(last)
        NameResolver.logInferred(inferred, kind, value)
        return inferred
    end

    function NameResolver.inferFromSource(source)
        if not source then
            return nil
        end

        return NameResolver.infer(source.name, "source name")
            or NameResolver.infer(source.path, "source path")
            or NameResolver.infer(source.url, "URL")
            or NameResolver.infer(source.repository, "repository")
    end

    function NameResolver.inferFromTarget(target)
        if not target then
            return nil
        end

        return NameResolver.infer(target.selection_spoon, "selected Spoon name")
            or NameResolver.infer(target.selection_folder, "selected folder")
            or NameResolver.infer(target.selection_asset, "selected asset")
    end

    return NameResolver
end
