return function(context)
    local SourceStage = {}
    local util = context.util
    local logger = context.logger
    local spoonExtractor = context.spoonExtractor
    local sourceFetcher = context.sourceFetcher

    function SourceStage.create()
        local root = util.trim(hs.execute("/usr/bin/mktemp -d"))
        if not root or root == "" then
            return nil, "Could not create temporary directory"
        end

        return {
            root = root,
        }
    end

    function SourceStage.copyFolderIntoStage(stage, sourceFolder, options)
        stage.folder = util.pathJoin(stage.root, "source.spoon")
        local _, copied = util.copyPath(sourceFolder, stage.folder, logger)
        if not copied then
            return nil, "Could not copy source folder into stage"
        end

        if not util.removeIgnoredNames(stage.folder, options, logger) then
            return nil, "Could not exclude folders from stage"
        end

        return stage
    end

    function SourceStage.copyZipSelectionIntoStage(stage, zipFile, selection, options)
        if not util.isZipPath(zipFile) then
            return nil, "ZIP source must point to a .zip file"
        end

        local sourceFolder, extractErr = spoonExtractor.extractZipToSpoon(zipFile, selection, stage.root)
        if not sourceFolder then
            return nil, extractErr
        end

        stage.folder = util.pathJoin(stage.root, "source.spoon")
        local _, copied = util.copyPath(sourceFolder, stage.folder, logger)
        if not copied then
            return nil, "Could not copy extracted Spoon into stage"
        end

        if not util.removeIgnoredNames(stage.folder, options, logger) then
            return nil, "Could not exclude folders from stage"
        end

        return stage
    end

    function SourceStage.fromFolderSource(source)
        local stage, err = SourceStage.create()
        if not stage then
            return nil, err
        end

        local artifact, fetchErr = sourceFetcher.fetch(source.location, stage)
        if not artifact then
            SourceStage.cleanup(stage)
            return nil, fetchErr
        end

        local result, stageErr = SourceStage.copyFolderIntoStage(stage, artifact.path, {
            excludeFolders = source.excludeFolders,
        })
        if not result then
            SourceStage.cleanup(stage)
            return nil, stageErr
        end

        return stage
    end

    function SourceStage.fromZipSource(source)
        local selection = source.selection or {}
        local location = source.location or {}
        local zipSource = location.url or location.path

        if not util.isZipPath(zipSource) then
            return nil, "ZIP source must point to a .zip file"
        end

        local stage, err = SourceStage.create()
        if not stage then
            return nil, err
        end

        local artifact, fetchErr = sourceFetcher.fetch(source.location, stage)
        if not artifact then
            SourceStage.cleanup(stage)
            return nil, fetchErr
        end

        local result, stageErr = SourceStage.copyZipSelectionIntoStage(stage, artifact.path, selection, {
            excludeFolders = source.excludeFolders,
        })
        if not result then
            SourceStage.cleanup(stage)
            return nil, stageErr
        end

        return stage
    end

    function SourceStage.fromCommand(command)
        local source = command.source
        local handlers = {
            folder = SourceStage.fromFolderSource,
            zip = SourceStage.fromZipSource,
        }
        local handler = handlers[source.kind]

        if not handler then
            return nil, "Unsupported source kind: " .. tostring(source.kind)
        end

        return handler(source)
    end

    function SourceStage.cleanup(stage)
        if stage and stage.root then
            util.removePath(stage.root, logger)
        end
    end

    return SourceStage
end
