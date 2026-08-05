return function(T)
    T.test("example: github folder config", function()
        local definition =
            T.SpoonManager.from.github("muescha/SpoonRepo")
                .branch("main")
                .folder("Source/deepfolder")
                .withName("DeepFolder")
                .toConfig()

        T.assertEqual(definition.source.type, "github")
        T.assertEqual(definition.source.repository, "muescha/SpoonRepo")
        T.assertEqual(definition.source.revision_branch, "main")
        T.assertEqual(definition.target.selection_folder, "Source/deepfolder")
        T.assertEqual(definition.target.name_withName, "DeepFolder")
        T.assertMatchesJson("examples/github_folder.config.json", definition)
    end)

    T.test("example: github folder command", function()
        local definition =
            T.SpoonManager.from.github("muescha/SpoonRepo")
                .branch("main")
                .folder("Source/deepfolder")
                .withName("DeepFolder")
                .toConfig()

        local command = T.context.resolver.toCommand(definition, "install")

        T.assertEqual(command.from.type, "github-folder")
        T.assertEqual(command.from.archiveUrl, "https://github.com/muescha/SpoonRepo/archive/main.zip")
        T.assertEqual(command.from.folder, "Source/deepfolder")
        T.assertEqual(command.to.name, "DeepFolder")
        T.assertMatchesJson("examples/github_folder.command.json", command)
    end)
end
