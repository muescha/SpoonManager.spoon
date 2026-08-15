return function(context)
    local NameResolver = {}
    local logger = context.logger

    local function callSite(level)
        if not debug or not debug.getinfo then
            return nil
        end

        local info = debug.getinfo(level, "nSl")
        if not info then
            return nil
        end

        local source = info.short_src or info.source or "?"
        source = source:match("([^/]+%.lua)$") or source
        local name = info.name or "?"
        return string.format("%s:%s %s", source, tostring(info.currentline or "?"), name)
    end

    local function callerStack()
        local sites = {}

        for level = 5, 64 do
            local site = callSite(level)
            if not site then
                break
            end

            if site and not site:match("^NameResolver%.lua:") then
                table.insert(sites, site)
            end
        end

        if #sites > 0 then
            return table.concat(sites, "\n  <- ")
        end

        return "unknown"
    end

    function NameResolver.safe(name)
        if not name or name == "" then
            return nil
        end

        name = tostring(name)
        if name:find("[/\\]") or name:find("%.%.") then
            return nil
        end

        return name
    end

    function NameResolver.logInferred(name, kind, value)
        if name then
            logger.df("Inferred Spoon name '%s' from %s '%s'\nStacktrace:\n  <- %s", name, kind or "value", tostring(value), callerStack())
        else
            logger.df("Could not infer Spoon name from %s '%s'\nStacktrace:\n  <- %s", kind or "value", tostring(value), callerStack())
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

    -- Full install-name precedence in one place. Returns the install name and the
    -- selected Spoon name (the latter is also used for pattern expansion).
    function NameResolver.inferNames(config)
        local source = config.source or {}
        local extract = config.extract or {}
        local naming = config.naming or {}

        local selectedSpoonName = NameResolver.infer(source.selection_spoon, "selected Spoon name")

        local installName = NameResolver.infer(naming.withName, "explicit Spoon name")
            or selectedSpoonName
            or NameResolver.infer(extract.useFolder, "extract folder")
            or NameResolver.infer(source.zipFile, "ZIP file")
            or NameResolver.infer(source.selection_path, "source path")
            or NameResolver.infer(source.name, "source name")
            or NameResolver.infer(source.file, "source file")
            or NameResolver.infer(source.root, "source root")
            or NameResolver.infer(source.url, "URL")
            or NameResolver.infer(source.repository, "repository")

        return installName, selectedSpoonName
    end

    return NameResolver
end
