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

    function Installer.prepareDefinition(definition, action)
        local def = definition.config and util.copyTable(definition) or {
            config = util.copyTable(definition),
        }
        action = action or "install"

        def = definitionResolver.withCommand(def, action)
        def.name = def.command.name
        def.options = util.copyTable(def.command.options)
        def.use = util.copyTable(def.command.use)

        return def
    end

    function Installer.validateDefinition(definition)
        if type(definition) ~= "table" then
            return nil, "Spoon definition must be a table"
        end

        if not definition.command or not definition.command.source or not definition.command.source.kind then
            return nil, "Spoon definition requires a source"
        end

        if not definition.name then
            return nil, "Spoon definition requires a Spoon name. Add .withName(\"Name\")."
        end

        if definition.options and definition.options.conflictStrategy and not manager._isConflictStrategy(definition.options.conflictStrategy) then
            return nil, "Invalid conflict strategy: " .. tostring(definition.options.conflictStrategy)
        end

        return true
    end

    function Installer.checkLocalChanges(definition, destination)
        local installed = registry.read()[definition.name]

        if not util.fileExists(destination) then
            return true
        end

        local behavior = definition.options.conflictStrategy or manager.options.conflictStrategy.abort

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
        if not definition.use then
            return true
        end

        local arg = util.copyTable(definition.use)
        arg.disable = nil
        return hs.spoons.use(definition.name, arg, false)
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
        local installed = registry.read()[definition.name]
        if not installed then
            return nil, "Spoon is not installed by SpoonManager. Use install() first."
        end

        if sourceHash and sourceHash == Installer.installedSourceHash(installed) then
            Installer.applyUse(definition)
            return {
                success = true,
                action = "update",
                skipped = true,
                reason = "source-unchanged",
                name = definition.name,
                path = destination,
                use = definition.use,
            }
        end

        return false
    end

    function Installer.installFromStage(definition, stage, action)
        local destination = paths.targetPath(definition.name)
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
            name = definition.name,
            path = destination,
            use = definition.use,
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

        if action == "install" and util.fileExists(paths.targetPath(def.name)) then
            Installer.applyUse(def)
            return {
                success = true,
                action = "install",
                skipped = true,
                reason = "already-installed",
                name = def.name,
                path = paths.targetPath(def.name),
                config = def.config,
                command = command,
                resolved = def.resolved,
                use = def.use,
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
