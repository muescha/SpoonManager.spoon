local Util = {}

function Util.shellQuote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

function Util.trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function Util.pathJoin(...)
    local parts = { ... }
    local path = table.concat(parts, "/")
    path = path:gsub("/+", "/")
    return path
end

function Util.copyTable(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}
    for key, child in pairs(value) do
        result[key] = Util.copyTable(child)
    end
    return result
end

function Util.mergeTables(base, extra)
    local result = Util.copyTable(base or {})
    for key, value in pairs(extra or {}) do
        result[key] = Util.copyTable(value)
    end
    return result
end

function Util.execute(command, logger, errfmt, ...)
    local output, ok = hs.execute(command)
    if ok then
        return Util.trim(output), true
    end

    if logger then
        logger.ef(errfmt or "Command failed: %s", ...)
        if output and output ~= "" then
            logger.ef("%s", output)
        end
    end

    return nil, false
end

function Util.ensureDir(path, logger)
    return Util.execute(
        "/bin/mkdir -p " .. Util.shellQuote(path),
        logger,
        "Could not create directory %s",
        path
    )
end

function Util.removePath(path, logger)
    return Util.execute(
        "/bin/rm -rf " .. Util.shellQuote(path),
        logger,
        "Could not remove %s",
        path
    )
end

function Util.copyPath(source, destination, logger)
    Util.removePath(destination, logger)
    return Util.execute(
        "/bin/cp -R " .. Util.shellQuote(source) .. " " .. Util.shellQuote(destination),
        logger,
        "Could not copy %s to %s",
        source,
        destination
    )
end

function Util.movePath(source, destination, logger)
    Util.removePath(destination, logger)
    return Util.execute(
        "/bin/mv " .. Util.shellQuote(source) .. " " .. Util.shellQuote(destination),
        logger,
        "Could not move %s to %s",
        source,
        destination
    )
end

function Util.fileExists(path)
    return hs.fs.attributes(path) ~= nil
end

function Util.localPath(path)
    Util.requireString(path, "Local path")

    if hs.fs.pathToAbsolute then
        return hs.fs.pathToAbsolute(path) or path
    end

    return path
end

function Util.requireString(value, label)
    if type(value) ~= "string" then
        error(string.format("%s must be a string, got %s", label or "Value", type(value)), 3)
    end

    return value
end

function Util.requireStringOptional(value, label)
    if value == nil then
        return nil
    end

    return Util.requireString(value, label)
end

function Util.createLabel(method, value)
    if value == true or value == nil then
        return "." .. method .. "()"
    end

    local escaped = tostring(value):gsub("'", "\\'")
    return "." .. method .. "('" .. escaped .. "')"
end

function Util.isZipPath(value)
    if type(value) ~= "string" then
        return false
    end

    local path = value:gsub("[?#].*$", ""):lower()
    return path:match("%.zip$") ~= nil
end

function Util.requireZipPath(value, label)
    Util.requireString(value, label or "ZIP source")

    if not Util.isZipPath(value) then
        error(string.format("%s must point to a .zip file: %s", label or "ZIP source", tostring(value)), 3)
    end

    return value
end

return Util
