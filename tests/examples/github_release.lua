return function(T)
    T.test("example: github latest release", function()
        local explanation =
            T.SpoonManager.from.github("muescha/DeepFolder.spoon")
                .releaseLatest()
                .zipFile("DeepFolder.zip")
                .command("install").explain()

        T.assertEqual(explanation.config.source.selection_releaseLatest, true)
        T.assertEqual(explanation.config.source.zipFile, "DeepFolder.zip")
        T.assertEqual(explanation.command.source.kind, "zip")
        T.assertEqual(explanation.command.source.url, "https://github.com/muescha/DeepFolder.spoon/releases/latest/download/DeepFolder.zip")
        T.assertEqual(explanation.command.target.name, "DeepFolder")
        T.assertMatchesJson("examples/github_release.lua.latest.explain.json", explanation)
    end)

    T.test("example: github latest release with explicit name", function()
        local explanation =
            T.SpoonManager.from.github("muescha/DeepFolder.spoon")
                .releaseLatest()
                .zipFile("latest.zip")
                .withName("DeepFolder")
                .command("install").explain()

        T.assertEqual(explanation.config.naming.withName, "DeepFolder")
        T.assertEqual(explanation.command.source.url, "https://github.com/muescha/DeepFolder.spoon/releases/latest/download/latest.zip")
        T.assertEqual(explanation.command.target.name, "DeepFolder")
        T.assertMatchesJson("examples/github_release.lua.latest-with-name.explain.json", explanation)
    end)

    T.test("example: github tagged release", function()
        local explanation =
            T.SpoonManager.from.github("muescha/DeepFolder.spoon")
                .release("v1.2.3")
                .zipFile("DeepFolder.zip")
                .command("install").explain()

        T.assertEqual(explanation.config.source.selection_release, "v1.2.3")
        T.assertEqual(explanation.command.source.url, "https://github.com/muescha/DeepFolder.spoon/releases/download/v1.2.3/DeepFolder.zip")
        T.assertMatchesJson("examples/github_release.lua.tag.explain.json", explanation)
    end)

    T.test("example: github tagged release with explicit name", function()
        local explanation =
            T.SpoonManager.from.github("muescha/DeepFolder.spoon")
                .release("v1.2.3")
                .zipFile("latest.zip")
                .withName("DeepFolder")
                .command("install").explain()

        T.assertEqual(explanation.config.source.selection_release, "v1.2.3")
        T.assertEqual(explanation.config.naming.withName, "DeepFolder")
        T.assertEqual(explanation.command.source.url, "https://github.com/muescha/DeepFolder.spoon/releases/download/v1.2.3/latest.zip")
        T.assertEqual(explanation.command.target.name, "DeepFolder")
        T.assertMatchesJson("examples/github_release.lua.tag-with-name.explain.json", explanation)
    end)
end
