local function shellQuote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function run(command)
    local handle = io.popen(command .. " 2>&1")
    if not handle then
        return nil, false
    end

    local output = handle:read("*a")
    local ok = handle:close()
    return output, ok == true
end

local function ensureDir(path)
    local _, ok = run("/bin/mkdir -p " .. shellQuote(path))
    return ok
end

local function writeFile(path, value)
    ensureDir(path:match("^(.*)/[^/]+$"))

    local file, err = io.open(path, "w")
    if not file then
        error(err)
    end

    file:write(value)
    file:close()
end

local function fileExists(path)
    local _, ok = run("/bin/test -e " .. shellQuote(path))
    return ok
end

local function installRealHammerspoonStub(repoRoot, configdir)
    local json = dofile(repoRoot .. "/tests/helpers/json.lua")

    hs = {
        configdir = configdir,
        json = json,
        logger = {
            new = function()
                return {
                    df = function() end,
                    ef = function() end,
                    i = function() end,
                    w = function() end,
                }
            end,
        },
        spoons = {
            scriptPath = function()
                return repoRoot
            end,
            use = function()
                return true
            end,
        },
        fs = {
            pathToAbsolute = function(path)
                return path:gsub("^~", "/Users/test")
            end,
            attributes = function(path)
                if fileExists(path) then
                    return {}
                end
                return nil
            end,
        },
        execute = function(command)
            return run(command)
        end,
        http = {
            get = function()
                return 500, ""
            end,
        },
    }
end

local function makeFixtureZip(tmpRoot)
    local fixtureRoot = tmpRoot .. "/fixture"
    local archiveRoot = fixtureRoot .. "/DownloadArchive"
    local zipFile = tmpRoot .. "/VendorBundle.zip"

    ensureDir(archiveRoot .. "/bundles/releases/current/WidgetKit.spoon")
    ensureDir(archiveRoot .. "/bundles/releases/archive/UnusedWidget.spoon")

    writeFile(archiveRoot .. "/bundles/releases/current/WidgetKit.spoon/init.lua", "return { name = 'WidgetKit' }\n")
    writeFile(archiveRoot .. "/bundles/releases/current/WidgetKit.spoon/asset.txt", "widget asset\n")
    writeFile(archiveRoot .. "/bundles/releases/archive/UnusedWidget.spoon/init.lua", "return { name = 'UnusedWidget' }\n")

    local output, ok = run(
        "cd " .. shellQuote(fixtureRoot)
            .. " && /usr/bin/zip -qr "
            .. shellQuote(zipFile)
            .. " DownloadArchive"
    )

    if not ok then
        error("Could not create fixture zip: " .. tostring(output))
    end

    return zipFile
end

return function(T)
    T.test("local zip folder selection installs the selected Spoon folder", function()
        local tmpRoot = "/tmp/spoonmanager-local-zip-folder-test"
        local configdir = tmpRoot .. "/hammerspoon"
        local originalHs = hs

        run("/bin/rm -rf " .. shellQuote(tmpRoot))
        ensureDir(tmpRoot)

        local zipFile = makeFixtureZip(tmpRoot)
        installRealHammerspoonStub(T.repoRoot, configdir)

        local SpoonManager = dofile(T.repoRoot .. "/init.lua")
        local ok, result, err = pcall(function()
            return SpoonManager.from.localZip(zipFile)
                .folder("bundles/releases/current/WidgetKit.spoon")
                .install()
        end)

        hs = originalHs

        if not ok then
            error(result, 2)
        end

        T.assertTrue(result ~= nil, err)
        T.assertEqual(result.name, "WidgetKit")
        T.assertTrue(fileExists(configdir .. "/Spoons/WidgetKit.spoon/init.lua"))
        T.assertTrue(fileExists(configdir .. "/Spoons/WidgetKit.spoon/asset.txt"))
        T.assertFalse(fileExists(configdir .. "/Spoons/UnusedWidget.spoon/init.lua"))
    end)
end
