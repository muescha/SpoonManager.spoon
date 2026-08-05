return function(T)
    T.test("example: github latest release command", function()
        local definition =
            T.SpoonManager.from.github("muescha/DeepFolder.spoon")
                .releaseLatest()
                .asset("DeepFolder.zip")
                .toConfig()

        local command = T.context.resolver.toCommand(definition, "install")

        T.assertEqual(definition.source.release, "latest")
        T.assertEqual(definition.target.selection_asset, "DeepFolder.zip")
        T.assertEqual(command.from.type, "github-release")
        T.assertEqual(command.from.url, "https://github.com/muescha/DeepFolder.spoon/releases/latest/download/DeepFolder.zip")
        T.assertEqual(command.to.name, "DeepFolder")
        T.assertMatchesJson("examples/github_release.lua.latest.command.json", command)
    end)

    T.test("example: github tagged release command", function()
        local definition =
            T.SpoonManager.from.github("muescha/DeepFolder.spoon")
                .release("v1.2.3")
                .asset("DeepFolder.zip")
                .toConfig()

        local command = T.context.resolver.toCommand(definition, "install")

        T.assertEqual(definition.source.release, "v1.2.3")
        T.assertEqual(command.from.url, "https://github.com/muescha/DeepFolder.spoon/releases/download/v1.2.3/DeepFolder.zip")
        T.assertMatchesJson("examples/github_release.lua.tag.command.json", command)
    end)
end
