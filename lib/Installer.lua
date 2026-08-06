return function(context)
    local Installer = {}
    local archive = context.archive
    local logger = context.logger
    local manager = context.manager
    local paths = context.paths
    local registry = context.registry
    local resolver = context.resolver
    local util = context.util

    function Installer.checksumDirectory(path)
        if not util.fileExists(path) then
            return nil
        end

        local command = table.concat({
            "/usr/bin/find",
            util.shellQuote(path),
            "-type f",
            "! -name .DS_Store",
            "-print0",
            "|",
            "/usr/bin/xargs -0 /usr/bin/shasum -a 256",
            "|",
            "/usr/bin/shasum -a 256",
            "|",
            "/usr/bin/awk '{ print $1 }'",
        }, " ")

        return util.execute(command, logger, "Could not checksum %s", path)
    end

    function Installer.prepareDefinition(definition, action)
        local def = definition.config and util.copyTable(definition) or {
            config = util.copyTable(definition),
        }
        action = action or "install"

        def = resolver.withCommand(def, action)
        def.name = def.command.name
        def.options = util.copyTable(def.command.options)
        def.use = util.copyTable(def.command.use)

        return def
    end

    function Installer.validateDefinition(definition)
        if type(definition) ~= "table" then
            return nil, "Spoon definition must be a table"
        end

        if not definition.command or not definition.command.from or not definition.command.from.type then
            return nil, "Spoon definition requires a source"
        end

        if not definition.name then
            return nil, "Spoon definition requires a Spoon name. Add .withName(\"Name\")."
        end

        if definition.command.from.type == "zip" then
            local zipSource = definition.command.from.url or definition.command.from.path
            if not util.isZipPath(zipSource) then
                return nil, "ZIP source must point to a .zip file"
            end
        end

        if definition.options and definition.options.onLocalChanges and not manager._isLocalChangesBehavior(definition.options.onLocalChanges) then
            return nil, "Invalid local changes behavior: " .. tostring(definition.options.onLocalChanges)
        end

        return true
    end

    function Installer.checkLocalChanges(definition, destination)
        local installed = registry.read()[definition.name]

        if not util.fileExists(destination) then
            return true
        end

        local behavior = definition.options.onLocalChanges or manager.options.localChanges.abort

        if not installed or not installed.checksum then
            if behavior == manager.options.localChanges.overwrite then
                return true
            end

            if behavior == manager.options.localChanges.backup then
                local backupPath = destination .. ".backup-" .. os.date("!%Y%m%dT%H%M%SZ")
                local _, ok = util.movePath(destination, backupPath, logger)
                if ok then
                    return true
                end
                return nil, "Could not backup existing unmanaged Spoon"
            end

            return nil, "Spoon already exists but is not managed by SpoonManager. Use .onLocalChanges(\"backup\") or .onLocalChanges(\"overwrite\") to install anyway."
        end

        local currentChecksum = Installer.checksumDirectory(destination)
        if currentChecksum == installed.checksum then
            return true
        end

        if behavior == manager.options.localChanges.overwrite then
            return true
        end

        if behavior == manager.options.localChanges.backup then
            local backupPath = destination .. ".backup-" .. os.date("!%Y%m%dT%H%M%SZ")
            local _, ok = util.movePath(destination, backupPath, logger)
            if ok then
                return true
            end
            return nil, "Could not backup locally changed Spoon"
        end

        return nil, "Local changes detected. Use .onLocalChanges(\"backup\") or .onLocalChanges(\"overwrite\") to update anyway."
    end

    function Installer.applyUse(definition)
        if not definition.use then
            return true
        end

        local arg = util.copyTable(definition.use)
        arg.disable = nil
        return hs.spoons.use(definition.name, arg, false)
    end

    function Installer.installFromFolder(definition, sourceFolder)
        local destination = paths.targetPath(definition.name)
        util.ensureDir(paths.installRoot(), logger)

        local ok, err = Installer.checkLocalChanges(definition, destination)
        if not ok then
            return nil, err
        end

        local valid, validationError = archive.validateInstalledFolder(sourceFolder)
        if not valid then
            return nil, validationError
        end

        local _, copied = util.copyPath(sourceFolder, destination, logger)
        if not copied then
            return nil, "Could not install Spoon folder"
        end

        registry.persistInstall(definition, destination, Installer.checksumDirectory)
        Installer.applyUse(definition)

        return {
            success = true,
            action = "install",
            name = definition.name,
            path = destination,
            use = definition.use,
        }
    end

    function Installer.installFromZipFile(definition, zipFile, tmpdir)
        local sourceFolder, err = archive.extractZipToSpoon(zipFile, definition, tmpdir)
        if not sourceFolder then
            return nil, err
        end

        return Installer.installFromFolder(definition, sourceFolder)
    end

    function Installer.installFromRemoteZip(definition, url)
        local tmpdir = util.trim(hs.execute("/usr/bin/mktemp -d"))
        if not tmpdir or tmpdir == "" then
            return nil, "Could not create temporary directory"
        end

        local zipFile = util.pathJoin(tmpdir, "download.zip")
        local ok, err = archive.downloadToFile(url, zipFile)
        if not ok then
            util.removePath(tmpdir, logger)
            return nil, err
        end

        local result, installErr = Installer.installFromZipFile(definition, zipFile, tmpdir)
        util.removePath(tmpdir, logger)
        return result, installErr
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

        local source = command.from
        local result, err

        if source.type == "folder" then
            result, err = Installer.installFromFolder(def, source.path)
        elseif source.type == "zip" and source.path then
            local tmpdir = util.trim(hs.execute("/usr/bin/mktemp -d"))
            result, err = Installer.installFromZipFile(def, source.path, tmpdir)
            util.removePath(tmpdir, logger)
        elseif source.type == "zip" and source.url then
            result, err = Installer.installFromRemoteZip(def, source.url)
        else
            return nil, "Unsupported source type: " .. tostring(source.type), def
        end

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
