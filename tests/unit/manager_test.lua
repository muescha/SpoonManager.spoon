return function(T)
    local function withRecordedInstaller(fn)
        local manager = T.SpoonManager
        local originalInstallDefinition = manager._installDefinition
        local calls = {}

        manager.clear()
        manager._installDefinition = function(definition, action)
            table.insert(calls, {
                definition = definition,
                action = action,
            })

            return {
                success = true,
                action = action,
                name = definition.target and (
                    definition.target.selection_spoon
                    or definition.target.name_withName
                    or definition.target.selection_folder
                    or definition.target.selection_asset
                ) or "unknown",
            }
        end

        local ok, err = pcall(fn, manager, calls)
        manager._installDefinition = originalInstallDefinition
        manager.clear()

        if not ok then
            error(err, 2)
        end
    end

    T.test("manager add stores definitions for later install and update", function()
        withRecordedInstaller(function(manager, calls)
            local emojis = manager.from.default.spoon("Emojis")
            local timeMachine = manager.from.default.spoon("TimeMachineProgress")

            manager.add(emojis, timeMachine)
            T.assertEqual(#manager.definitions, 2)

            local installResult = manager.install()
            T.assertTrue(installResult.success)
            T.assertEqual(#calls, 2)
            T.assertEqual(calls[1].action, "install")
            T.assertEqual(calls[2].definition.target.selection_spoon, "TimeMachineProgress")

            local updateResult = manager.update()
            T.assertTrue(updateResult.success)
            T.assertEqual(#calls, 4)
            T.assertEqual(calls[3].action, "update")
            T.assertEqual(calls[4].definition.target.selection_spoon, "TimeMachineProgress")
        end)
    end)

    T.test("definition add stores itself for manager install", function()
        withRecordedInstaller(function(manager, calls)
            manager.from.default
                .spoon("Emojis")
                .add()

            T.assertEqual(#manager.definitions, 1)
            manager.install()

            T.assertEqual(#calls, 1)
            T.assertEqual(calls[1].definition.target.selection_spoon, "Emojis")
        end)
    end)

    T.test("manager install with explicit definitions does not store them", function()
        withRecordedInstaller(function(manager, calls)
            local emojis = manager.from.default.spoon("Emojis")
            local timeMachine = manager.from.default.spoon("TimeMachineProgress")

            manager.install(emojis, timeMachine)

            T.assertEqual(#calls, 2)
            T.assertEqual(#manager.definitions, 0)

            manager.update()
            T.assertEqual(#calls, 2)
        end)
    end)

    T.test("definition install does not store itself in manager", function()
        withRecordedInstaller(function(manager, calls)
            manager.from.default
                .spoon("Emojis")
                .install()

            T.assertEqual(#calls, 1)
            T.assertEqual(#manager.definitions, 0)

            manager.update()
            T.assertEqual(#calls, 1)
        end)
    end)
end
