return function(context)
    local SourceStage = {}
    local util = context.util
    local logger = context.logger
    local spoonExtractor = context.spoonExtractor

    function SourceStage.create()
        local root = util.trim(hs.execute("/usr/bin/mktemp -d"))
        if not root or root == "" then
            return nil, "Could not create temporary directory"
        end

        return {
            root = root,
        }
    end

    function SourceStage.fromFolder(sourceFolder)
        local stage, err = SourceStage.create()
        if not stage then
            return nil, err
        end

        stage.folder = util.pathJoin(stage.root, "source.spoon")
        local _, copied = util.copyPath(sourceFolder, stage.folder, logger)
        if not copied then
            SourceStage.cleanup(stage)
            return nil, "Could not copy source folder into stage"
        end

        return stage
    end

    function SourceStage.fromZipFile(zipFile, selection)
        local stage, err = SourceStage.create()
        if not stage then
            return nil, err
        end

        local sourceFolder, extractErr = spoonExtractor.extractZipToSpoon(zipFile, selection, stage.root)
        if not sourceFolder then
            SourceStage.cleanup(stage)
            return nil, extractErr
        end

        stage.folder = util.pathJoin(stage.root, "source.spoon")
        local _, copied = util.copyPath(sourceFolder, stage.folder, logger)
        if not copied then
            SourceStage.cleanup(stage)
            return nil, "Could not copy extracted Spoon into stage"
        end

        return stage
    end

    function SourceStage.fromRemoteZip(url, selection)
        local stage, err = SourceStage.create()
        if not stage then
            return nil, err
        end

        local zipFile = util.pathJoin(stage.root, "download.zip")
        local ok, downloadErr = spoonExtractor.downloadToFile(url, zipFile)
        if not ok then
            SourceStage.cleanup(stage)
            return nil, downloadErr
        end

        local sourceFolder, extractErr = spoonExtractor.extractZipToSpoon(zipFile, selection, stage.root)
        if not sourceFolder then
            SourceStage.cleanup(stage)
            return nil, extractErr
        end

        stage.folder = util.pathJoin(stage.root, "source.spoon")
        local _, copied = util.copyPath(sourceFolder, stage.folder, logger)
        if not copied then
            SourceStage.cleanup(stage)
            return nil, "Could not copy extracted Spoon into stage"
        end

        return stage
    end

    function SourceStage.cleanup(stage)
        if stage and stage.root then
            util.removePath(stage.root, logger)
        end
    end

    return SourceStage
end
