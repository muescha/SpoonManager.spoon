return function(T)
    T.test("example: config source for github folder", function()
        local explanation =
            T.SpoonManager.from.config({
                source = {
                    type = "github",
                    provider = "github",
                    repository = "muescha/SpoonRepo",
                    baseUrl = "https://github.com",
                    revision_branch = "main",
                    path_path = "Source/DeepFolder.spoon",
                },
            }).command("install").explain()

        T.assertEqual(explanation.command.source.kind, "zip")
        T.assertEqual(explanation.command.source.folder, "Source/DeepFolder.spoon")
        T.assertEqual(explanation.command.target.name, "DeepFolder")
        T.assertMatchesJson("examples/config_sources.lua.github-folder.explain.json", explanation)
    end)

    T.test("example: config source with explicit name", function()
        local explanation =
            T.SpoonManager.from.config({
                source = {
                    type = "remoteZip",
                    url = "https://example.com/downloads/latest.zip",
                },
                target = {
                    name_withName = "DeepFolder",
                },
            }).command("install").explain()

        T.assertEqual(explanation.command.source.kind, "zip")
        T.assertEqual(explanation.command.target.name, "DeepFolder")
        T.assertMatchesJson("examples/config_sources.lua.remoteZip-with-name.explain.json", explanation)
    end)
end
