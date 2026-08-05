return function(T)
    T.test("example: github spoon zip pattern", function()
        local explanation =
            T.SpoonManager.from.github("muescha/SpoonRepo")
                .branch("main")
                .spoonZipPattern("dist/{name}.spoon.zip")
                .spoon("DeepFolder")
                .explain("install")

        T.assertEqual(explanation.definition.source.pattern_spoonZipPattern, "dist/{name}.spoon.zip")
        T.assertEqual(explanation.definition.target.selection_spoon, "DeepFolder")
        T.assertEqual(explanation.command.from.type, "remote-zip")
        T.assertEqual(explanation.command.from.url, "https://github.com/muescha/SpoonRepo/raw/main/dist/DeepFolder.spoon.zip")
        T.assertEqual(explanation.command.to.name, "DeepFolder")
        T.assertMatchesJson("examples/github_patterns.lua.zip-pattern.explain.json", explanation)
    end)

    T.test("example: github spoon folder pattern", function()
        local explanation =
            T.SpoonManager.from.github("muescha/SpoonRepo")
                .branch("main")
                .spoonFolderPattern("Source/{name}.spoon")
                .spoon("DeepFolder")
                .explain("install")

        T.assertEqual(explanation.definition.source.pattern_spoonFolderPattern, "Source/{name}.spoon")
        T.assertEqual(explanation.definition.target.selection_spoon, "DeepFolder")
        T.assertEqual(explanation.command.from.type, "github-folder")
        T.assertEqual(explanation.command.from.folder, "Source/DeepFolder.spoon")
        T.assertEqual(explanation.command.to.name, "DeepFolder")
        T.assertMatchesJson("examples/github_patterns.lua.folder-pattern.explain.json", explanation)
    end)

    T.test("example: spoon repo sugar", function()
        local explanation =
            T.SpoonManager.from.spoonRepo("muescha/SpoonRepo", {
                branch = "main",
            })
                .spoon("DeepFolder")
                .explain("install")

        T.assertEqual(explanation.definition.source.pattern_spoonFolderPattern, "Source/{name}.spoon")
        T.assertEqual(explanation.definition.target.selection_spoon, "DeepFolder")
        T.assertEqual(explanation.command.from.type, "github-folder")
        T.assertEqual(explanation.command.from.folder, "Source/DeepFolder.spoon")
        T.assertEqual(explanation.command.to.name, "DeepFolder")
        T.assertMatchesJson("examples/github_patterns.lua.spoon-repo.explain.json", explanation)
    end)

    T.test("example: spoon repo zip sugar", function()
        local explanation =
            T.SpoonManager.from.spoonRepoZip("muescha/SpoonRepo", {
                branch = "main",
            })
                .spoon("DeepFolder")
                .explain("install")

        T.assertEqual(explanation.definition.source.pattern_spoonZipPattern, "Spoons/{name}.spoon.zip")
        T.assertEqual(explanation.definition.target.selection_spoon, "DeepFolder")
        T.assertEqual(explanation.command.from.type, "remote-zip")
        T.assertEqual(explanation.command.from.url, "https://github.com/muescha/SpoonRepo/raw/main/Spoons/DeepFolder.spoon.zip")
        T.assertEqual(explanation.command.to.name, "DeepFolder")
        T.assertMatchesJson("examples/github_patterns.lua.spoon-repo-zip.explain.json", explanation)
    end)
end
