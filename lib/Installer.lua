return function(context)
    local Installer = {}
    local spoonExtractor = context.spoonExtractor
    local sourceStage = context.sourceStage
    local logger = context.logger
    local manager = context.manager
    local paths = context.paths
    local registry = context.registry
    local definitionResolver = context.definitionResolver
    local util = context.util
    local ports = context.ports

    local function task(definition)
        return definition.task or error("Prepared definition requires task section", 3)
    end

    local function actionOutput(definition, result)
        local def = util.copyTable(definition)
        def.result = util.copyTable(result)
        return {
            success = result.success,
            definition = def,
        }
    end

    -- Existing files at the destination: overwrite proceeds, backup moves them
    -- aside, anything else (including a nil/abort strategy) aborts with the message.
    local function resolveExistingConflict(behavior, destination, backupError, abortError)
        if behavior == manager.options.conflictStrategy.overwrite then
            return true
        end

        if behavior == manager.options.conflictStrategy.backup then
            local backupPath = destination .. ".backup-" .. ports.clock.stamp()
            local _, ok = util.movePath(destination, backupPath, logger)
            if ok then
                return true
            end
            return nil, backupError
        end

        return nil, abortError
    end

    function Installer.prepareDefinition(definition, action)
        local def = definition.config and util.copyTable(definition) or {
            config = util.copyTable(definition),
        }
        action = action or "install"

        def = definitionResolver.withCommand(def, action)
        def.task = {
            action = action,
            name = def.command.name,
            options = util.copyTable(def.command.options),
            use = util.copyTable(def.command.use),
        }

        return def
    end

    function Installer.validateDefinition(definition)
        if type(definition) ~= "table" then
            return nil, "Spoon definition must be a table"
        end

        if not definition.command or not definition.command.source or not definition.command.source.kind then
            return nil, "Spoon definition requires a source"
        end

        local run = task(definition)
        if not run.name then
            return nil, "Spoon definition requires a Spoon name. Add .withName(\"Name\")."
        end

        if run.options and run.options.conflictStrategy and not manager._isConflictStrategy(run.options.conflictStrategy) then
            return nil, "Invalid conflict strategy: " .. tostring(run.options.conflictStrategy)
        end

        return true
    end

    function Installer.checkLocalChanges(definition, destination)
        local run = task(definition)
        local installed = registry.read()[run.name]

        if not util.fileExists(destination) then
            return true
        end

        local behavior = run.options.conflictStrategy

        if not installed then
            return resolveExistingConflict(behavior, destination,
                "Could not backup existing unmanaged Spoon",
                "Spoon already exists but is not managed by SpoonManager. Use .conflictStrategy(\"backup\") or .conflictStrategy(\"overwrite\") to install anyway.")
        end

        -- Managed Spoon: without a stored hash we cannot verify integrity, so we
        -- can neither confirm it is unchanged nor prove local changes.
        local knownHash = installed.fingerprints and installed.fingerprints.targetFolderHash
        if not knownHash then
            return resolveExistingConflict(behavior, destination,
                "Could not backup Spoon with a missing baseline hash",
                "Cannot detect local changes: the baseline hash is missing. Use .conflictStrategy(\"backup\") or .conflictStrategy(\"overwrite\") to update anyway.")
        end

        if util.hashDirectory(destination, nil, logger) == knownHash then
            return true
        end

        return resolveExistingConflict(behavior, destination,
            "Could not backup locally changed Spoon",
            "Local changes detected. Use .conflictStrategy(\"backup\") or .conflictStrategy(\"overwrite\") to update anyway.")
    end

    function Installer.applyUse(definition)
        local run = task(definition)
        if not run.use then
            return true
        end

        local arg = util.copyTable(run.use)
        arg.disable = nil
        return ports.spoons.use(run.name, arg, false)
    end

    function Installer.skipUnchangedUpdate(definition, destination, stagedSourceHash)
        local run = task(definition)
        local installed = registry.read()[run.name]
        if not installed then
            return nil, "Spoon is not installed by SpoonManager. Use install() first."
        end

        local installedHashes = installed.fingerprints or {}
        local storedSourceHash = installedHashes.stagedSourceHash
        if stagedSourceHash and stagedSourceHash == storedSourceHash then
            Installer.applyUse(definition)
            return {
                success = true,
                action = "update",
                skipped = true,
                reason = "source-unchanged",
                name = run.name,
                path = destination,
                fingerprints = {
                    stagedSourceHash = stagedSourceHash,
                    storedSourceHash = storedSourceHash,
                },
                use = run.use,
            }
        end

        local targetFolderHash = util.hashDirectory(destination, nil, logger)
        if stagedSourceHash and targetFolderHash == stagedSourceHash then
            local result = {
                success = true,
                action = "update",
                skipped = true,
                reason = "source-unchanged",
                name = run.name,
                path = destination,
                fingerprints = {
                    stagedSourceHash = stagedSourceHash,
                    storedSourceHash = storedSourceHash,
                    targetFolderHash = targetFolderHash,
                },
                use = run.use,
            }
            definition.result = util.copyTable(result)
            registry.persistInstall(definition, destination, {
                targetFolderHash = targetFolderHash,
                stagedSourceHash = stagedSourceHash,
            })
            Installer.applyUse(definition)
            return result
        end

        return false
    end

    function Installer.installFromStage(definition, stage, action)
        local run = task(definition)
        local destination = paths.targetPath(run.name)
        util.ensureDir(paths.installRoot(), logger)

        local valid, validationError = spoonExtractor.validateInstalledFolder(stage.folder)
        if not valid then
            return nil, validationError
        end

        local stagedSourceHash = util.hashDirectory(stage.folder, nil, logger)
        if action == "update" then
            local skipped, skipErr = Installer.skipUnchangedUpdate(definition, destination, stagedSourceHash)
            if skipped or skipErr then
                return skipped, skipErr
            end
        end

        local ok, err = Installer.checkLocalChanges(definition, destination)
        if not ok then
            return nil, err
        end

        local _, copied = util.copyPath(stage.folder, destination, logger)
        if not copied then
            return nil, "Could not install Spoon folder"
        end

        local targetFolderHash = util.hashDirectory(destination, nil, logger)
        local result = {
            success = true,
            action = action,
            name = run.name,
            path = destination,
            fingerprints = {
                stagedSourceHash = stagedSourceHash,
                targetFolderHash = targetFolderHash,
            },
            use = run.use,
        }
        definition.result = util.copyTable(result)
        registry.persistInstall(definition, destination, {
            targetFolderHash = targetFolderHash,
            stagedSourceHash = stagedSourceHash,
        })
        Installer.applyUse(definition)

        return result
    end

    function Installer.installDefinition(definition, action)
        local def = Installer.prepareDefinition(definition, action)
        local command = util.copyTable(def.command)
        command.action = action or "install"

        local valid, validationError = Installer.validateDefinition(def)
        if not valid then
            return nil, validationError, def
        end

        action = action or "install"

        local run = task(def)
        if action == "install" and util.fileExists(paths.targetPath(run.name)) then
            Installer.applyUse(def)
            return actionOutput(def, {
                success = true,
                action = "install",
                skipped = true,
                reason = "already-installed",
                name = run.name,
                path = paths.targetPath(run.name),
                use = run.use,
            }), nil, def
        end

        local stage, stageErr = sourceStage.fromCommand(command)
        if not stage then
            return nil, stageErr, def
        end

        local result, err = Installer.installFromStage(def, stage, action)
        sourceStage.cleanup(stage)

        if not result then
            return nil, err, def
        end

        return actionOutput(def, result), nil, def
    end

    return Installer
end
