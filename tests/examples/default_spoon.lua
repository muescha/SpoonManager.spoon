return function(T)
    T.test("example: default spoon", function()
        local explanation =
            T.SpoonManager.from.default
                .spoon("Emojis")
                .command("install").explain()

        T.assertEqual(explanation.config.source.type, "github")
        T.assertEqual(explanation.config.source.repository, "Hammerspoon/Spoons")
        T.assertEqual(explanation.config.source.defaultBranch, "master")
        T.assertEqual(explanation.config.source.pattern_spoonZipPattern, "Spoons/{name}.spoon.zip")
        T.assertEqual(explanation.config.source.selection_spoon, "Emojis")
        T.assertEqual(explanation.resolved.installName, "Emojis")
        T.assertEqual(explanation.command.source.kind, "zip")
        T.assertMatchesJson("examples/default_spoon.lua.explain.json", explanation)
    end)

    T.test("example: default spoon with branch override", function()
        local explanation =
            T.SpoonManager.from.default
                .branch("main")
                .spoon("Emojis")
                .command("install").explain()

        T.assertEqual(explanation.config.source.defaultBranch, "master")
        T.assertEqual(explanation.config.source.revision_branch, "main")
        T.assertEqual(explanation.command.source.url, "https://github.com/Hammerspoon/Spoons/raw/main/Spoons/Emojis.spoon.zip")
        T.assertMatchesJson("examples/default_spoon.lua.branch-override.explain.json", explanation)
    end)
end
