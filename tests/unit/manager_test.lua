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

    local function preparedTask(name, options, use)
        return {
            task = {
                name = name,
                options = options or {
                    conflictStrategy = T.SpoonManager.options.conflictStrategy.abort,
                },
                use = use,
            },
        }
    end

    local function withRecordedInstaller(fn)
        local manager = T.SpoonManager
        local originalInstallDefinition = manager._installDefinition
        local calls = {}

        manager._installDefinition = function(definitionConfig, action)
            local config = definitionConfig.config or definitionConfig
            local source = config.source or {}
            local extract = config.extract or {}
            local naming = config.naming or {}
            table.insert(calls, {
                config = config,
                action = action,
            })

            return {
                success = true,
                definition = {
                    result = {
                        action = action,
                        name = (
                            source.selection_spoon
                            or naming.withName
                            or extract.useFolder
                            or source.zipFile
                            or source.selection_path
                        ) or "unknown",
                    },
                },
            }
        end

        local ok, err = pcall(fn, manager, calls)
        manager._installDefinition = originalInstallDefinition

        if not ok then
            error(err, 2)
        end
    end

    T.test("manager registers source providers", function()
        local providers = T.SpoonManager.providers

        T.assertEqual(providers.github.name, "github")
        T.assertEqual(providers.remoteZip.name, "remoteZip")
        T.assertEqual(providers.localZip.name, "localZip")
        T.assertEqual(providers.localFolder.name, "localFolder")
        T.assertTrue(providers.github.capabilities.release)
        T.assertEqual(type(providers.github.builderPresets.spoonRepo), "function")
        T.assertEqual(type(providers.github.builderPresets.spoonRepoZip), "function")
        T.assertTrue(providers.remoteZip.capabilities.useFolder)
        T.assertTrue(providers.localFolder.capabilities.path)
        T.assertEqual(type(T.SpoonManager.from.github), "function")
        T.assertEqual(type(T.SpoonManager.from.spoonRepo), "function")
        T.assertEqual(type(T.SpoonManager.from.spoonRepoZip), "function")
        T.assertEqual(type(T.SpoonManager.from.remoteZip), "function")
        T.assertEqual(type(T.SpoonManager.installed.list), "function")
        T.assertEqual(type(T.SpoonManager.installed.spoon), "function")
        T.assertEqual(T.SpoonManager.installed.kind, "installed")
        T.assertEqual(T.SpoonManager.installed.scope, "all")
    end)

    T.test("manager rejects duplicate provider factories", function()
        T.assertError(function()
            T.SpoonManager.registerProvider({
                name = "duplicateGitHub",
                factoryName = "github",
                createSource = function() end,
            })
        end, "Source factory already registered: github")
    end)

    T.test("manager rejects duplicate builder preset factories", function()
        T.assertError(function()
            T.SpoonManager.registerProvider({
                name = "duplicateSpoonRepo",
                factoryName = "duplicateSpoonRepo",
                createSource = function() end,
                builderPresets = {
                    spoonRepo = function() end,
                },
            })
        end, "Source factory already registered: spoonRepo")
    end)

    T.test("manager reload controller pauses batch reloads", function()
        withRecordedInstaller(function(manager)
            local events = {}
            local originalReload = hs.reload

            hs.reload = function()
                table.insert(events, "reload")
            end

            local controller = {
                stop = function(self)
                    T.assertTrue(self)
                    table.insert(events, "stop")
                end,
                start = function(self)
                    T.assertTrue(self)
                    table.insert(events, "start")
                end,
            }

            manager.reloadController(controller)
            manager.update(
                manager.from.default.spoon("Emojis"),
                manager.from.default.spoon("TimeMachineProgress")
            )
            manager.reloadController(nil)
            hs.reload = originalReload

            T.assertEqual(table.concat(events, ","), "stop,start,reload")
        end)
    end)

    T.test("manager reload controller skips reload for unchanged batch", function()
        local manager = T.SpoonManager
        local originalInstallDefinition = manager._installDefinition
        local originalReload = hs.reload
        local events = {}

        manager._installDefinition = function()
            return {
                success = true,
                definition = {
                    result = {
                        name = "Emojis",
                        skipped = true,
                        reason = "source-unchanged",
                    },
                },
            }
        end
        hs.reload = function()
            table.insert(events, "reload")
        end

        manager.reloadController({
            stop = function()
                table.insert(events, "stop")
            end,
            start = function()
                table.insert(events, "start")
            end,
        })

        local result = manager.update(manager.from.default.spoon("Emojis"))

        manager.reloadController(nil)
        manager._installDefinition = originalInstallDefinition
        hs.reload = originalReload

        T.assertTrue(result.success)
        T.assertEqual(#result.runs, 1)
        T.assertTrue(result.runs[1].definition.result.skipped)
        T.assertEqual(table.concat(events, ","), "stop,start")
    end)

    T.test("manager install and update run explicit vararg definitions", function()
        withRecordedInstaller(function(manager, calls)
            local emojis = manager.from.default.spoon("Emojis")
            local timeMachine = manager.from.default.spoon("TimeMachineProgress")

            local installResult = manager.install(emojis, timeMachine)
            T.assertTrue(installResult.success)
            T.assertEqual(#installResult.runs, 2)
            T.assertEqual(#calls, 2)
            T.assertEqual(calls[1].action, "install")
            T.assertEqual(calls[2].config.source.selection_spoon, "TimeMachineProgress")

            local updateResult = manager.update(emojis, timeMachine)
            T.assertTrue(updateResult.success)
            T.assertEqual(#updateResult.runs, 2)
            T.assertEqual(#calls, 4)
            T.assertEqual(calls[3].action, "update")
            T.assertEqual(calls[4].config.source.selection_spoon, "TimeMachineProgress")
        end)
    end)

    T.test("manager accepts an explicit definition list", function()
        withRecordedInstaller(function(manager, calls)
            local definitions = {
                manager.from.default.spoon("Emojis"),
                manager.from.default.spoon("TimeMachineProgress"),
            }

            local result = manager.install(definitions)

            T.assertTrue(result.success)
            T.assertEqual(#result.runs, 2)
            T.assertEqual(#calls, 2)
            T.assertEqual(calls[1].config.source.selection_spoon, "Emojis")
            T.assertEqual(calls[2].config.source.selection_spoon, "TimeMachineProgress")
        end)
    end)

    T.test("manager actions require explicit definitions", function()
        T.assertError(function()
            T.SpoonManager.install()
        end, "SpoonManager.install requires at least one definition")

        T.assertError(function()
            T.SpoonManager.update()
        end, "SpoonManager.update requires at least one definition")
    end)

    T.test("definition install and update are manager action shortcuts", function()
        withRecordedInstaller(function(manager, calls)
            local installResult = manager.from.default
                .spoon("Emojis")
                .install()

            T.assertTrue(installResult.success)
            T.assertEqual(#installResult.runs, 1)
            T.assertEqual(#calls, 1)
            T.assertEqual(calls[1].action, "install")

            local updateResult = manager.from.default
                .spoon("Emojis")
                .update()

            T.assertTrue(updateResult.success)
            T.assertEqual(#updateResult.runs, 1)
            T.assertEqual(#calls, 2)
            T.assertEqual(calls[2].action, "update")
            T.assertEqual(calls[2].config.source.selection_spoon, "Emojis")
        end)
    end)

    T.test("definition shortcut returns failed run without mutating manager state", function()
        local manager = T.SpoonManager
        local originalInstallDefinition = manager._installDefinition

        manager._installDefinition = function(definitionConfig, action)
            return nil, "install failed", {
                config = definitionConfig,
                task = {
                    action = action,
                    name = "Emojis",
                    options = {},
                },
            }
        end

        local ok, result = pcall(function()
            return manager.from.default
                .spoon("Emojis")
                .update()
        end)

        manager._installDefinition = originalInstallDefinition

        T.assertTrue(ok, result)
        T.assertFalse(result.success)
        T.assertEqual(#result.runs, 1)
        T.assertFalse(result.runs[1].success)
        T.assertEqual(result.runs[1].error, "install failed")
    end)

    T.test("installed list returns sorted registry BOM snapshots", function()
        withPatched({
            {
                table = T.context.registry,
                key = "read",
                value = function()
                    return {
                        TimeMachineProgress = {
                            task = {
                                name = "TimeMachineProgress",
                            },
                            config = {
                                source = {
                                    selection_spoon = "TimeMachineProgress",
                                },
                            },
                        },
                        Emojis = {
                            task = {
                                name = "Emojis",
                            },
                            config = {
                                source = {
                                    selection_spoon = "Emojis",
                                },
                            },
                        },
                    }
                end,
            },
        }, function()
            local installed = T.context.installed.create()
            local items = installed.list()

            T.assertEqual(installed.kind, "installed")
            T.assertEqual(installed.scope, "all")
            T.assertEqual(installed.registered, true)
            T.assertEqual(installed.count, 2)
            T.assertEqual(installed.names[1], "Emojis")
            T.assertEqual(installed.names[2], "TimeMachineProgress")
            T.assertEqual(#items, 2)
            T.assertEqual(items[1].task.name, "Emojis")
            T.assertEqual(items[2].task.name, "TimeMachineProgress")

            items[1].task.name = "Mutated"
            T.assertEqual(installed.list()[1].task.name, "Emojis")
        end)
    end)

    T.test("installed spoon selection lists one installed BOM", function()
        withPatched({
            {
                table = T.context.registry,
                key = "read",
                value = function()
                    return {
                        Emojis = {
                            task = {
                                name = "Emojis",
                            },
                        },
                        TimeMachineProgress = {
                            task = {
                                name = "TimeMachineProgress",
                            },
                        },
                    }
                end,
            },
        }, function()
            local installed = T.context.installed.create()
            local selection = installed.spoon("TimeMachineProgress")
            local items = selection.list()

            T.assertEqual(selection.kind, "installed")
            T.assertEqual(selection.scope, "spoon")
            T.assertEqual(selection.name, "TimeMachineProgress")
            T.assertEqual(selection.count, 1)
            T.assertEqual(selection.names[1], "TimeMachineProgress")
            T.assertEqual(selection.registered, true)
            T.assertEqual(#items, 1)
            T.assertEqual(items[1].task.name, "TimeMachineProgress")
            local missing = installed.spoon("Missing")
            T.assertEqual(missing.count, 1)
            T.assertEqual(missing.names[1], "Missing")
            T.assertEqual(missing.registered, false)
            T.assertEqual(#missing.list(), 0)
            T.assertError(function()
                installed.spoon(123)
            end, "Installed Spoon name must be a string")
        end)
    end)

    T.test("installed update runs registry configs through manager update", function()
        withRecordedInstaller(function(manager, calls)
            withPatched({
                {
                    table = T.context.registry,
                    key = "read",
                    value = function()
                        return {
                            TimeMachineProgress = {
                                config = {
                                    source = {
                                        selection_spoon = "TimeMachineProgress",
                                    },
                                },
                            },
                            Emojis = {
                                config = {
                                    source = {
                                        selection_spoon = "Emojis",
                                    },
                                },
                            },
                        }
                    end,
                },
            }, function()
                local installed = T.context.installed.create()
                local result = installed.update()

                T.assertTrue(result.success)
                T.assertEqual(result.action, "update")
                T.assertEqual(#result.runs, 2)
                T.assertEqual(#calls, 2)
                T.assertEqual(calls[1].action, "update")
                T.assertEqual(calls[1].config.source.selection_spoon, "Emojis")
                T.assertEqual(calls[2].config.source.selection_spoon, "TimeMachineProgress")
            end)
        end)
    end)

    T.test("installed spoon selection updates one registry config", function()
        withRecordedInstaller(function(manager, calls)
            withPatched({
                {
                    table = T.context.registry,
                    key = "read",
                    value = function()
                        return {
                            Emojis = {
                                config = {
                                    source = {
                                        selection_spoon = "Emojis",
                                    },
                                },
                            },
                            TimeMachineProgress = {
                                config = {
                                    source = {
                                        selection_spoon = "TimeMachineProgress",
                                    },
                                },
                            },
                        }
                    end,
                },
            }, function()
                local installed = T.context.installed.create()
                local result = installed.spoon("Emojis").update()

                T.assertTrue(result.success)
                T.assertEqual(#result.runs, 1)
                T.assertEqual(#calls, 1)
                T.assertEqual(calls[1].action, "update")
                T.assertEqual(calls[1].config.source.selection_spoon, "Emojis")

                T.assertError(function()
                    installed.spoon("Missing").update()
                end, "Installed Spoon not found: Missing")
            end)
        end)
    end)

    T.test("installed update with empty registry is a no-op", function()
        withPatched({
            {
                table = T.context.registry,
                key = "read",
                value = function()
                    return {}
                end,
            },
        }, function()
            local result = T.context.installed.create().update()

            T.assertTrue(result.success)
            T.assertEqual(result.action, "update")
            T.assertEqual(#result.runs, 0)
        end)
    end)

    T.test("installed doctor reports missing installed spoon folders", function()
        withPatched({
            {
                table = T.context.registry,
                key = "read",
                value = function()
                    return {
                        Emojis = {
                            path = "/tmp/hammerspoon-test/Spoons/Emojis.spoon",
                        },
                        MissingPath = {
                            name = "MissingPath",
                        },
                        TimeMachineProgress = {
                            path = "/tmp/hammerspoon-test/Spoons/TimeMachineProgress.spoon",
                        },
                    }
                end,
            },
            {
                table = T.context.util,
                key = "fileExists",
                value = function(path)
                    return path == "/tmp/hammerspoon-test/Spoons/Emojis.spoon"
                end,
            },
        }, function()
            local result = T.context.installed.create().doctor()

            T.assertFalse(result.success)
            T.assertEqual(#result.checks, 3)
            T.assertEqual(result.checks[1].name, "Emojis")
            T.assertTrue(result.checks[1].installed)
            T.assertFalse(result.checks[1].reason)
            T.assertEqual(result.checks[2].name, "MissingPath")
            T.assertFalse(result.checks[2].installed)
            T.assertEqual(result.checks[2].reason, "missing-path")
            T.assertEqual(result.checks[3].name, "TimeMachineProgress")
            T.assertFalse(result.checks[3].installed)
            T.assertEqual(result.checks[3].reason, "missing-folder")
        end)
    end)

    T.test("installed doctor supports one spoon selection", function()
        withPatched({
            {
                table = T.context.registry,
                key = "read",
                value = function()
                    return {
                        Emojis = {
                            path = "/tmp/hammerspoon-test/Spoons/Emojis.spoon",
                        },
                    }
                end,
            },
            {
                table = T.context.util,
                key = "fileExists",
                value = function()
                    return true
                end,
            },
        }, function()
            local installed = T.context.installed.create()
            local result = installed.spoon("Emojis").doctor()

            T.assertTrue(result.success)
            T.assertEqual(#result.checks, 1)
            T.assertEqual(result.checks[1].path, "/tmp/hammerspoon-test/Spoons/Emojis.spoon")

            local missing = installed.spoon("Missing").doctor()
            T.assertFalse(missing.success)
            T.assertEqual(#missing.checks, 1)
            T.assertEqual(missing.checks[1].name, "Missing")
            T.assertFalse(missing.checks[1].installed)
            T.assertEqual(missing.checks[1].reason, "missing-registry-entry")
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
            T.assertEqual(#result.runs, 1)
            local run = result.runs[1]
            T.assertTrue(run.definition.config)
            T.assertTrue(run.definition.resolved)
            T.assertTrue(run.definition.command)
            T.assertTrue(run.definition.task)
            T.assertTrue(run.definition.result)
            T.assertEqual(result.action, "install")
            T.assertFalse(result.name)
            T.assertFalse(result.path)
            T.assertFalse(result.skipped)
            T.assertFalse(result.reason)
            T.assertFalse(result.task)
            T.assertFalse(result.result)
            T.assertEqual(run.definition.result.action, "install")
            T.assertEqual(run.definition.result.name, "Emojis")
            T.assertEqual(run.definition.result.path, "/tmp/hammerspoon-test/Spoons/Emojis.spoon")
            T.assertTrue(run.definition.result.skipped)
            T.assertEqual(run.definition.result.reason, "already-installed")
            T.assertEqual(#used, 1)
            T.assertEqual(used[1].name, "Emojis")
            T.assertEqual(used[1].options.start, true)
        end)
    end)

    T.test("installer exposes update definition without remapping sections", function()
        withPatched({
            {
                table = T.context.sourceStage,
                key = "fromCommand",
                value = function(command)
                    T.assertEqual(command.action, "update")
                    return {
                        folder = "/stage/Emojis.spoon",
                    }
                end,
            },
            {
                table = T.context.sourceStage,
                key = "cleanup",
                value = function() end,
            },
            {
                table = T.context.installer,
                key = "installFromStage",
                value = function()
                    return {
                        success = true,
                        action = "update",
                        name = "Emojis",
                        path = "/tmp/hammerspoon-test/Spoons/Emojis.spoon",
                        skipped = true,
                        reason = "source-unchanged",
                        fingerprints = {
                            stagedSourceHash = "source-hash",
                            storedSourceHash = "source-hash",
                        },
                    }
                end,
            },
        }, function()
            local result, err = T.context.installer.installDefinition(
                T.SpoonManager.from.default
                    .spoon("Emojis")
                    .toConfig(),
                "update"
            )

            T.assertTrue(result, err)
            T.assertTrue(result.definition.config)
            T.assertTrue(result.definition.resolved)
            T.assertTrue(result.definition.command)
            T.assertTrue(result.definition.task)
            T.assertTrue(result.definition.result)
            T.assertFalse(result.action)
            T.assertFalse(result.name)
            T.assertFalse(result.path)
            T.assertFalse(result.config)
            T.assertFalse(result.resolved)
            T.assertFalse(result.command)
            T.assertFalse(result.task)
            T.assertFalse(result.result)
            T.assertEqual(result.definition.result.action, "update")
            T.assertEqual(result.definition.result.name, "Emojis")
            T.assertEqual(result.definition.result.path, "/tmp/hammerspoon-test/Spoons/Emojis.spoon")
            T.assertTrue(result.definition.result.skipped)
            T.assertEqual(result.definition.result.reason, "source-unchanged")
            T.assertEqual(result.definition.result.fingerprints.stagedSourceHash, "source-hash")
        end)
    end)

    T.test("installer prepares task values in one section", function()
        local prepared = T.context.installer.prepareDefinition(
            T.SpoonManager.from.default
                .spoon("Emojis")
                .use({
                    start = true,
                })
                .toConfig(),
            "update"
        )

        T.assertEqual(prepared.task.action, "update")
        T.assertEqual(prepared.task.name, "Emojis")
        T.assertEqual(prepared.task.options.conflictStrategy, T.SpoonManager.options.conflictStrategy.abort)
        T.assertEqual(prepared.task.use.start, true)
        T.assertFalse(prepared.execution)
        T.assertFalse(prepared.name)
        T.assertFalse(prepared.options)
        T.assertFalse(prepared.use)
    end)

    T.test("registry stores a narrow versioned record", function()
        local written

        withPatched({
            {
                table = T.context.registry,
                key = "read",
                value = function()
                    return {
                        Emojis = {
                            installedAt = "2026-08-01T00:00:00Z",
                        },
                    }
                end,
            },
            {
                table = T.context.registry,
                key = "write",
                value = function(registry)
                    written = registry
                    return true
                end,
            },
        }, function()
            local ok, err = T.context.registry.persistInstall({
                task = {
                    name = "Emojis",
                    use = {
                        start = true,
                    },
                },
                config = {
                    source = {
                        selection_spoon = "Emojis",
                    },
                },
                resolved = {},
                command = {},
            }, "/tmp/hammerspoon-test/Spoons/Emojis.spoon", {
                stagedSourceHash = "source-hash",
                targetFolderHash = "target-hash",
            })

            T.assertTrue(ok, err)
            local record = written.Emojis
            T.assertEqual(record.schemaVersion, 1)
            T.assertEqual(record.name, "Emojis")
            T.assertEqual(record.path, "/tmp/hammerspoon-test/Spoons/Emojis.spoon")
            T.assertEqual(record.config.source.selection_spoon, "Emojis")
            T.assertEqual(record.fingerprints.stagedSourceHash, "source-hash")
            T.assertEqual(record.fingerprints.targetFolderHash, "target-hash")
            T.assertEqual(record.installedAt, "2026-08-01T00:00:00Z")
            T.assertTrue(record.updatedAt)
            -- runtime scaffolding is NOT persisted
            T.assertFalse(record.resolved)
            T.assertFalse(record.command)
            T.assertFalse(record.task)
            T.assertFalse(record.registryMeta)
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
            local ok, err = T.context.installer.checkLocalChanges(preparedTask("Emojis"), destination)

            T.assertFalse(ok)
            T.assertEqual(err, "Spoon already exists but is not managed by SpoonManager. Use .conflictStrategy(\"backup\") or .conflictStrategy(\"overwrite\") to install anyway.")
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
                            fingerprints = {
                                targetFolderHash = "same",
                            },
                        },
                    }
                end,
            },
            {
                table = T.context.util,
                key = "hashDirectory",
                value = function()
                    return "same"
                end,
            },
        }, function()
            local ok, err = T.context.installer.checkLocalChanges(preparedTask("Emojis"), destination)

            T.assertTrue(ok, err)
        end)
    end)

    T.test("update skips when staged source is unchanged", function()
        local copied = false
        local used = {}

        withPatched({
            {
                table = T.context.util,
                key = "fileExists",
                value = function(path)
                    return path == "/stage/Emojis.spoon/init.lua"
                end,
            },
            {
                table = T.context.util,
                key = "hashDirectory",
                value = function()
                    return "source-hash"
                end,
            },
            {
                table = T.context.registry,
                key = "read",
                value = function()
                    return {
                        Emojis = {
                            fingerprints = {
                                stagedSourceHash = "source-hash",
                            },
                        },
                    }
                end,
            },
            {
                table = T.context.util,
                key = "copyPath",
                value = function()
                    copied = true
                    return nil, false
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
            local result, err = T.context.installer.installFromStage(preparedTask("Emojis", nil, {
                start = true,
            }), {
                folder = "/stage/Emojis.spoon",
            }, "update")

            T.assertTrue(result, err)
            T.assertTrue(result.skipped)
            T.assertEqual(result.reason, "source-unchanged")
            T.assertEqual(result.fingerprints.stagedSourceHash, "source-hash")
            T.assertEqual(result.fingerprints.storedSourceHash, "source-hash")
            T.assertFalse(copied)
            T.assertEqual(#used, 1)
            T.assertEqual(used[1].name, "Emojis")
            T.assertEqual(used[1].options.start, true)
        end)
    end)

    T.test("update skips when staged source matches installed folder", function()
        local copied = false
        local persisted

        withPatched({
            {
                table = T.context.util,
                key = "fileExists",
                value = function(path)
                    return path == "/stage/Emojis.spoon/init.lua"
                        or path == "/tmp/hammerspoon-test/Spoons/Emojis.spoon"
                end,
            },
            {
                table = T.context.util,
                key = "hashDirectory",
                value = function()
                    return "stable-hash"
                end,
            },
            {
                table = T.context.registry,
                key = "read",
                value = function()
                    return {
                        Emojis = {
                            fingerprints = {
                                stagedSourceHash = "old-path-dependent-source-hash",
                                targetFolderHash = "old-path-dependent-target-hash",
                            },
                        },
                    }
                end,
            },
            {
                table = T.context.registry,
                key = "persistInstall",
                value = function(definition, destination, fingerprints)
                    persisted = {
                        name = definition.task.name,
                        destination = destination,
                        targetFolderHash = fingerprints.targetFolderHash,
                        stagedSourceHash = fingerprints.stagedSourceHash,
                    }
                    return true
                end,
            },
            {
                table = T.context.util,
                key = "copyPath",
                value = function()
                    copied = true
                    return nil, false
                end,
            },
        }, function()
            local result, err = T.context.installer.installFromStage(preparedTask("Emojis"), {
                folder = "/stage/Emojis.spoon",
            }, "update")

            T.assertTrue(result, err)
            T.assertTrue(result.skipped)
            T.assertEqual(result.reason, "source-unchanged")
            T.assertEqual(result.fingerprints.stagedSourceHash, "stable-hash")
            T.assertEqual(result.fingerprints.storedSourceHash, "old-path-dependent-source-hash")
            T.assertEqual(result.fingerprints.targetFolderHash, "stable-hash")
            T.assertFalse(copied)
            T.assertEqual(persisted.name, "Emojis")
            T.assertEqual(persisted.destination, "/tmp/hammerspoon-test/Spoons/Emojis.spoon")
            T.assertEqual(persisted.targetFolderHash, "stable-hash")
            T.assertEqual(persisted.stagedSourceHash, "stable-hash")
        end)
    end)

    T.test("update result includes fingerprints when source changed", function()
        local copied = false
        local hashCalls = 0

        withPatched({
            {
                table = T.context.util,
                key = "fileExists",
                value = function(path)
                    return path == "/stage/Emojis.spoon/init.lua"
                        or path == "/tmp/hammerspoon-test/Spoons/Emojis.spoon"
                end,
            },
            {
                table = T.context.util,
                key = "hashDirectory",
                value = function()
                    hashCalls = hashCalls + 1
                    if hashCalls == 1 then
                        return "new-source-hash"
                    end
                    if hashCalls == 4 then
                        return "new-target-hash"
                    end
                    return "old-target-hash"
                end,
            },
            {
                table = T.context.registry,
                key = "read",
                value = function()
                    return {
                        Emojis = {
                            fingerprints = {
                                stagedSourceHash = "old-source-hash",
                                targetFolderHash = "old-target-hash",
                            },
                        },
                    }
                end,
            },
            {
                table = T.context.util,
                key = "copyPath",
                value = function()
                    copied = true
                    return "", true
                end,
            },
        }, function()
            local result, err = T.context.installer.installFromStage(preparedTask("Emojis"), {
                folder = "/stage/Emojis.spoon",
            }, "update")

            T.assertTrue(result, err)
            T.assertTrue(copied)
            T.assertEqual(result.fingerprints.stagedSourceHash, "new-source-hash")
            T.assertEqual(result.fingerprints.targetFolderHash, "new-target-hash")
        end)
    end)

    T.test("update does not install untracked spoon", function()
        local copied = false

        withPatched({
            {
                table = T.context.util,
                key = "fileExists",
                value = function(path)
                    return path == "/stage/Emojis.spoon/init.lua"
                end,
            },
            {
                table = T.context.util,
                key = "hashDirectory",
                value = function()
                    return "source-hash"
                end,
            },
            {
                table = T.context.registry,
                key = "read",
                value = function()
                    return {}
                end,
            },
            {
                table = T.context.util,
                key = "copyPath",
                value = function()
                    copied = true
                    return nil, false
                end,
            },
        }, function()
            local result, err = T.context.installer.installFromStage(preparedTask("Emojis"), {
                folder = "/stage/Emojis.spoon",
            }, "update")

            T.assertFalse(result)
            T.assertEqual(err, "Spoon is not installed by SpoonManager. Use install() first.")
            T.assertFalse(copied)
        end)
    end)

    T.test("source stage excludes configured folders", function()
        local removedOptions

        withPatched({
            {
                table = hs,
                key = "execute",
                value = function(command)
                    if command == "/usr/bin/mktemp -d" then
                        return "/stage\n", true
                    end
                    return "", true
                end,
            },
            {
                table = T.context.util,
                key = "copyPath",
                value = function()
                    return "", true
                end,
            },
            {
                table = T.context.util,
                key = "removeIgnoredNames",
                value = function(path, options)
                    removedOptions = {
                        path = path,
                        excludeFolders = options.excludeFolders,
                    }
                    return true
                end,
            },
        }, function()
            local stage, err = T.context.sourceStage.fromFolderSource({
                kind = "folder",
                location = {
                    kind = "path",
                    path = "/source/EmmyLua.spoon",
                },
                excludeFolders = {
                    "annotations",
                },
            })

            T.assertTrue(stage, err)
            T.assertEqual(stage.folder, "/stage/source.spoon")
            T.assertEqual(removedOptions.path, "/stage/source.spoon")
            T.assertEqual(removedOptions.excludeFolders[1], "annotations")
        end)
    end)
end
