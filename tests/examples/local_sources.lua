return function(T)
    T.test("example: local folder spoon", function()
        local explanation =
            T.explainCommand(
                T.SpoonManager.from.localFolder("~/Projects/DeepFolder.spoon"),
            "install")

        T.assertEqual(explanation.config.source.type, "localFolder")
        T.assertEqual(explanation.config.source.root, "~/Projects/DeepFolder.spoon")
        T.assertEqual(explanation.command.source.kind, "folder")
        T.assertEqual(explanation.command.source.location.kind, "path")
        T.assertEqual(explanation.command.source.location.path, "/Users/test/Projects/DeepFolder.spoon")
        T.assertEqual(explanation.command.target.name, "DeepFolder")
        T.assertMatchesJson("examples/local_sources.lua.folder.explain.json", explanation)
    end)

    T.test("example: local folder repository selection", function()
        local explanation =
            T.explainCommand(
                T.SpoonManager.from.localFolder("~/Projects/SpoonRepo")
                .path("Source/DeepFolder.spoon"),
            "install")

        T.assertEqual(explanation.config.source.selection_path, "Source/DeepFolder.spoon")
        T.assertEqual(explanation.command.source.kind, "folder")
        T.assertEqual(explanation.command.source.location.kind, "path")
        T.assertEqual(explanation.command.source.location.path, "/Users/test/Projects/SpoonRepo/Source/DeepFolder.spoon")
        T.assertEqual(explanation.command.target.name, "DeepFolder")
        T.assertMatchesJson("examples/local_sources.lua.folder-selection.explain.json", explanation)
    end)

    T.test("example: local folder with explicit name", function()
        local explanation =
            T.explainCommand(
                T.SpoonManager.from.localFolder("~/Projects/experimental")
                .withName("DeepFolder"),
            "install")

        T.assertEqual(explanation.config.naming.withName, "DeepFolder")
        T.assertEqual(explanation.command.source.location.path, "/Users/test/Projects/experimental")
        T.assertEqual(explanation.command.target.name, "DeepFolder")
        T.assertMatchesJson("examples/local_sources.lua.folder-with-name.explain.json", explanation)
    end)

    T.test("example: local folder with excluded folders", function()
        local explanation =
            T.explainCommand(
                T.SpoonManager.from.localFolder("~/Projects/EmmyLua.spoon")
                .excludeFolders("annotations"),
            "install")

        T.assertEqual(explanation.config.source.excludeFolders[1], "annotations")
        T.assertEqual(explanation.command.source.excludeFolders[1], "annotations")
        T.assertEqual(explanation.command.target.name, "EmmyLua")
        T.assertMatchesJson("examples/local_sources.lua.folder-exclude.explain.json", explanation)
    end)

    T.test("example: local zip", function()
        local explanation =
            T.explainCommand(
                T.SpoonManager.from.localZip("~/Downloads/DeepFolder.spoon.zip"),
            "install")

        T.assertEqual(explanation.config.source.type, "localZip")
        T.assertEqual(explanation.config.source.file, "~/Downloads/DeepFolder.spoon.zip")
        T.assertEqual(explanation.command.source.kind, "zip")
        T.assertEqual(explanation.command.source.location.kind, "path")
        T.assertEqual(explanation.command.source.location.path, "/Users/test/Downloads/DeepFolder.spoon.zip")
        T.assertEqual(explanation.command.target.name, "DeepFolder")
        T.assertMatchesJson("examples/local_sources.lua.zip.explain.json", explanation)
    end)

    T.test("example: local zip with explicit name", function()
        local explanation =
            T.explainCommand(
                T.SpoonManager.from.localZip("~/Downloads/latest.zip")
                .withName("DeepFolder"),
            "install")

        T.assertEqual(explanation.config.naming.withName, "DeepFolder")
        T.assertEqual(explanation.command.source.location.path, "/Users/test/Downloads/latest.zip")
        T.assertEqual(explanation.command.target.name, "DeepFolder")
        T.assertMatchesJson("examples/local_sources.lua.zip-with-name.explain.json", explanation)
    end)

    T.test("example: local zip folder selection", function()
        local explanation =
            T.explainCommand(
                T.SpoonManager.from.localZip("~/Downloads/DeepFolder.spoon.zip")
                .useFolder("bundles/DeepFolder.spoon"),
            "install")

        T.assertEqual(explanation.config.extract.useFolder, "bundles/DeepFolder.spoon")
        T.assertEqual(explanation.command.source.kind, "zip")
        T.assertEqual(explanation.command.source.location.path, "/Users/test/Downloads/DeepFolder.spoon.zip")
        T.assertEqual(explanation.command.source.selection.folder, "bundles/DeepFolder.spoon")
        T.assertEqual(explanation.command.target.name, "DeepFolder")
        T.assertMatchesJson("examples/local_sources.lua.zip-folder.explain.json", explanation)
    end)
end
