local Util = {}

function Util.shellQuote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

function Util.trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

-- Defense-in-depth: refuse to build a path/URL out of a traversal segment.
-- Untrusted segments are validated earlier (Util.requireSafeRelPath), so this
-- only fires if something slipped past that boundary.
local function assertSafeSegment(part)
    if type(part) == "string" and part:find("%.%.") then
        error("path segment must not contain '..': " .. part, 3)
    end
end

-- Join path segments, skipping nil ones (like joinUrl), and collapse slashes.
function Util.pathJoin(...)
    local parts = {}
    for i = 1, select("#", ...) do
        local part = select(i, ...)
        if part ~= nil then
            assertSafeSegment(part)
            parts[#parts + 1] = part
        end
    end

    return (table.concat(parts, "/"):gsub("/+", "/"))
end

-- Join URL segments without collapsing the "scheme://" slashes (unlike pathJoin).
-- Uses select so nil segments (e.g. an unset path) are skipped, not truncated.
function Util.joinUrl(...)
    local url = ""
    for i = 1, select("#", ...) do
        local part = select(i, ...)
        assertSafeSegment(part)
        if part and part ~= "" then
            if url == "" then
                url = part
            else
                url = url:gsub("/+$", "") .. "/" .. part:gsub("^/+", "")
            end
        end
    end
    return url
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

local function ignoredNames(options)
    options = options or {}
    local names = {
        ".DS_Store",
        "__MACOSX",
        "._*",
        ".git",
    }

    for _, name in ipairs(options.excludeFolders or options.ignoreFolders or {}) do
        names[#names + 1] = name
    end

    return names
end

local function appendFindNamePrune(command, names)
    command[#command + 1] = "\\("
    for index, name in ipairs(names) do
        if index > 1 then
            command[#command + 1] = "-o"
        end
        command[#command + 1] = "-name"
        command[#command + 1] = Util.shellQuote(name)
    end
    command[#command + 1] = "\\)"
end

function Util.hashDirectory(path, options, logger)
    if not Util.fileExists(path) then
        return nil
    end

    local command = {
        "/usr/bin/find",
        Util.shellQuote(path),
    }

    appendFindNamePrune(command, ignoredNames(options))
    command[#command + 1] = "-prune"
    command[#command + 1] = "-o"
    command[#command + 1] = "-type f"
    command[#command + 1] = "-print0"
    command[#command + 1] = "|"
    command[#command + 1] = "/usr/bin/xargs -0 /usr/bin/shasum -a 256"
    command[#command + 1] = "|"
    command[#command + 1] = "/usr/bin/shasum -a 256"
    command[#command + 1] = "|"
    command[#command + 1] = "/usr/bin/awk '{ print $1 }'"

    return Util.execute(table.concat(command, " "), logger, "Could not hash %s", path)
end

function Util.removeIgnoredNames(path, options, logger)
    if not Util.fileExists(path) then
        return true
    end

    local command = {
        "/usr/bin/find",
        Util.shellQuote(path),
    }

    appendFindNamePrune(command, ignoredNames(options))
    command[#command + 1] = "-prune"
    command[#command + 1] = "-exec"
    command[#command + 1] = "/bin/rm -rf {} +"

    local _, ok = Util.execute(table.concat(command, " "), logger, "Could not remove ignored names in %s", path)
    return ok
end

function Util.localPath(path)
    Util.requireString(path, "Local path")

    if hs.fs.pathToAbsolute then
        return hs.fs.pathToAbsolute(path) or path
    end

    return path
end

-- Reject path traversal in an untrusted relative path segment (allows "/" for
-- subpaths, but forbids ".." and backslashes). Used for selection paths and
-- extract folders, which may arrive from a config/manifest and reach pathJoin.
-- Build a field error message from a reason clause. With a sourceRef, prefix with
-- the setter label ".method('value')"; without one, use the plain label and append
-- ": value". So createMessage("must point to a .zip file", "ZIP file", v, ref).
local function createMessage(reason, label, value, sourceRef)
    if sourceRef then
        return Util.createLabel(sourceRef, value) .. " " .. reason
    end

    return label .. " " .. reason .. ": " .. tostring(value)
end

function Util.requireSafeRelPath(value, label, sourceRef)
    Util.requireString(value, label)

    if value:find("%.%.") then
        error(createMessage("must not contain '..'", label or "Path", value, sourceRef), 3)
    end

    if value:find("\\", 1, true) then
        error(createMessage("must not contain a backslash", label or "Path", value, sourceRef), 3)
    end

    return value
end

-- Reject any path separator in an untrusted file name (a bare name, no directory).
-- Slash-free means it cannot traverse; used for zipFile at the builder and resolve.
function Util.requireSafeFileName(value, label, sourceRef)
    Util.requireString(value, label)

    if value:find("[/\\]") then
        error(createMessage("must be a file name, not a path", label or "File name", value, sourceRef), 3)
    end

    return value
end

function Util.requireSafeFileNames(values, label, sourceRef)
    if type(values) ~= "table" then
        error(string.format("%s must be a table, got %s", label or "File names", type(values)), 3)
    end

    for _, value in ipairs(values) do
        Util.requireSafeFileName(value, label, sourceRef)
    end

    return values
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

-- Builds a setter label like ".path('value')". `method` may be a plain method name
-- or a field ref ("source.selection_path") -- the last "." / "_" segment is used.
function Util.createLabel(method, value)
    method = tostring(method):match("[^._]+$") or method

    if value == true or value == nil then
        return "." .. method .. "()"
    end

    local escaped = tostring(value):gsub("'", "\\'")
    return "." .. method .. "('" .. escaped .. "')"
end

function Util.findFlatGroupValue(container, group)
    local prefix = group .. "_"

    for key, value in pairs(container or {}) do
        if type(key) == "string" and key:sub(1, #prefix) == prefix then
            return key:sub(#prefix + 1), value, key
        end
    end

    return nil, nil, nil
end

function Util.isZipPath(value)
    if type(value) ~= "string" then
        return false
    end

    local path = value:gsub("[?#].*$", ""):lower()
    return path:match("%.zip$") ~= nil
end

function Util.requireZipPath(value, label, sourceRef)
    Util.requireString(value, label or "ZIP source")

    if not Util.isZipPath(value) then
        error(createMessage("must point to a .zip file", label or "ZIP source", value, sourceRef), 3)
    end

    return value
end

return Util
