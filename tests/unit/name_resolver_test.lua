return function(T)
    local cases = {
        { "name.zip", "name" },
        { "name.spoon.zip", "name" },
        { "name.spoon", "name" },
        { "folder/lastfoldername", "lastfoldername" },
        { "folder/lastfoldername.spoon", "lastfoldername" },
        { "user/reponame", "reponame" },
        { "user/reponame.spoon", "reponame" },
    }

    for _, item in ipairs(cases) do
        T.test("name inference: " .. item[1], function()
            T.assertEqual(T.context.nameResolver.infer(item[1]), item[2])
        end)
    end

    T.test("name inference precedence: explicit name wins, selection is returned", function()
        local installName, selectedSpoonName = T.context.nameResolver.inferNames({
            source = {
                selection_spoon = "Selected",
                repository = "owner/Repo",
            },
            naming = {
                withName = "Explicit",
            },
        })

        T.assertEqual(installName, "Explicit")
        T.assertEqual(selectedSpoonName, "Selected")
    end)

    T.test("name inference precedence: falls back to repository", function()
        local installName = T.context.nameResolver.inferNames({
            source = {
                repository = "owner/RepoName.spoon",
            },
        })

        T.assertEqual(installName, "RepoName")
    end)

    T.test("name safe rejects traversal and separators", function()
        T.assertEqual(T.context.nameResolver.safe(".."), nil)
        T.assertEqual(T.context.nameResolver.safe("a/b"), nil)
        T.assertEqual(T.context.nameResolver.safe("a..b"), nil)
        T.assertEqual(T.context.nameResolver.safe("Emojis"), "Emojis")
    end)
end
