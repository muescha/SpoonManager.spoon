return function(T)
    T.test("definition rejects branch after spoon selection", function()
        T.assertError(function()
            T.SpoonManager.from.default
                .spoon("Emojis")
                .branch("main")
        end, "spoon%('Emojis'%) already selected")
    end)

    T.test("definition rejects duplicate revision group", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .branch("main")
                .ref("v1.2.3")
        end, "%.branch%('main'%) already set; cannot call %.ref%('v1%.2%.3'%)")
    end)

    T.test("definition rejects duplicate selection group", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .folder("Source/A.spoon")
                .asset("A.zip")
        end, "%.folder%('Source/A%.spoon'%) already set; cannot call %.asset%('A%.zip'%)")
    end)

    T.test("definition rejects non zip release asset", function()
        T.assertError(function()
            T.SpoonManager.from.github("owner/repo")
                .releaseLatest()
                .asset("A.tar.gz")
        end, "Release asset must point to a %.zip file")
    end)

    T.test("installer rejects non zip release asset from config", function()
        local result, err =
            T.SpoonManager.from.config({
                source = {
                    type = "github",
                    repository = "owner/repo",
                    release = "latest",
                },
                target = {
                    selection_asset = "A.tar.gz",
                    name_withName = "A",
                },
            }).install()

        T.assertFalse(result)
        T.assertEqual(err, "GitHub release asset must point to a .zip file")
    end)
end
