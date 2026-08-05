return function(T)
    T.test("example: default spoon", function()
        local explanation =
            T.SpoonManager.from.default
                .spoon("Emojis")
                .explain("install")

        T.assertEqual(explanation.definition.source.type, "github")
        T.assertEqual(explanation.definition.source.repository, "Hammerspoon/Spoons")
        T.assertEqual(explanation.definition.source.revision_branch, "master")
        T.assertEqual(explanation.definition.source.pattern_spoonZipPattern, "Spoons/{name}.spoon.zip")
        T.assertEqual(explanation.definition.target.selection_spoon, "Emojis")
        T.assertEqual(explanation.resolved.installName, "Emojis")
        T.assertEqual(explanation.command.from.type, "remote-zip")
        T.assertMatchesJson("examples/default_spoon.lua.explain.json", explanation)
    end)
end
