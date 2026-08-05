return function(T)
    T.test("example: remote zip", function()
        local explanation =
            T.SpoonManager.from.remoteZip("https://example.com/downloads/DeepFolder.spoon.zip")
                .explain("install")

        T.assertEqual(explanation.definition.source.type, "remote-zip")
        T.assertEqual(explanation.command.from.type, "remote-zip")
        T.assertEqual(explanation.command.from.url, "https://example.com/downloads/DeepFolder.spoon.zip")
        T.assertEqual(explanation.command.to.name, "DeepFolder")
        T.assertMatchesJson("examples/zip_sources.lua.remote.explain.json", explanation)
    end)

    T.test("example: remote zip with explicit name", function()
        local explanation =
            T.SpoonManager.from.remoteZip("https://example.com/downloads/latest.zip")
                .withName("DeepFolder")
                .explain("install")

        T.assertEqual(explanation.definition.target.name_withName, "DeepFolder")
        T.assertEqual(explanation.command.from.url, "https://example.com/downloads/latest.zip")
        T.assertEqual(explanation.command.to.name, "DeepFolder")
        T.assertMatchesJson("examples/zip_sources.lua.remote-with-name.explain.json", explanation)
    end)
end
