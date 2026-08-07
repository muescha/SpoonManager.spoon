return function(T)
    T.test("resolver maps github repository root", function()
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

    T.test("resolver maps github folder pattern", function()
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

    T.test("resolver maps local folder selection", function()
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
