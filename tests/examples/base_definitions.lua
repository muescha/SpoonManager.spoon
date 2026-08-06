return function(T)
    T.test("example: reuse default base definition for one spoon", function()
        local official = T.SpoonManager.from.default
        local explanation = official
            .spoon("Emojis")
            .command("install").explain()

        T.assertEqual(explanation.target.selection_spoon, "Emojis")
        T.assertEqual(explanation.source.defaultBranch, "master")
        T.assertEqual(explanation.command.from.url, "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/Emojis.spoon.zip")
        T.assertMatchesJson("examples/base_definitions.lua.default-emojis.explain.json", explanation)
    end)

    T.test("example: reuse default base definition for another spoon", function()
        local official = T.SpoonManager.from.default
        local explanation = official
            .spoon("TimeMachineProgress")
            .command("install").explain()

        T.assertEqual(explanation.target.selection_spoon, "TimeMachineProgress")
        T.assertEqual(explanation.source.defaultBranch, "master")
        T.assertEqual(explanation.command.from.url, "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/TimeMachineProgress.spoon.zip")
        T.assertMatchesJson("examples/base_definitions.lua.default-time-machine.explain.json", explanation)
    end)

    T.test("example: reuse github release base definition for latest", function()
        local releases = T.SpoonManager.from.github("muescha/DeepFolder.spoon")
        local explanation = releases
            .releaseLatest()
            .asset("DeepFolder.zip")
            .command("install").explain()

        T.assertEqual(explanation.source.release, "latest")
        T.assertEqual(explanation.command.from.url, "https://github.com/muescha/DeepFolder.spoon/releases/latest/download/DeepFolder.zip")
        T.assertMatchesJson("examples/base_definitions.lua.release-latest.explain.json", explanation)
    end)

    T.test("example: reuse github release base definition for tag", function()
        local releases = T.SpoonManager.from.github("muescha/DeepFolder.spoon")
        local explanation = releases
            .release("v1.2.3")
            .asset("DeepFolder.zip")
            .command("install").explain()

        T.assertEqual(explanation.source.release, "v1.2.3")
        T.assertEqual(explanation.command.from.url, "https://github.com/muescha/DeepFolder.spoon/releases/download/v1.2.3/DeepFolder.zip")
        T.assertMatchesJson("examples/base_definitions.lua.release-tag.explain.json", explanation)
    end)
end
