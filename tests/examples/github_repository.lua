return function(T)
    T.test("example: github repository root", function()
        local explanation =
            T.SpoonManager.from.github("muescha/DeepFolder.spoon")
                .command("install").explain()

        T.assertEqual(explanation.config.source.repository, "muescha/DeepFolder.spoon")
        T.assertEqual(explanation.command.from.type, "zip")
        T.assertEqual(explanation.command.from.url, "https://github.com/muescha/DeepFolder.spoon/archive/main.zip")
        T.assertEqual(explanation.command.to.name, "DeepFolder")
        T.assertMatchesJson("examples/github_repository.lua.root.explain.json", explanation)
    end)

    T.test("example: github repository root with ref", function()
        local explanation =
            T.SpoonManager.from.github("muescha/DeepFolder.spoon")
                .ref("v1.2.3")
                .command("update").explain()

        T.assertEqual(explanation.config.source.revision_ref, "v1.2.3")
        T.assertEqual(explanation.command.action, "update")
        T.assertEqual(explanation.command.from.url, "https://github.com/muescha/DeepFolder.spoon/archive/v1.2.3.zip")
        T.assertMatchesJson("examples/github_repository.lua.ref.explain.json", explanation)
    end)
end
