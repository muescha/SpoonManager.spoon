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

    T.test("name safe rejects traversal and separators", function()
        T.assertEqual(T.context.nameResolver.safe(".."), nil)
        T.assertEqual(T.context.nameResolver.safe("a/b"), nil)
        T.assertEqual(T.context.nameResolver.safe("a..b"), nil)
        T.assertEqual(T.context.nameResolver.safe("Emojis"), "Emojis")
    end)
end
