return function(T)
    T.test("example: default spoon", function()
        local explanation =
            T.SpoonManager.from.default
                .spoon("Emojis")
                .command("install").explain()

        T.assertEqual(explanation.source.type, "github")
        T.assertEqual(explanation.source.repository, "Hammerspoon/Spoons")
        T.assertEqual(explanation.source.defaultBranch, "master")
        T.assertEqual(explanation.source.pattern_spoonZipPattern, "Spoons/{name}.spoon.zip")
        T.assertEqual(explanation.target.selection_spoon, "Emojis")
        T.assertEqual(explanation.resolved.installName, "Emojis")
        T.assertEqual(explanation.command.from.type, "remote-zip")
        T.assertMatchesJson("examples/default_spoon.lua.explain.json", explanation)
    end)

    T.test("example: default spoon with branch override", function()
        local explanation =
            T.SpoonManager.from.default
                .branch("main")
                .spoon("Emojis")
                .command("install").explain()

        T.assertEqual(explanation.source.defaultBranch, "master")
        T.assertEqual(explanation.source.revision_branch, "main")
        T.assertEqual(explanation.command.from.url, "https://github.com/Hammerspoon/Spoons/raw/main/Spoons/Emojis.spoon.zip")
        T.assertMatchesJson("examples/default_spoon.lua.branch-override.explain.json", explanation)
    end)
end
