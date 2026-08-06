return function(T)
    T.test("example: github folder", function()
        local explanation =
            T.SpoonManager.from.github("muescha/SpoonRepo")
                .branch("main")
                .folder("Source/deepfolder")
                .withName("DeepFolder")
                .command("install").explain()

        T.assertEqual(explanation.source.type, "github")
        T.assertEqual(explanation.source.repository, "muescha/SpoonRepo")
        T.assertEqual(explanation.source.revision_branch, "main")
        T.assertEqual(explanation.target.selection_folder, "Source/deepfolder")
        T.assertEqual(explanation.target.name_withName, "DeepFolder")
        T.assertEqual(explanation.command.from.type, "github-folder")
        T.assertEqual(explanation.command.from.archiveUrl, "https://github.com/muescha/SpoonRepo/archive/main.zip")
        T.assertEqual(explanation.command.to.name, "DeepFolder")
        T.assertMatchesJson("examples/github_folder.lua.explain.json", explanation)
    end)

    T.test("example: github folder with inferred name", function()
        local explanation =
            T.SpoonManager.from.github("muescha/SpoonRepo")
                .branch("main")
                .folder("Source/DeepFolder.spoon")
                .command("install").explain()

        T.assertEqual(explanation.target.selection_folder, "Source/DeepFolder.spoon")
        T.assertEqual(explanation.command.to.name, "DeepFolder")
        T.assertMatchesJson("examples/github_folder.lua.inferred-name.explain.json", explanation)
    end)

    T.test("example: github folder with ref", function()
        local explanation =
            T.SpoonManager.from.github("muescha/SpoonRepo")
                .ref("v1.2.3")
                .folder("Source/DeepFolder.spoon")
                .command("update").explain()

        T.assertEqual(explanation.source.revision_ref, "v1.2.3")
        T.assertEqual(explanation.command.action, "update")
        T.assertEqual(explanation.command.from.archiveUrl, "https://github.com/muescha/SpoonRepo/archive/v1.2.3.zip")
        T.assertMatchesJson("examples/github_folder.lua.ref.explain.json", explanation)
    end)
end
