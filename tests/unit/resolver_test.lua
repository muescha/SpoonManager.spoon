return function(T)
    T.test("resolver maps github repository root", function()
        local config =
            T.SpoonManager.from.github("muescha/MySpoon.spoon")
                .toConfig()
        local definition = {
            config = config,
        }

        local resolved = T.context.resolver.resolveFromDefinition(definition)
        local command = T.context.resolver.commandFromResolved(definition, "install", resolved)

        T.assertEqual(command.from.type, "zip")
        T.assertEqual(command.from.url, "https://github.com/muescha/MySpoon.spoon/archive/main.zip")
        T.assertEqual(command.to.name, "MySpoon")
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

        local resolved = T.context.resolver.resolveFromDefinition(definition)
        local command = T.context.resolver.commandFromResolved(definition, "update", resolved)

        T.assertEqual(command.action, "update")
        T.assertEqual(command.from.type, "zip")
        T.assertEqual(command.from.folder, "Source/A.spoon")
        T.assertEqual(command.to.name, "A")
    end)

    T.test("resolver maps local folder selection", function()
        local config =
            T.SpoonManager.from.localFolder("~/Projects/SpoonRepo")
                .path("Source/A.spoon")
                .toConfig()
        local definition = {
            config = config,
        }

        local resolved = T.context.resolver.resolveFromDefinition(definition)
        local command = T.context.resolver.commandFromResolved(definition, "install", resolved)

        T.assertEqual(command.from.type, "folder")
        T.assertEqual(command.from.path, "/Users/test/Projects/SpoonRepo/Source/A.spoon")
        T.assertEqual(command.to.name, "A")
    end)

    T.test("archive selection accepts command folder field", function()
        local selection = T.context.archive.prepareZipSelection({
            command = {
                from = {
                    type = "zip",
                    folder = "Source/A.spoon",
                },
            },
        })

        T.assertEqual(selection.path, "Source/A.spoon")
    end)
end
