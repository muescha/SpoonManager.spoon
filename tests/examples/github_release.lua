return function(T)
    T.test("example: github latest release", function()
        local explanation =
            T.SpoonManager.from.github("muescha/DeepFolder.spoon")
                .releaseLatest()
                .asset("DeepFolder.zip")
                .explain("install")

        T.assertEqual(explanation.definition.source.release, "latest")
        T.assertEqual(explanation.definition.target.selection_asset, "DeepFolder.zip")
        T.assertEqual(explanation.command.from.type, "github-release")
        T.assertEqual(explanation.command.from.url, "https://github.com/muescha/DeepFolder.spoon/releases/latest/download/DeepFolder.zip")
        T.assertEqual(explanation.command.to.name, "DeepFolder")
        T.assertMatchesJson("examples/github_release.lua.latest.explain.json", explanation)
    end)

    T.test("example: github tagged release", function()
        local explanation =
            T.SpoonManager.from.github("muescha/DeepFolder.spoon")
                .release("v1.2.3")
                .asset("DeepFolder.zip")
                .explain("install")

        T.assertEqual(explanation.definition.source.release, "v1.2.3")
        T.assertEqual(explanation.command.from.url, "https://github.com/muescha/DeepFolder.spoon/releases/download/v1.2.3/DeepFolder.zip")
        T.assertMatchesJson("examples/github_release.lua.tag.explain.json", explanation)
    end)
end
