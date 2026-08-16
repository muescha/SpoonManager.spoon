-- Ports: a thin adapter boundary over the Hammerspoon host primitives.
--
-- Part of the Ports & Adapters (hexagonal) boundary. Each function is a faithful
-- pass-through to an `hs.*` primitive (or `os.date`), so routing a call site
-- through a port is behaviour-neutral. Tests can substitute an in-memory table
-- with the same shape; a later async variant (getAsync / task) slots in here.
--
-- Kept intentionally logic-free: higher-level helpers (Util.mkdir, cp, …) stay
-- in their modules and call these primitives.

local Ports = {
    exec = {
        run = function(...) return hs.execute(...) end,
    },
    fs = {
        attributes = function(...) return hs.fs.attributes(...) end,
        absolute = function(...) return hs.fs.pathToAbsolute(...) end,
    },
    http = {
        get = function(...) return hs.http.get(...) end,
    },
    json = {
        read = function(...) return hs.json.read(...) end,
        encode = function(...) return hs.json.encode(...) end,
        decode = function(...) return hs.json.decode(...) end,
    },
    spoons = {
        use = function(...) return hs.spoons.use(...) end,
        scriptPath = function(...) return hs.spoons.scriptPath(...) end,
    },
    clock = {
        nowIso = function() return os.date("!%Y-%m-%dT%H:%M:%SZ") end,
        stamp = function() return os.date("!%Y%m%dT%H%M%SZ") end,
    },
    config = {
        dir = function() return hs.configdir end,
    },
}

return Ports
