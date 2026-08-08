return function(T)
    local util = T.context.util

    T.test("util pathJoin joins segments and collapses slashes", function()
        T.assertEqual(util.pathJoin("a", "b", "c"), "a/b/c")
        T.assertEqual(util.pathJoin("a/", "/b"), "a/b")
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
