return function(context)
    local SourceStage = {}
    local util = context.util
    local logger = context.logger

    function SourceStage.create()
        local root = util.trim(hs.execute("/usr/bin/mktemp -d"))
        if not root or root == "" then
            return nil, "Could not create temporary directory"
        end

        return {
            root = root,
        }
    end

    function SourceStage.cleanup(stage)
        if stage and stage.root then
            util.removePath(stage.root, logger)
        end
    end

    return SourceStage
end
