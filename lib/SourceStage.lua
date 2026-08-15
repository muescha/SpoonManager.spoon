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

    function SourceStage.stageFolder(stage, sourceFolder)
        stage.folder = util.pathJoin(stage.root, "source.spoon")
        local _, copied = util.copyPath(sourceFolder, stage.folder, logger)
        if not copied then
            return nil, "Could not copy source folder into stage"
        end

        return stage
    end

    function SourceStage.stageZipFile(stage, zipFile, selection)
        local sourceFolder, extractErr = spoonExtractor.extractZipToSpoon(zipFile, selection, stage.root)
        if not sourceFolder then
            return nil, extractErr
        end

        stage.folder = util.pathJoin(stage.root, "source.spoon")
        local _, copied = util.copyPath(sourceFolder, stage.folder, logger)
        if not copied then
            return nil, "Could not copy extracted Spoon into stage"
        end

        return stage
    end

    function SourceStage.fromFolderSource(source)
        local stage, err = SourceStage.create()
        if not stage then
            return nil, err
        end

        local artifact, fetchErr = sourceFetcher.fetch(source.location or {}, stage)
        if not artifact then
            SourceStage.cleanup(stage)
            return nil, fetchErr
        end

        local result, stageErr = SourceStage.stageFolder(stage, artifact.path)
        if not result then
            SourceStage.cleanup(stage)
            return nil, stageErr
        end

        return stage
    end

    function SourceStage.fromZipSource(source)
        local selection = source.selection or {}

        local stage, err = SourceStage.create()
        if not stage then
            return nil, err
        end

        local artifact, fetchErr = sourceFetcher.fetch(source.location or {}, stage)
        if not artifact then
            SourceStage.cleanup(stage)
            return nil, fetchErr
        end

        local result, stageErr = SourceStage.stageZipFile(stage, artifact.path, selection)
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
