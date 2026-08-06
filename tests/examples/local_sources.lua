return function(T)
    T.test("example: local folder spoon", function()
        local explanation =
            T.SpoonManager.from.localFolder("~/Projects/DeepFolder.spoon")
                .command("install").explain()

        T.assertEqual(explanation.config.source.type, "localFolder")
        T.assertEqual(explanation.config.source.root, "~/Projects/DeepFolder.spoon")
        T.assertEqual(explanation.command.source.kind, "folder")
        T.assertEqual(explanation.command.source.path, "/Users/test/Projects/DeepFolder.spoon")
        T.assertEqual(explanation.command.target.name, "DeepFolder")
        T.assertMatchesJson("examples/local_sources.lua.folder.explain.json", explanation)
    end)

    T.test("example: local folder repository selection", function()
        local explanation =
            T.SpoonManager.from.localFolder("~/Projects/SpoonRepo")
                .path("Source/DeepFolder.spoon")
                .command("install").explain()

        T.assertEqual(explanation.config.source.path, "Source/DeepFolder.spoon")
        T.assertEqual(explanation.command.source.kind, "folder")
        T.assertEqual(explanation.command.source.path, "/Users/test/Projects/SpoonRepo/Source/DeepFolder.spoon")
        T.assertEqual(explanation.command.target.name, "DeepFolder")
        T.assertMatchesJson("examples/local_sources.lua.folder-selection.explain.json", explanation)
    end)

    T.test("example: local folder with explicit name", function()
        local explanation =
            T.SpoonManager.from.localFolder("~/Projects/experimental")
                .to("DeepFolder")
                .command("install").explain()

        T.assertEqual(explanation.config.target.name, "DeepFolder")
        T.assertEqual(explanation.command.source.path, "/Users/test/Projects/experimental")
        T.assertEqual(explanation.command.target.name, "DeepFolder")
        T.assertMatchesJson("examples/local_sources.lua.folder-with-name.explain.json", explanation)
    end)

    T.test("example: local zip", function()
        local explanation =
            T.SpoonManager.from.localZip("~/Downloads/DeepFolder.spoon.zip")
                .command("install").explain()

        T.assertEqual(explanation.config.source.type, "localZip")
        T.assertEqual(explanation.config.source.file, "~/Downloads/DeepFolder.spoon.zip")
        T.assertEqual(explanation.command.source.kind, "zip")
        T.assertEqual(explanation.command.source.path, "/Users/test/Downloads/DeepFolder.spoon.zip")
        T.assertEqual(explanation.command.target.name, "DeepFolder")
        T.assertMatchesJson("examples/local_sources.lua.zip.explain.json", explanation)
    end)

    T.test("example: local zip with explicit name", function()
        local explanation =
            T.SpoonManager.from.localZip("~/Downloads/latest.zip")
                .to("DeepFolder")
                .command("install").explain()

        T.assertEqual(explanation.config.target.name, "DeepFolder")
        T.assertEqual(explanation.command.source.path, "/Users/test/Downloads/latest.zip")
        T.assertEqual(explanation.command.target.name, "DeepFolder")
        T.assertMatchesJson("examples/local_sources.lua.zip-with-name.explain.json", explanation)
    end)
end
