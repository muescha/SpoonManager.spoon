return function(T)
    T.test("example: local folder spoon", function()
        local explanation =
            T.SpoonManager.from.localFolder("~/Projects/DeepFolder.spoon")
                .explain("install")

        T.assertEqual(explanation.definition.source.type, "local-folder")
        T.assertEqual(explanation.definition.source.path, "/Users/test/Projects/DeepFolder.spoon")
        T.assertEqual(explanation.command.from.type, "local-folder")
        T.assertEqual(explanation.command.from.path, "/Users/test/Projects/DeepFolder.spoon")
        T.assertEqual(explanation.command.to.name, "DeepFolder")
        T.assertMatchesJson("examples/local_sources.lua.folder.explain.json", explanation)
    end)

    T.test("example: local folder repository selection", function()
        local explanation =
            T.SpoonManager.from.localFolder("~/Projects/SpoonRepo")
                .folder("Source/DeepFolder.spoon")
                .explain("install")

        T.assertEqual(explanation.definition.target.selection_folder, "Source/DeepFolder.spoon")
        T.assertEqual(explanation.command.from.type, "local-folder")
        T.assertEqual(explanation.command.from.path, "/Users/test/Projects/SpoonRepo/Source/DeepFolder.spoon")
        T.assertEqual(explanation.command.to.name, "DeepFolder")
        T.assertMatchesJson("examples/local_sources.lua.folder-selection.explain.json", explanation)
    end)

    T.test("example: local zip", function()
        local explanation =
            T.SpoonManager.from.localZip("~/Downloads/DeepFolder.spoon.zip")
                .explain("install")

        T.assertEqual(explanation.definition.source.type, "local-zip")
        T.assertEqual(explanation.command.from.type, "local-zip")
        T.assertEqual(explanation.command.from.path, "/Users/test/Downloads/DeepFolder.spoon.zip")
        T.assertEqual(explanation.command.to.name, "DeepFolder")
        T.assertMatchesJson("examples/local_sources.lua.zip.explain.json", explanation)
    end)
end
