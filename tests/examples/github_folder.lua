return function(T)
    T.test("example: github folder", function()
        local explanation =
            T.SpoonManager.from.github("muescha/SpoonRepo")
                .branch("main")
                .path("Source/DeepFolder.spoon")
                .command("install").explain()

        T.assertEqual(explanation.config.source.type, "github")
        T.assertEqual(explanation.config.source.repository, "muescha/SpoonRepo")
        T.assertEqual(explanation.config.source.revision_branch, "main")
        T.assertEqual(explanation.config.source.path_path, "Source/DeepFolder.spoon")
        T.assertEqual(explanation.command.source.kind, "zip")
        T.assertEqual(explanation.command.source.url, "https://github.com/muescha/SpoonRepo/archive/main.zip")
        T.assertEqual(explanation.command.target.name, "DeepFolder")
        T.assertMatchesJson("examples/github_folder.lua.explain.json", explanation)
    end)

    T.test("example: github folder with inferred name", function()
        local explanation =
            T.SpoonManager.from.github("muescha/SpoonRepo")
                .branch("main")
                .path("Source/DeepFolder.spoon")
                .command("install").explain()

        T.assertEqual(explanation.config.source.path_path, "Source/DeepFolder.spoon")
        T.assertEqual(explanation.command.target.name, "DeepFolder")
        T.assertMatchesJson("examples/github_folder.lua.inferred-name.explain.json", explanation)
    end)

    T.test("example: github folder with ref", function()
        local explanation =
            T.SpoonManager.from.github("muescha/SpoonRepo")
                .ref("v1.2.3")
                .path("Source/DeepFolder.spoon")
                .command("update").explain()

        T.assertEqual(explanation.config.source.revision_ref, "v1.2.3")
        T.assertEqual(explanation.command.action, "update")
        T.assertEqual(explanation.command.source.url, "https://github.com/muescha/SpoonRepo/archive/v1.2.3.zip")
        T.assertMatchesJson("examples/github_folder.lua.ref.explain.json", explanation)
    end)
end
