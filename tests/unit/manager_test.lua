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

        manager.clear()
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
                action = action,
                name = (
                    source.selection_spoon
                    or naming.withName
                    or extract.useFolder
                    or source.zipFile
                    or source.selection_path
                ) or "unknown",
                result = {},
            }
        end

        local ok, err = pcall(fn, manager, calls)
        manager._installDefinition = originalInstallDefinition
        manager.clear()

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
                name = "Emojis",
                result = {
                    skipped = true,
                    reason = "source-unchanged",
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
        T.assertEqual(#result.skipped, 1)
        T.assertEqual(table.concat(events, ","), "stop,start")
    end)

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
            T.assertEqual(calls[2].config.source.selection_spoon, "TimeMachineProgress")

            local updateResult = manager.update()
            T.assertTrue(updateResult.success)
            T.assertEqual(#calls, 4)
            T.assertEqual(calls[3].action, "update")
            T.assertEqual(calls[4].config.source.selection_spoon, "TimeMachineProgress")
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
            T.assertEqual(calls[1].config.source.selection_spoon, "Emojis")
        end)
    end)

    T.test("manager install with explicit definitions stores them", function()
        withRecordedInstaller(function(manager, calls)
            local emojis = manager.from.default.spoon("Emojis")
            local timeMachine = manager.from.default.spoon("TimeMachineProgress")

            manager.install(emojis, timeMachine)

            T.assertEqual(#calls, 2)
            T.assertEqual(#manager.definitions, 2)
            T.assertEqual(manager.definitions[1].source.selection_spoon, "Emojis")
            T.assertEqual(manager.definitions[2].source.selection_spoon, "TimeMachineProgress")

            manager.update()
            T.assertEqual(#calls, 4)
            T.assertEqual(calls[3].action, "update")
            T.assertEqual(calls[4].config.source.selection_spoon, "TimeMachineProgress")
        end)
    end)

    T.test("definition install stores itself in manager", function()
        withRecordedInstaller(function(manager, calls)
            manager.from.default
                .spoon("Emojis")
                .install()

            T.assertEqual(#calls, 1)
            T.assertEqual(#manager.definitions, 1)
            T.assertEqual(manager.definitions[1].source.selection_spoon, "Emojis")

            manager.update()
            T.assertEqual(#calls, 2)
            T.assertEqual(calls[2].action, "update")
            T.assertEqual(calls[2].config.source.selection_spoon, "Emojis")
        end)
    end)

    T.test("manager remembers prepared name without reading output result", function()
        local manager = T.SpoonManager
        local originalInstallDefinition = manager._installDefinition

        manager.clear()
        manager._installDefinition = function(definitionConfig, action)
            return {
                success = true,
            }, nil, {
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
        T.assertTrue(result.success)
        T.assertEqual(#manager.definitions, 1)
        T.assertEqual(manager.definitions[1].source.selection_spoon, "Emojis")
        manager.clear()
    end)

    T.test("manager debug info does not break update", function()
        local manager = T.SpoonManager
        local originalInstallDefinition = manager._installDefinition
        local originalDebug = manager.logger.df
        local originalInspect = hs.inspect
        local inspected

        manager.clear()
        hs.inspect = function(value)
            inspected = value
            return "inspected-debug-info"
        end
        manager.logger.df = function()
            error("")
        end
        manager._installDefinition = function(definitionConfig, action)
            return {
                success = true,
                result = {
                    success = true,
                    action = action,
                    skipped = true,
                    name = "Emojis",
                },
            }, nil, {
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
        manager.logger.df = originalDebug
        hs.inspect = originalInspect

        T.assertTrue(ok, result)
        T.assertTrue(result.success)
        T.assertEqual(#manager.definitions, 1)
        T.assertTrue(inspected.config)
        manager.clear()
    end)

    T.test("manager debug stacktrace does not break update", function()
        local manager = T.SpoonManager
        local originalInstallDefinition = manager._installDefinition
        local originalTraceback = debug.traceback

        manager.clear()
        debug.traceback = function()
            error("traceback failed")
        end
        manager._installDefinition = function(definitionConfig, action)
            return {
                success = true,
                result = {
                    success = true,
                    action = action,
                    skipped = true,
                    name = "Emojis",
                },
            }, nil, {
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
        debug.traceback = originalTraceback

        T.assertTrue(ok, result)
        T.assertTrue(result.success)
        T.assertEqual(#manager.definitions, 1)
        manager.clear()
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
            T.assertEqual(manager.definitions[1].source.selection_spoon, "Emojis")
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
            T.assertTrue(result.task.config)
            T.assertTrue(result.task.resolved)
            T.assertTrue(result.task.command)
            T.assertFalse(result.action)
            T.assertFalse(result.name)
            T.assertFalse(result.path)
            T.assertFalse(result.skipped)
            T.assertFalse(result.reason)
            T.assertEqual(result.result.action, "install")
            T.assertEqual(result.result.name, "Emojis")
            T.assertEqual(result.result.path, "/tmp/hammerspoon-test/Spoons/Emojis.spoon")
            T.assertTrue(result.result.skipped)
            T.assertEqual(result.result.reason, "already-installed")
            T.assertEqual(#used, 1)
            T.assertEqual(used[1].name, "Emojis")
            T.assertEqual(used[1].options.start, true)
        end)
    end)

    T.test("installer wraps update result separately from task", function()
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
            T.assertTrue(result.task.config)
            T.assertTrue(result.task.resolved)
            T.assertTrue(result.task.command)
            T.assertFalse(result.action)
            T.assertFalse(result.name)
            T.assertFalse(result.path)
            T.assertFalse(result.config)
            T.assertFalse(result.resolved)
            T.assertFalse(result.command)
            T.assertEqual(result.result.action, "update")
            T.assertEqual(result.result.name, "Emojis")
            T.assertEqual(result.result.path, "/tmp/hammerspoon-test/Spoons/Emojis.spoon")
            T.assertTrue(result.result.skipped)
            T.assertEqual(result.result.reason, "source-unchanged")
            T.assertEqual(result.result.fingerprints.stagedSourceHash, "source-hash")
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

    T.test("registry stores clear fingerprint names", function()
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
                config = {},
                resolved = {},
                command = {},
            }, "/tmp/hammerspoon-test/Spoons/Emojis.spoon", {
                stagedSourceHash = "source-hash",
                targetFolderHash = "target-hash",
            })

            T.assertTrue(ok, err)
            T.assertEqual(written.Emojis.fingerprints.stagedSourceHash, "source-hash")
            T.assertEqual(written.Emojis.fingerprints.targetFolderHash, "target-hash")
            T.assertFalse(written.Emojis.checksum)
            T.assertFalse(written.Emojis.fingerprints.sourceHash)
            T.assertFalse(written.Emojis.fingerprints.localHash)
            T.assertEqual(written.Emojis.use.start, true)
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
