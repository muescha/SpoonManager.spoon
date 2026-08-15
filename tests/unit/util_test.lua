return function(T)
    local util = T.context.util

    T.test("util pathJoin joins segments and collapses slashes", function()
        T.assertEqual(util.pathJoin("a", "b", "c"), "a/b/c")
        T.assertEqual(util.pathJoin("a/", "/b"), "a/b")
    end)

    T.test("util pathJoin skips nil segments", function()
        T.assertEqual(util.pathJoin("a", nil, "c"), "a/c")
        T.assertEqual(util.pathJoin("a", nil), "a")
        T.assertEqual(util.pathJoin(nil, "b"), "b")
    end)

    T.test("util pathJoin rejects traversal segments", function()
        T.assertError(function()
            util.pathJoin("base", "../etc")
        end, "must not contain '%.%.'")
    end)

    T.test("util joinUrl preserves scheme and skips nil segments", function()
        T.assertEqual(util.joinUrl("https://example.com/", nil, "x.zip"), "https://example.com/x.zip")
        T.assertEqual(util.joinUrl("https://example.com", "sub", "x.zip"), "https://example.com/sub/x.zip")
    end)

    T.test("util joinUrl rejects traversal segments", function()
        T.assertError(function()
            util.joinUrl("https://example.com", "../secret", "x.zip")
        end, "must not contain '%.%.'")
    end)

    T.test("util hashDirectory prunes default noise and extra folders", function()
        local originalExecute = hs.execute
        local originalAttributes = hs.fs.attributes
        local commandSeen

        hs.execute = function(command)
            commandSeen = command
            return "hash\n", true
        end
        hs.fs.attributes = function()
            return {}
        end

        local hash = util.hashDirectory("/tmp/Spoon.spoon", {
            excludeFolders = {
                "annotations",
            },
        })

        hs.execute = originalExecute
        hs.fs.attributes = originalAttributes

        T.assertEqual(hash, "hash")
        T.assertTrue(commandSeen:find("%-name '%.DS_Store'") ~= nil)
        T.assertTrue(commandSeen:find("%-name '__MACOSX'") ~= nil)
        T.assertTrue(commandSeen:find("%-name '%.git'") ~= nil)
        T.assertTrue(commandSeen:find("%-name 'annotations'") ~= nil)
        T.assertTrue(commandSeen:find("%-prune %-o %-type f %-print0") ~= nil)
    end)

    T.test("util removeIgnoredNames prunes default noise and extra folders", function()
        local originalExecute = hs.execute
        local originalAttributes = hs.fs.attributes
        local commandSeen

        hs.execute = function(command)
            commandSeen = command
            return "", true
        end
        hs.fs.attributes = function()
            return {}
        end

        local ok = util.removeIgnoredNames("/tmp/Spoon.spoon", {
            excludeFolders = {
                "annotations",
            },
        })

        hs.execute = originalExecute
        hs.fs.attributes = originalAttributes

        T.assertTrue(ok)
        T.assertTrue(commandSeen:find("%-name '%.DS_Store'") ~= nil)
        T.assertTrue(commandSeen:find("%-name '__MACOSX'") ~= nil)
        T.assertTrue(commandSeen:find("%-name '%.git'") ~= nil)
        T.assertTrue(commandSeen:find("%-name 'annotations'") ~= nil)
        T.assertTrue(commandSeen:find("%-prune %-exec /bin/rm %-rf") ~= nil)
    end)

    T.test("util requireSafeFileName rejects path separators", function()
        T.assertEqual(util.requireSafeFileName("A.spoon.zip", "ZIP file"), "A.spoon.zip")

        T.assertError(function()
            util.requireSafeFileName("sub/A.zip", "ZIP file")
        end, "ZIP file must be a file name, not a path")

        T.assertError(function()
            util.requireSafeFileName("../A.zip", "ZIP file")
        end, "ZIP file must be a file name, not a path")
    end)

    T.test("util requireSafeRelPath allows subpaths and rejects traversal", function()
        T.assertEqual(util.requireSafeRelPath("Source/A.spoon", "Source path"), "Source/A.spoon")

        T.assertError(function()
            util.requireSafeRelPath("../x", "Source path")
        end, "Source path must not contain '%.%.'")

        T.assertError(function()
            util.requireSafeRelPath("a\\b", "Source path")
        end, "must not contain a backslash")
    end)
end
