return function(T)
    local json = dofile(T.repoRoot .. "/tests/helpers/json.lua")

    local function assertBuilderConfig(name, builder, expected)
        local actualConfig = builder.toConfig()
        local expectedConfig = T.SpoonManager.from.config(expected).toConfig()

        local actualJson = json.encode(actualConfig)
        local expectedJson = json.encode(expectedConfig)

        T.assertEqual(actualJson, expectedJson, name)
    end

    T.test("builder creates github folder definition", function()
        assertBuilderConfig(
            "github folder builder config",
            T.SpoonManager.from.github("Hammerspoon/Spoons", {
                branch = "master",
            })
                .folder("Source/WindowSigils.spoon")
                .withName("WindowSigils"),
            {
                source = {
                    type = "github",
                    provider = "github",
                    repository = "Hammerspoon/Spoons",
                    baseUrl = "https://github.com",
                    revision_branch = "master",
                },
                target = {
                    selection_folder = "Source/WindowSigils.spoon",
                    name_withName = "WindowSigils",
                },
            }
        )
    end)

    T.test("builder creates spoon repo folder pattern definition", function()
        assertBuilderConfig(
            "spoon repo builder config",
            T.SpoonManager.from.spoonRepo("Hammerspoon/Spoons", {
                branch = "master",
            })
                .spoon("WindowSigils"),
            {
                source = {
                    type = "github",
                    provider = "github",
                    repository = "Hammerspoon/Spoons",
                    baseUrl = "https://github.com",
                    revision_branch = "master",
                    pattern_spoonFolderPattern = "Source/{name}.spoon",
                },
                target = {
                    selection_spoon = "WindowSigils",
                },
            }
        )
    end)

    T.test("builder creates spoon repo zip pattern definition", function()
        assertBuilderConfig(
            "spoon repo zip builder config",
            T.SpoonManager.from.spoonRepoZip("Hammerspoon/Spoons", {
                branch = "master",
            })
                .spoon("WindowSigils"),
            {
                source = {
                    type = "github",
                    provider = "github",
                    repository = "Hammerspoon/Spoons",
                    baseUrl = "https://github.com",
                    revision_branch = "master",
                    pattern_spoonZipPattern = "Spoons/{name}.spoon.zip",
                },
                target = {
                    selection_spoon = "WindowSigils",
                },
            }
        )
    end)

    T.test("builder creates github repository definition", function()
        assertBuilderConfig(
            "github repository builder config",
            T.SpoonManager.from.github("owner/TestSpoon.spoon", {
                branch = "main",
            })
                .withName("TestSpoon"),
            {
                source = {
                    type = "github",
                    provider = "github",
                    repository = "owner/TestSpoon.spoon",
                    baseUrl = "https://github.com",
                    revision_branch = "main",
                },
                target = {
                    name_withName = "TestSpoon",
                },
            }
        )
    end)

    T.test("builder creates github latest release asset definition", function()
        assertBuilderConfig(
            "github release builder config",
            T.SpoonManager.from.github("owner/TestSpoon.spoon")
                .releaseLatest()
                .asset("TestSpoon.zip")
                .withName("TestSpoon"),
            {
                source = {
                    type = "github",
                    provider = "github",
                    repository = "owner/TestSpoon.spoon",
                    baseUrl = "https://github.com",
                    release_releaseLatest = true,
                },
                target = {
                    selection_asset = "TestSpoon.zip",
                    name_withName = "TestSpoon",
                },
            }
        )
    end)

    T.test("builder creates remote zip definition", function()
        assertBuilderConfig(
            "remote zip builder config",
            T.SpoonManager.from.remoteZip("https://github.com/Hammerspoon/Spoons/raw/master/Spoons/AutoMuteOnSleep.spoon.zip"),
            {
                source = {
                    type = "remoteZip",
                    url = "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/AutoMuteOnSleep.spoon.zip",
                },
            }
        )
    end)

    T.test("builder creates named remote zip definition", function()
        assertBuilderConfig(
            "named remote zip builder config",
            T.SpoonManager.from.remoteZip("https://example.com/TestSpoon.zip")
                .withName("TestSpoon"),
            {
                source = {
                    type = "remoteZip",
                    url = "https://example.com/TestSpoon.zip",
                },
                target = {
                    name_withName = "TestSpoon",
                },
            }
        )
    end)
end
