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

    function Installer.normalizeDefinition(definition)
        local def = util.copyTable(definition)
        local command = resolver.toCommand(definition)
        local resolved = resolver.resolveDefinition(definition)

        def.definition = util.copyTable(definition)
        def.options = util.mergeTables(manager.installOptions, def.options or {})
        def.command = command
        def.resolved = resolved
        def.name = def.resolved.installName
        def.source = command.from
        return def
    end

    function Installer.validateDefinition(definition)
        if type(definition) ~= "table" then
            return nil, "Spoon definition must be a table"
        end

        if not definition.source or not definition.source.type then
            return nil, "Spoon definition requires a source"
        end

        if not definition.name then
            return nil, "Spoon definition requires a Spoon name. Add .withName(\"Name\")."
        end

        if definition.source.type == "remote-zip" and not util.isZipPath(definition.source.url) then
            return nil, "Remote ZIP URL must point to a .zip file"
        end

        if definition.source.type == "local-zip" and not util.isZipPath(definition.source.path) then
            return nil, "Local ZIP path must point to a .zip file"
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
            source = definition.source,
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
        local def = Installer.normalizeDefinition(definition)
        local command = util.copyTable(def.command)
        command.action = action or "install"

        local valid, validationError = Installer.validateDefinition(def)
        if not valid then
            return nil, validationError
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
                command = command,
                resolved = def.resolved,
                source = def.source,
                use = def.use,
            }
        end

        local source = command.from
        local result, err

        if source.type == "local-folder" then
            result, err = Installer.installFromFolder(def, source.path)
        elseif source.type == "local-zip" then
            local tmpdir = util.trim(hs.execute("/usr/bin/mktemp -d"))
            result, err = Installer.installFromZipFile(def, source.path, tmpdir)
            util.removePath(tmpdir, logger)
        elseif source.type == "remote-zip" then
            result, err = Installer.installFromRemoteZip(def, source.url)
        elseif source.type == "github-release" then
            result, err = Installer.installFromRemoteZip(def, source.url)
        elseif source.type == "github-folder" or source.type == "github-repository" then
            result, err = Installer.installFromRemoteZip(def, source.archiveUrl)
        else
            return nil, "Unsupported source type: " .. tostring(source.type)
        end

        if result then
            result.action = action
            result.command = command
            result.resolved = def.resolved
        end
        return result, err
    end

    return Installer
end
