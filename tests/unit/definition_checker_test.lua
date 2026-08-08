return function(T)
    local checker = T.context.definitionChecker

    local provider = {
        resolveChecks = {
            {
                when = { field = "selection_spoon" },
                forbid = { field = "zipFile" },
                message = "spoon conflicts with zipFile",
            },
        },
    }

    T.test("checker passes when no rule triggers", function()
        checker.run(provider, {
            source = {
                selection_spoon = "A",
            },
        })
    end)

    T.test("checker errors when a forbid rule triggers", function()
        T.assertError(function()
            checker.run(provider, {
                source = {
                    selection_spoon = "A",
                    zipFile = "x.zip",
                },
            })
        end, "spoon conflicts with zipFile")
    end)

    T.test("checker blanket-rejects path traversal regardless of provider", function()
        T.assertError(function()
            checker.run({}, {
                source = {
                    selection_path = "../etc",
                },
            })
        end, "Source path must not contain '%.%.'")
    end)
end
