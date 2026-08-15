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

    local function execution(definition)
        return definition.execution or {
            action = definition.command and definition.command.action or nil,
            name = definition.name,
            options = definition.options or {},
            use = definition.use,
        }
    end

    function Installer.prepareDefinition(definition, action)
        local def = definition.config and util.copyTable(definition) or {
            config = util.copyTable(definition),
        }
        action = action or "install"

        def = definitionResolver.withCommand(def, action)
        def.execution = {
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

        local run = execution(definition)
        if not run.name then
            return nil, "Spoon definition requires a Spoon name. Add .withName(\"Name\")."
        end

        if run.options and run.options.conflictStrategy and not manager._isConflictStrategy(run.options.conflictStrategy) then
            return nil, "Invalid conflict strategy: " .. tostring(run.options.conflictStrategy)
        end

        return true
    end

    function Installer.checkLocalChanges(definition, destination)
        local run = execution(definition)
        local installed = registry.read()[run.name]

        if not util.fileExists(destination) then
            return true
        end

        local behavior = run.options.conflictStrategy or manager.options.conflictStrategy.abort

        if not installed or not installed.checksum then
            if behavior == manager.options.conflictStrategy.overwrite then
                return true
            end

            if behavior == manager.options.conflictStrategy.backup then
                local backupPath = destination .. ".backup-" .. os.date("!%Y%m%dT%H%M%SZ")
                local _, ok = util.movePath(destination, backupPath, logger)
                if ok then
                    return true
                end
                return nil, "Could not backup existing unmanaged Spoon"
            end

            return nil, "Spoon already exists but is not managed by SpoonManager. Use .conflictStrategy(\"backup\") or .conflictStrategy(\"overwrite\") to install anyway."
        end

        local currentChecksum = util.hashDirectory(destination, nil, logger)
        if currentChecksum == installed.checksum then
            return true
        end

        if behavior == manager.options.conflictStrategy.overwrite then
            return true
        end

        if behavior == manager.options.conflictStrategy.backup then
            local backupPath = destination .. ".backup-" .. os.date("!%Y%m%dT%H%M%SZ")
            local _, ok = util.movePath(destination, backupPath, logger)
            if ok then
                return true
            end
            return nil, "Could not backup locally changed Spoon"
        end

        return nil, "Local changes detected. Use .conflictStrategy(\"backup\") or .conflictStrategy(\"overwrite\") to update anyway."
    end

    function Installer.applyUse(definition)
        local run = execution(definition)
        if not run.use then
            return true
        end

        local arg = util.copyTable(run.use)
        arg.disable = nil
        return hs.spoons.use(run.name, arg, false)
    end

    function Installer.installedSourceHash(installed)
        if not installed then
            return nil
        end

        if installed.fingerprints and installed.fingerprints.sourceHash then
            return installed.fingerprints.sourceHash
        end

        return installed.checksum
    end

    function Installer.skipUnchangedUpdate(definition, destination, sourceHash)
        local run = execution(definition)
        local installed = registry.read()[run.name]
        if not installed then
            return nil, "Spoon is not installed by SpoonManager. Use install() first."
        end

        local installedSourceHash = Installer.installedSourceHash(installed)
        if sourceHash and sourceHash == installedSourceHash then
            Installer.applyUse(definition)
            return {
                success = true,
                action = "update",
                skipped = true,
                reason = "source-unchanged",
                name = run.name,
                path = destination,
                fingerprints = {
                    sourceHash = sourceHash,
                    installedSourceHash = installedSourceHash,
                },
                use = run.use,
            }
        end

        local localHash = util.hashDirectory(destination, nil, logger)
        if sourceHash and localHash == sourceHash then
            registry.persistInstall(definition, destination, {
                localHash = localHash,
                sourceHash = sourceHash,
            })
            Installer.applyUse(definition)
            return {
                success = true,
                action = "update",
                skipped = true,
                reason = "source-unchanged",
                name = run.name,
                path = destination,
                fingerprints = {
                    localHash = localHash,
                    sourceHash = sourceHash,
                    installedSourceHash = installedSourceHash,
                },
                use = run.use,
            }
        end

        return false
    end

    function Installer.installFromStage(definition, stage, action)
        local run = execution(definition)
        local destination = paths.targetPath(run.name)
        util.ensureDir(paths.installRoot(), logger)

        local valid, validationError = spoonExtractor.validateInstalledFolder(stage.folder)
        if not valid then
            return nil, validationError
        end

        local sourceHash = util.hashDirectory(stage.folder, nil, logger)
        if action == "update" then
            local skipped, skipErr = Installer.skipUnchangedUpdate(definition, destination, sourceHash)
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

        local localHash = util.hashDirectory(destination, nil, logger)
        registry.persistInstall(definition, destination, {
            localHash = localHash,
            sourceHash = sourceHash,
        })
        Installer.applyUse(definition)

        return {
            success = true,
            action = "install",
            name = run.name,
            path = destination,
            fingerprints = {
                localHash = localHash,
                sourceHash = sourceHash,
            },
            use = run.use,
        }
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

        local run = execution(def)
        if action == "install" and util.fileExists(paths.targetPath(run.name)) then
            Installer.applyUse(def)
            return {
                success = true,
                action = "install",
                skipped = true,
                reason = "already-installed",
                name = run.name,
                path = paths.targetPath(run.name),
                config = def.config,
                command = command,
                resolved = def.resolved,
                use = run.use,
            }, nil, def
        end

        local stage, stageErr = sourceStage.fromCommand(command)
        if not stage then
            return nil, stageErr, def
        end

        local result, err = Installer.installFromStage(def, stage, action)
        sourceStage.cleanup(stage)

        if result then
            result.action = action
            result.config = def.config
            result.command = command
            result.resolved = def.resolved
        end
        return result, err, def
    end

    return Installer
end
