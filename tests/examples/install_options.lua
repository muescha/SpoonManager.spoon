return function(T)
    T.test("example: onLocalChanges override", function()
        local explanation =
            T.SpoonManager.from.github("owner/repo")
                .path("Source/A.spoon")
                .onLocalChanges(T.SpoonManager.options.localChanges.backup)
                .command("install").explain()

        T.assertEqual(explanation.config.options.onLocalChanges, T.SpoonManager.options.localChanges.backup)
        T.assertEqual(explanation.command.options.onLocalChanges, T.SpoonManager.options.localChanges.backup)
        T.assertMatchesJson("examples/install_options.lua.on-local-changes.explain.json", explanation)
    end)
end
