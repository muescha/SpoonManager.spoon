return function(T)
    T.test("definition resolver maps github repository root", function()
        local config =
            T.SpoonManager.from.github("muescha/MySpoon.spoon")
                .toConfig()
        local definition = {
            config = config,
        }

        local resolved = T.context.definitionResolver.resolveFromDefinition(definition)
        local command = T.context.definitionResolver.commandFromResolved(definition, "install", resolved)

        T.assertEqual(command.source.kind, "zip")
        T.assertEqual(command.source.url, "https://github.com/muescha/MySpoon.spoon/archive/main.zip")
        T.assertEqual(command.target.name, "MySpoon")
    end)

    T.test("definition resolver maps github folder pattern", function()
        local config =
            T.SpoonManager.from.github("owner/repo")
                .branch("main")
                .spoonFolderPattern("Source/{name}.spoon")
                .spoon("A")
                .toConfig()
        local definition = {
            config = config,
        }

        local resolved = T.context.definitionResolver.resolveFromDefinition(definition)
        local command = T.context.definitionResolver.commandFromResolved(definition, "update", resolved)

        T.assertEqual(command.action, "update")
        T.assertEqual(command.source.kind, "zip")
        T.assertEqual(command.source.folder, "Source/A.spoon")
        T.assertEqual(command.target.name, "A")
    end)

    T.test("definition resolver allows spoon selection before its pattern", function()
        local config =
            T.SpoonManager.from.github("owner/repo")
                .branch("main")
                .spoon("A")
                .spoonFolderPattern("Source/{name}.spoon")
                .toConfig()
        local definition = {
            config = config,
        }

        local resolved = T.context.definitionResolver.resolveFromDefinition(definition)
        local command = T.context.definitionResolver.commandFromResolved(definition, "install", resolved)

        T.assertEqual(command.source.kind, "zip")
        T.assertEqual(command.source.folder, "Source/A.spoon")
        T.assertEqual(command.target.name, "A")
    end)

    T.test("definition resolver builds remote zip url from base and zip file", function()
        local config =
            T.SpoonManager.from.remoteZip("https://example.com/")
                .zipFile("WindowGrid.spoon.zip")
                .toConfig()
        local definition = {
            config = config,
        }

        local resolved = T.context.definitionResolver.resolveFromDefinition(definition)
        local command = T.context.definitionResolver.commandFromResolved(definition, "install", resolved)

        T.assertEqual(command.source.kind, "zip")
        T.assertEqual(command.source.url, "https://example.com/WindowGrid.spoon.zip")
        T.assertEqual(command.target.name, "WindowGrid")
    end)

    T.test("definition resolver builds remote zip url with path prefix", function()
        local config =
            T.SpoonManager.from.remoteZip("https://example.com/")
                .path("subfolder")
                .zipFile("WindowGrid.spoon.zip")
                .toConfig()
        local definition = {
            config = config,
        }

        local resolved = T.context.definitionResolver.resolveFromDefinition(definition)
        local command = T.context.definitionResolver.commandFromResolved(definition, "install", resolved)

        T.assertEqual(command.source.url, "https://example.com/subfolder/WindowGrid.spoon.zip")
        T.assertEqual(command.target.name, "WindowGrid")
    end)

    T.test("definition resolver keeps a direct remote zip url", function()
        local config =
            T.SpoonManager.from.remoteZip("https://example.com/WindowGrid.spoon.zip")
                .toConfig()
        local definition = {
            config = config,
        }

        local resolved = T.context.definitionResolver.resolveFromDefinition(definition)
        local command = T.context.definitionResolver.commandFromResolved(definition, "install", resolved)

        T.assertEqual(command.source.url, "https://example.com/WindowGrid.spoon.zip")
        T.assertEqual(command.target.name, "WindowGrid")
    end)

    T.test("definition resolver builds local zip path from base and zip file", function()
        local config =
            T.SpoonManager.from.localZip("~/Downloads")
                .zipFile("WindowGrid.spoon.zip")
                .toConfig()
        local definition = {
            config = config,
        }

        local resolved = T.context.definitionResolver.resolveFromDefinition(definition)
        local command = T.context.definitionResolver.commandFromResolved(definition, "install", resolved)

        T.assertEqual(command.source.kind, "zip")
        T.assertEqual(command.source.path, "/Users/test/Downloads/WindowGrid.spoon.zip")
        T.assertEqual(command.target.name, "WindowGrid")
    end)

    T.test("definition resolver builds local zip path with path prefix", function()
        local config =
            T.SpoonManager.from.localZip("~/Downloads")
                .path("spoons")
                .zipFile("WindowGrid.spoon.zip")
                .toConfig()
        local definition = {
            config = config,
        }

        local resolved = T.context.definitionResolver.resolveFromDefinition(definition)
        local command = T.context.definitionResolver.commandFromResolved(definition, "install", resolved)

        T.assertEqual(command.source.path, "/Users/test/Downloads/spoons/WindowGrid.spoon.zip")
        T.assertEqual(command.target.name, "WindowGrid")
    end)

    T.test("definition resolver maps local folder selection", function()
        local config =
            T.SpoonManager.from.localFolder("~/Projects/SpoonRepo")
                .path("Source/A.spoon")
                .toConfig()
        local definition = {
            config = config,
        }

        local resolved = T.context.definitionResolver.resolveFromDefinition(definition)
        local command = T.context.definitionResolver.commandFromResolved(definition, "install", resolved)

        T.assertEqual(command.source.kind, "folder")
        T.assertEqual(command.source.path, "/Users/test/Projects/SpoonRepo/Source/A.spoon")
        T.assertEqual(command.target.name, "A")
    end)

end
