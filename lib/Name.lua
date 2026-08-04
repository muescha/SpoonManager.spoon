return function(context)
    local Name = {}
    local logger = context.logger

    function Name.safe(name)
        if not name or name == "" then
            return nil
        end

        name = tostring(name)
        if name:find("[/\\]") or name:find("%.%.", 1, true) then
            return nil
        end

        return name
    end

    function Name.logInferred(name, kind, value)
        if name then
            logger.df("Inferred Spoon name '%s' from %s '%s'", name, kind or "value", tostring(value))
        end
    end

    function Name.logExplicit(name, value)
        if name then
            logger.df("Using explicit Spoon name '%s' from '%s'", name, tostring(value))
        end
    end

    function Name.infer(value, kind)
        if not value then
            return nil
        end

        local cleaned = tostring(value)
        cleaned = cleaned:gsub("[?#].*$", "")
        cleaned = cleaned:gsub("/+$", "")

        local last = cleaned:match("([^/]+)$") or cleaned
        last = last:gsub("%.zip$", "")
        last = last:gsub("%.spoon$", "")

        local inferred = Name.safe(last)
        Name.logInferred(inferred, kind, value)
        return inferred
    end

    function Name.inferFromSource(source)
        if not source then
            return nil
        end

        return Name.infer(source.name, "source name")
            or Name.infer(source.path, "source path")
            or Name.infer(source.asset, "asset name")
            or Name.infer(source.url, "URL")
            or Name.infer(source.repository, "repository")
    end

    return Name
end
