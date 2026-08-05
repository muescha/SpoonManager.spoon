return function(T)
    T.test("example: default spoon config", function()
        local definition =
            T.SpoonManager.from.default
                .spoon("Emojis")
                .toConfig()

        T.assertEqual(definition.source.type, "github")
        T.assertEqual(definition.source.repository, "Hammerspoon/Spoons")
        T.assertEqual(definition.source.revision_branch, "master")
        T.assertEqual(definition.source.pattern_spoonZipPattern, "Spoons/{name}.spoon.zip")
        T.assertEqual(definition.target.selection_spoon, "Emojis")
        T.assertMatchesJson("examples/default_spoon.lua.config.json", definition)
    end)

    T.test("example: default spoon command", function()
        local definition =
            T.SpoonManager.from.default
                .spoon("Emojis")
                .toConfig()

        local command = T.context.resolver.toCommand(definition, "install")

        T.assertEqual(command.from.type, "remote-zip")
        T.assertEqual(command.from.url, "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/Emojis.spoon.zip")
        T.assertEqual(command.to.name, "Emojis")
        T.assertMatchesJson("examples/default_spoon.lua.command.json", command)
    end)

    T.test("example: default spoon explain", function()
        local explanation =
            T.SpoonManager.from.default
                .spoon("Emojis")
                .explain("install")

        T.assertEqual(explanation.definition.target.selection_spoon, "Emojis")
        T.assertEqual(explanation.resolved.installName, "Emojis")
        T.assertEqual(explanation.command.from.type, "remote-zip")
        T.assertMatchesJson("examples/default_spoon.lua.explain.json", explanation)
    end)
end
