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
                },
                target = {
                    selection_folder = "Source/DeepFolder.spoon",
                },
            }).command("install").explain()

        T.assertEqual(explanation.command.from.type, "github-folder")
        T.assertEqual(explanation.command.from.folder, "Source/DeepFolder.spoon")
        T.assertEqual(explanation.command.to.name, "DeepFolder")
        T.assertMatchesJson("examples/config_sources.lua.github-folder.explain.json", explanation)
    end)

    T.test("example: config source with explicit name", function()
        local explanation =
            T.SpoonManager.from.config({
                source = {
                    type = "remote-zip",
                    url = "https://example.com/downloads/latest.zip",
                },
                target = {
                    name_withName = "DeepFolder",
                },
            }).command("install").explain()

        T.assertEqual(explanation.command.from.type, "remote-zip")
        T.assertEqual(explanation.command.to.name, "DeepFolder")
        T.assertMatchesJson("examples/config_sources.lua.remote-zip-with-name.explain.json", explanation)
    end)
end
