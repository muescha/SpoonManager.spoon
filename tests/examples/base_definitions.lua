return function(T)
    T.test("example: reuse default base definition for one spoon", function()
        local official = T.SpoonManager.from.default
        local explanation = T.explainCommand(
            official
            .spoon("Emojis"),
            "install")

        T.assertEqual(explanation.config.source.selection_spoon, "Emojis")
        T.assertEqual(explanation.config.source.defaultBranch, "master")
        T.assertEqual(explanation.command.source.location.url, "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/Emojis.spoon.zip")
        T.assertMatchesJson("examples/base_definitions.lua.default-emojis.explain.json", explanation)
    end)

    T.test("example: reuse default base definition for another spoon", function()
        local official = T.SpoonManager.from.default
        local explanation = T.explainCommand(
            official
            .spoon("TimeMachineProgress"),
            "install")

        T.assertEqual(explanation.config.source.selection_spoon, "TimeMachineProgress")
        T.assertEqual(explanation.config.source.defaultBranch, "master")
        T.assertEqual(explanation.command.source.location.url, "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/TimeMachineProgress.spoon.zip")
        T.assertMatchesJson("examples/base_definitions.lua.default-time-machine.explain.json", explanation)
    end)

    T.test("example: reuse github release base definition for latest", function()
        local releases = T.SpoonManager.from.github("muescha/DeepFolder.spoon")
        local explanation = T.explainCommand(
            releases
            .releaseLatest()
            .zipFile("DeepFolder.zip"),
            "install")

        T.assertEqual(explanation.config.source.selection_releaseLatest, true)
        T.assertEqual(explanation.command.source.location.url, "https://github.com/muescha/DeepFolder.spoon/releases/latest/download/DeepFolder.zip")
        T.assertMatchesJson("examples/base_definitions.lua.release-latest.explain.json", explanation)
    end)

    T.test("example: reuse github release base definition for tag", function()
        local releases = T.SpoonManager.from.github("muescha/DeepFolder.spoon")
        local explanation = T.explainCommand(
            releases
            .release("v1.2.3")
            .zipFile("DeepFolder.zip"),
            "install")

        T.assertEqual(explanation.config.source.selection_release, "v1.2.3")
        T.assertEqual(explanation.command.source.location.url, "https://github.com/muescha/DeepFolder.spoon/releases/download/v1.2.3/DeepFolder.zip")
        T.assertMatchesJson("examples/base_definitions.lua.release-tag.explain.json", explanation)
    end)
end
