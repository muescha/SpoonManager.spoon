return function(T)
    local function withPatched(patches, fn)
        local originals = {}

        for _, patch in ipairs(patches) do
            originals[patch] = patch.table[patch.key]
            patch.table[patch.key] = patch.value
        end

        local ok, err = pcall(fn)

        for index = #patches, 1, -1 do
            local patch = patches[index]
            patch.table[patch.key] = originals[patch]
        end

        if not ok then
            error(err, 2)
        end
    end

    local function withRecordedInstaller(fn)
        local manager = T.SpoonManager
        local originalInstallDefinition = manager._installDefinition
        local calls = {}

        manager.clear()
        manager._installDefinition = function(definitionConfig, action)
            local config = definitionConfig.config or definitionConfig
            local target = config.target or {}
            table.insert(calls, {
                config = config,
                action = action,
            })

            return {
                success = true,
                action = action,
                name = (
                    target.selection_spoon
                    or target.name_withName
                    or target.selection_folder
                    or target.selection_asset
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
            T.assertEqual(calls[2].config.target.selection_spoon, "TimeMachineProgress")

            local updateResult = manager.update()
            T.assertTrue(updateResult.success)
            T.assertEqual(#calls, 4)
            T.assertEqual(calls[3].action, "update")
            T.assertEqual(calls[4].config.target.selection_spoon, "TimeMachineProgress")
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
            T.assertEqual(calls[1].config.target.selection_spoon, "Emojis")
        end)
    end)

    T.test("manager install with explicit definitions stores them", function()
        withRecordedInstaller(function(manager, calls)
            local emojis = manager.from.default.spoon("Emojis")
            local timeMachine = manager.from.default.spoon("TimeMachineProgress")

            manager.install(emojis, timeMachine)

            T.assertEqual(#calls, 2)
            T.assertEqual(#manager.definitions, 2)
            T.assertEqual(manager.definitions[1].target.selection_spoon, "Emojis")
            T.assertEqual(manager.definitions[2].target.selection_spoon, "TimeMachineProgress")

            manager.update()
            T.assertEqual(#calls, 4)
            T.assertEqual(calls[3].action, "update")
            T.assertEqual(calls[4].config.target.selection_spoon, "TimeMachineProgress")
        end)
    end)

    T.test("definition install stores itself in manager", function()
        withRecordedInstaller(function(manager, calls)
            manager.from.default
                .spoon("Emojis")
                .install()

            T.assertEqual(#calls, 1)
            T.assertEqual(#manager.definitions, 1)
            T.assertEqual(manager.definitions[1].target.selection_spoon, "Emojis")

            manager.update()
            T.assertEqual(#calls, 2)
            T.assertEqual(calls[2].action, "update")
            T.assertEqual(calls[2].config.target.selection_spoon, "Emojis")
        end)
    end)

    T.test("manager stores one definition per spoon name", function()
        withRecordedInstaller(function(manager)
            manager.install(
                manager.from.default
                    .spoon("Emojis")
                    .use({
                        start = true,
                    })
            )

            manager.install(
                manager.from.default
                    .spoon("Emojis")
                    .use({
                        start = false,
                    })
            )

            T.assertEqual(#manager.definitions, 1)
            T.assertEqual(manager.definitions[1].target.selection_spoon, "Emojis")
            T.assertEqual(manager.definitions[1].use.start, false)
        end)
    end)

    T.test("installer skips already installed spoon", function()
        local used = {}

        withPatched({
            {
                table = hs.fs,
                key = "attributes",
                value = function(path)
                    if path == "/tmp/hammerspoon-test/Spoons/Emojis.spoon" then
                        return {
                            mode = "directory",
                        }
                    end
                    return nil
                end,
            },
            {
                table = hs.spoons,
                key = "use",
                value = function(name, options)
                    table.insert(used, {
                        name = name,
                        options = options,
                    })
                    return true
                end,
            },
        }, function()
            local result, err =
                T.SpoonManager.from.default
                    .spoon("Emojis")
                    .use({
                        start = true,
                    })
                    .install()

            T.assertTrue(result, err)
            T.assertTrue(result.skipped)
            T.assertEqual(result.reason, "already-installed")
            T.assertEqual(#used, 1)
            T.assertEqual(used[1].name, "Emojis")
            T.assertEqual(used[1].options.start, true)
        end)
    end)

    T.test("update aborts on unmanaged local changes by default", function()
        local destination = "/tmp/hammerspoon-test/Spoons/Emojis.spoon"

        withPatched({
            {
                table = T.context.util,
                key = "fileExists",
                value = function(path)
                    return path == destination
                end,
            },
            {
                table = T.context.registry,
                key = "read",
                value = function()
                    return {}
                end,
            },
        }, function()
            local ok, err = T.context.installer.checkLocalChanges({
                name = "Emojis",
                options = {
                    onLocalChanges = T.SpoonManager.options.localChanges.abort,
                },
            }, destination)

            T.assertFalse(ok)
            T.assertEqual(err, "Spoon already exists but is not managed by SpoonManager. Use .onLocalChanges(\"backup\") or .onLocalChanges(\"overwrite\") to install anyway.")
        end)
    end)

    T.test("update allows unchanged managed spoon", function()
        local destination = "/tmp/hammerspoon-test/Spoons/Emojis.spoon"

        withPatched({
            {
                table = T.context.util,
                key = "fileExists",
                value = function(path)
                    return path == destination
                end,
            },
            {
                table = T.context.registry,
                key = "read",
                value = function()
                    return {
                        Emojis = {
                            checksum = "same",
                        },
                    }
                end,
            },
            {
                table = T.context.installer,
                key = "checksumDirectory",
                value = function()
                    return "same"
                end,
            },
        }, function()
            local ok, err = T.context.installer.checkLocalChanges({
                name = "Emojis",
                options = {
                    onLocalChanges = T.SpoonManager.options.localChanges.abort,
                },
            }, destination)

            T.assertTrue(ok, err)
        end)
    end)
end
