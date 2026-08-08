return function(T)
    T.test("example: conflictStrategy override", function()
        local explanation =
            T.SpoonManager.from.github("owner/repo")
                .path("Source/A.spoon")
                .conflictStrategy(T.SpoonManager.options.conflictStrategy.backup)
                .command("install").explain()

        T.assertEqual(explanation.config.installOptions.conflictStrategy, T.SpoonManager.options.conflictStrategy.backup)
        T.assertEqual(explanation.command.options.conflictStrategy, T.SpoonManager.options.conflictStrategy.backup)
        T.assertMatchesJson("examples/install_options.lua.conflict-strategy.explain.json", explanation)
    end)
end
